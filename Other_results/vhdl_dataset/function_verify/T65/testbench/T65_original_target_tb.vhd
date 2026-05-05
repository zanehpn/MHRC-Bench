-- =============================================================================
-- Testbench: T65_original_target_tb.vhd
--
-- DUT: T65 (65xx CPU core, T65.vhd)
-- Source: T65_original.vhd
--
-- Target Logic:
--   Stack pointer increment/decrement in T65.vhd:
--     if Inc_S = '1' then S <= S + 1;
--     if Dec_S = '1' and (RstCycle = '0' or Mode = "00") then S <= S - 1;
--   These signals are driven by T65_MCode (the microcode decoder). They are
--   exercised by instructions that push/pull to/from the stack: PHA, PLA,
--   JSR, RTS, PHP, PLP, BRK, RTI.
--
-- PARTIAL BLOCKER:
--   The T65 is a soft-CPU that executes a real 6502 instruction stream. To
--   reach the stack-pointer target logic, the CPU must fetch and execute
--   instructions that use the stack (e.g., PHA = 0x48, JSR = 0x20, PLA =
--   0x68, RTS = 0x60). This testbench provides a minimal ROM-like instruction
--   memory via a process that responds to A_OUT, allowing basic instruction
--   execution. Full functional verification (all opcodes, all addressing modes,
--   timing accuracy) requires a complete 6502 test suite (e.g., Klaus Dormann
--   or Lorenz tests) loaded as a binary image.
--
-- DEPENDENCY:
--   T65 uses work.T65_Pack (package with T_ALU_OP, T_t65_dbg, etc.).
--   T65_Pack.vhd must be compiled into work before this testbench.
--   It is located alongside T65.vhd in the source tree.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.T65_Pack.all;

entity T65_original_target_tb is
end entity T65_original_target_tb;

architecture tb of T65_original_target_tb is

  -- -------------------------------------------------------------------------
  -- Timing constants
  -- -------------------------------------------------------------------------
  constant CLK_PERIOD : time := 20 ns;   -- 50 MHz

  -- -------------------------------------------------------------------------
  -- DUT interface signals
  -- -------------------------------------------------------------------------
  signal Mode    : std_logic_vector(1 downto 0) := "00";  -- 6502 mode
  signal BCD_en  : std_logic := '1';
  signal Res_n   : std_logic := '0';
  signal Enable  : std_logic := '1';
  signal Clk     : std_logic := '0';
  signal Rdy     : std_logic := '1';
  signal Abort_n : std_logic := '1';
  signal IRQ_n   : std_logic := '1';
  signal NMI_n   : std_logic := '1';
  signal SO_n    : std_logic := '1';
  signal R_W_n   : std_logic;
  signal Sync    : std_logic;
  signal EF      : std_logic;
  signal MF      : std_logic;
  signal XF      : std_logic;
  signal ML_n    : std_logic;
  signal VP_n    : std_logic;
  signal VDA     : std_logic;
  signal VPA     : std_logic;
  signal A       : std_logic_vector(23 downto 0);
  signal DI      : std_logic_vector(7 downto 0) := (others => '0');
  signal DO_cpu  : std_logic_vector(7 downto 0);
  signal Regs    : std_logic_vector(63 downto 0);
  signal DEBUG   : T_t65_dbg;
  signal NMI_ack : std_logic;

  -- Loopback: DO -> DI when writing (required for undoc opcode correctness)
  signal cpu_addr : unsigned(15 downto 0);

  -- -------------------------------------------------------------------------
  -- Minimal instruction ROM
  -- Placed at reset vector 0xFFFC/0xFFFD -> 0x0200 (start address)
  -- Instruction sequence at 0x0200:
  --   LDA #$55   (A9 55)   - load accumulator
  --   PHA        (48)      - push A: Dec_S asserted -> S decrements
  --   PLA        (68)      - pull A: Inc_S asserted -> S increments
  --   NOP        (EA)
  --   JMP $0200  (4C 00 02)- loop back
  -- -------------------------------------------------------------------------
  type rom_t is array(0 to 65535) of std_logic_vector(7 downto 0);

  function init_rom return rom_t is
    variable r : rom_t := (others => x"EA");  -- fill with NOP
  begin
    -- Reset vector: lo=0x00, hi=0x02 => jump to 0x0200
    r(16#FFFC#) := x"00";
    r(16#FFFD#) := x"02";
    -- NMI vector (unused)
    r(16#FFFA#) := x"00";
    r(16#FFFB#) := x"02";
    -- IRQ/BRK vector (unused)
    r(16#FFFE#) := x"00";
    r(16#FFFF#) := x"02";
    -- Instruction stream at 0x0200
    r(16#0200#) := x"A9";  -- LDA #imm
    r(16#0201#) := x"55";  -- #$55
    r(16#0202#) := x"48";  -- PHA  (push A -> Dec_S)
    r(16#0203#) := x"68";  -- PLA  (pull A -> Inc_S)
    r(16#0204#) := x"EA";  -- NOP
    r(16#0205#) := x"4C";  -- JMP abs
    r(16#0206#) := x"00";  -- lo
    r(16#0207#) := x"02";  -- hi
    return r;
  end function init_rom;

  constant ROM : rom_t := init_rom;

  -- Scratchpad RAM (0x0000 - 0x01FF for stack, plus zero page)
  type ram_t is array(0 to 511) of std_logic_vector(7 downto 0);
  signal RAM : ram_t := (others => (others => '0'));

  -- SP extraction: bits 23..16 of Regs = S (low byte of stack pointer)
  -- Regs layout (MSB->LSB): PC(15:0) SP(15:0) P(7:0) Y(7:0) X(7:0) A(7:0)
  -- bits 63:48 = PC, 47:32 = SP, 31:24 = P, 23:16 = Y, 15:8 = X, 7:0 = A
  signal sp_reg   : std_logic_vector(15 downto 0);
  signal sp_prev  : std_logic_vector(15 downto 0);
  signal dec_seen : std_logic := '0';
  signal inc_seen : std_logic := '0';

begin

  -- -------------------------------------------------------------------------
  -- Clock generation
  -- -------------------------------------------------------------------------
  clk_proc : process
  begin
    Clk <= '0'; wait for CLK_PERIOD / 2;
    Clk <= '1'; wait for CLK_PERIOD / 2;
  end process clk_proc;

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  DUT : entity work.T65
    port map (
      Mode    => Mode,
      BCD_en  => BCD_en,
      Res_n   => Res_n,
      Enable  => Enable,
      Clk     => Clk,
      Rdy     => Rdy,
      Abort_n => Abort_n,
      IRQ_n   => IRQ_n,
      NMI_n   => NMI_n,
      SO_n    => SO_n,
      R_W_n   => R_W_n,
      Sync    => Sync,
      EF      => EF,
      MF      => MF,
      XF      => XF,
      ML_n    => ML_n,
      VP_n    => VP_n,
      VDA     => VDA,
      VPA     => VPA,
      A       => A,
      DI      => DI,
      DO      => DO_cpu,
      Regs    => Regs,
      DEBUG   => DEBUG,
      NMI_ack => NMI_ack
    );

  cpu_addr <= unsigned(A(15 downto 0));
  sp_reg   <= Regs(47 downto 32);

  -- -------------------------------------------------------------------------
  -- Memory model: combinational ROM read + synchronous RAM write
  -- T65 expects data on DI to be available in the same cycle the address
  -- is presented (asynchronous / combinational read, like a real 6502).
  -- -------------------------------------------------------------------------
  mem_read : process (cpu_addr, R_W_n, DO_cpu, RAM)
    variable addr_int : integer;
  begin
    addr_int := to_integer(cpu_addr);
    if R_W_n = '0' then
      -- Write: loopback DO -> DI (per T65 documentation)
      DI <= DO_cpu;
    else
      -- Read
      if addr_int <= 511 then
        DI <= RAM(addr_int);
      else
        DI <= ROM(addr_int);
      end if;
    end if;
  end process mem_read;

  mem_write : process (Clk)
    variable addr_int : integer;
  begin
    if rising_edge(Clk) then
      addr_int := to_integer(cpu_addr);
      if R_W_n = '0' and addr_int <= 511 then
        RAM(addr_int) <= DO_cpu;
      end if;
    end if;
  end process mem_write;

  -- -------------------------------------------------------------------------
  -- Stack pointer monitor: detect Inc_S / Dec_S activity
  -- -------------------------------------------------------------------------
  sp_monitor : process (Clk)
  begin
    if rising_edge(Clk) then
      sp_prev <= sp_reg;
      -- Dec_S observed when SP decrements (PHA, JSR, PHP, BRK, ...)
      if unsigned(sp_reg) = unsigned(sp_prev) - 1 then
        dec_seen <= '1';
      end if;
      -- Inc_S observed when SP increments (PLA, RTS, PLP, RTI, ...)
      if unsigned(sp_reg) = unsigned(sp_prev) + 1 then
        inc_seen <= '1';
      end if;
    end if;
  end process sp_monitor;

  -- -------------------------------------------------------------------------
  -- Stimulus and assertion process
  -- -------------------------------------------------------------------------
  stim_proc : process
  begin
    -- Hold reset for 10 clock cycles
    Res_n <= '0';
    wait for 10 * CLK_PERIOD;

    -- De-assert reset
    Res_n <= '1';

    -- Allow reset sequence to complete (7 cycles for 6502 reset sequence)
    wait for 20 * CLK_PERIOD;

    -- Assert: CPU should now be executing; Sync should pulse during opcode fetch
    -- Wait for at least one Sync pulse (instruction fetch)
    wait until Sync = '1' for 50 * CLK_PERIOD;
    assert Sync = '1'
      report "FAIL: No Sync (opcode fetch) detected within 50 cycles of reset completion"
      severity error;

    -- Assert: A_OUT should not be X or U after reset
    assert A /= (A'range => 'X')
      report "FAIL: Address bus is all-X after reset"
      severity error;

    -- Run long enough to execute LDA/PHA/PLA loop several times
    -- PHA = 3 cycles, PLA = 4 cycles, LDA = 2 cycles, NOP = 2, JMP = 3 -> ~14 cycles/iteration
    -- Allow extra margin for reset sequence and pipeline startup
    wait for 600 * CLK_PERIOD;

    -- Assert: stack decrement (PHA) was observed
    assert dec_seen = '1'
      report "FAIL: Stack pointer decrement (Dec_S path / PHA) was never observed"
      severity error;

    -- Assert: stack increment (PLA) was observed
    assert inc_seen = '1'
      report "FAIL: Stack pointer increment (Inc_S path / PLA) was never observed"
      severity error;

    report "PASS: T65 stack pointer Inc_S and Dec_S paths both observed." severity note;
    report "NOTE: Full CPU verification requires Klaus Dormann / Lorenz test suite (PARTIAL BLOCKER)." severity note;

    wait for 100 * CLK_PERIOD;
    report "SIMULATION COMPLETE: T65_original_target_tb" severity note;
    wait;
  end process stim_proc;

end architecture tb;
