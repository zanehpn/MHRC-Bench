-- Shared UNISIM stub implementations
-- Contains behavioral models for: ODDR, OSERDESE2, PLLE2_ADV, BUFG, OBUFDS

------------------------------------------------------------------------
-- ODDR
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ODDR is
    generic (
        DDR_CLK_EDGE : string := "SAME_EDGE";
        INIT         : bit    := '0';
        SRTYPE       : string := "SYNC"
    );
    port (
        Q  : out std_logic;
        C  : in  std_logic;
        CE : in  std_logic;
        R  : in  std_logic;
        S  : in  std_logic;
        D1 : in  std_logic;
        D2 : in  std_logic
    );
end entity ODDR;

architecture behavioral of ODDR is
begin
    process (C)
    begin
        if rising_edge(C) then
            if R = '1' then
                Q <= '0';
            elsif S = '1' then
                Q <= '1';
            elsif CE = '1' then
                Q <= D1;
            end if;
        end if;
        if falling_edge(C) then
            if R = '1' then
                Q <= '0';
            elsif S = '1' then
                Q <= '1';
            elsif CE = '1' then
                Q <= D2;
            end if;
        end if;
    end process;
end architecture behavioral;

------------------------------------------------------------------------
-- OSERDESE1
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity OSERDESE1 is
    generic (
        DATA_RATE_OQ   : string  := "DDR";
        DATA_RATE_TQ   : string  := "DDR";
        DATA_WIDTH     : integer := 4;
        INIT_OQ        : bit     := '0';
        INIT_TQ        : bit     := '0';
        SERDES_MODE    : string  := "MASTER";
        SRVAL_OQ       : bit     := '0';
        SRVAL_TQ       : bit     := '0';
        TRISTATE_WIDTH : integer := 4;
        INTERFACE_TYPE : string  := "DEFAULT"
    );
    port (
        OFB          : out std_logic;
        OQ           : out std_logic;
        SHIFTOUT1    : out std_logic;
        SHIFTOUT2    : out std_logic;
        TFB          : out std_logic;
        TQ           : out std_logic;
        CLK          : in  std_logic;
        CLKDIV       : in  std_logic;
        CLKPERF      : in  std_logic;
        CLKPERFDELAY : in  std_logic;
        D1           : in  std_logic;
        D2           : in  std_logic;
        D3           : in  std_logic;
        D4           : in  std_logic;
        D5           : in  std_logic;
        D6           : in  std_logic;
        OCE          : in  std_logic;
        ODV          : in  std_logic;
        RST          : in  std_logic;
        SHIFTIN1     : in  std_logic;
        SHIFTIN2     : in  std_logic;
        T1           : in  std_logic;
        T2           : in  std_logic;
        T3           : in  std_logic;
        T4           : in  std_logic;
        TCE          : in  std_logic;
        WC           : in  std_logic
    );
end entity OSERDESE1;

architecture behavioral of OSERDESE1 is
    signal shift_reg : std_logic_vector(5 downto 0) := (others => '0');
    signal bit_index : integer range 0 to 9 := 0;
    signal loaded    : std_logic := '0';
begin

    -- Unused outputs
    OFB <= '0';
    TFB <= '0';
    TQ  <= '0';

    -- In SLAVE mode, cascade shift data to MASTER via SHIFTOUT
    SHIFTOUT1 <= D3 when SERDES_MODE = "SLAVE" else '0';
    SHIFTOUT2 <= D4 when SERDES_MODE = "SLAVE" else '0';

    -- Load parallel data on CLKDIV rising edge
    p_load : process (CLKDIV)
    begin
        if rising_edge(CLKDIV) then
            if RST = '1' then
                shift_reg <= (others => '0');
                loaded    <= '0';
            elsif OCE = '1' then
                shift_reg <= D1 & D2 & D3 & D4 & D5 & D6;
                loaded    <= '1';
                bit_index <= 0;
            end if;
        end if;
    end process;

    -- Serialize on CLK edges
    p_shift : process (CLK)
        variable idx : integer;
    begin
        if SERDES_MODE = "MASTER" then
            if rising_edge(CLK) then
                if RST = '1' then
                    OQ <= '0';
                elsif loaded = '1' and OCE = '1' then
                    idx := 5 - bit_index;
                    if idx >= 0 and idx <= 5 then
                        OQ <= shift_reg(idx);
                    end if;
                end if;
            end if;
            if falling_edge(CLK) then
                if RST = '1' then
                    OQ <= '0';
                elsif DATA_RATE_OQ = "DDR" and loaded = '1' and OCE = '1' then
                    idx := 5 - bit_index;
                    if (idx - 1) >= 0 and (idx - 1) <= 5 then
                        OQ <= shift_reg(idx - 1);
                    end if;
                    if bit_index + 2 < DATA_WIDTH then
                        bit_index <= bit_index + 2;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;

------------------------------------------------------------------------
-- OSERDESE2
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity OSERDESE2 is
    generic (
        DATA_RATE_OQ   : string  := "DDR";
        DATA_RATE_TQ   : string  := "DDR";
        DATA_WIDTH     : integer := 4;
        INIT_OQ        : bit     := '0';
        INIT_TQ        : bit     := '0';
        SERDES_MODE    : string  := "MASTER";
        SRVAL_OQ       : bit     := '0';
        SRVAL_TQ       : bit     := '0';
        TBYTE_CTL      : string  := "FALSE";
        TBYTE_SRC      : string  := "FALSE";
        TRISTATE_WIDTH : integer := 4
    );
    port (
        OFB       : out std_logic;
        OQ        : out std_logic;
        SHIFTOUT1 : out std_logic;
        SHIFTOUT2 : out std_logic;
        TBYTEOUT  : out std_logic;
        TFB       : out std_logic;
        TQ        : out std_logic;
        CLK       : in  std_logic;
        CLKDIV    : in  std_logic;
        D1        : in  std_logic;
        D2        : in  std_logic;
        D3        : in  std_logic;
        D4        : in  std_logic;
        D5        : in  std_logic;
        D6        : in  std_logic;
        D7        : in  std_logic;
        D8        : in  std_logic;
        OCE       : in  std_logic;
        RST       : in  std_logic;
        SHIFTIN1  : in  std_logic;
        SHIFTIN2  : in  std_logic;
        T1        : in  std_logic;
        T2        : in  std_logic;
        T3        : in  std_logic;
        T4        : in  std_logic;
        TBYTEIN   : in  std_logic;
        TCE       : in  std_logic
    );
end entity OSERDESE2;

architecture behavioral of OSERDESE2 is
    -- Shift register holds parallel data to be serialized
    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_index : integer range 0 to 7 := 0;
    signal loaded    : std_logic := '0';
begin

    -- Unused outputs
    OFB      <= '0';
    TBYTEOUT <= '0';
    TFB      <= '0';
    TQ       <= '0';

    -- In SLAVE mode, cascade shift data to MASTER via SHIFTOUT
    SHIFTOUT1 <= D3 when SERDES_MODE = "SLAVE" else '0';
    SHIFTOUT2 <= D4 when SERDES_MODE = "SLAVE" else '0';

    -- Load parallel data on CLKDIV rising edge, shift out on CLK edges
    p_load : process (CLKDIV)
    begin
        if rising_edge(CLKDIV) then
            if RST = '1' then
                shift_reg <= (others => '0');
                loaded    <= '0';
            elsif OCE = '1' then
                if SERDES_MODE = "MASTER" then
                    -- For width 10, bits 8-9 come from SHIFTIN (slave cascade)
                    -- For width 8 or less, only D1..D8 are used
                    if DATA_WIDTH = 10 then
                        shift_reg <= D1 & D2 & D3 & D4 & D5 & D6 & D7 & D8;
                    elsif DATA_WIDTH = 8 then
                        shift_reg <= D1 & D2 & D3 & D4 & D5 & D6 & D7 & D8;
                    elsif DATA_WIDTH = 6 then
                        shift_reg <= D1 & D2 & D3 & D4 & D5 & D6 & '0' & '0';
                    elsif DATA_WIDTH = 4 then
                        shift_reg <= D1 & D2 & D3 & D4 & '0' & '0' & '0' & '0';
                    else
                        shift_reg <= D1 & D2 & D3 & D4 & D5 & D6 & D7 & D8;
                    end if;
                end if;
                loaded    <= '1';
                bit_index <= 0;
            end if;
        end if;
    end process;

    -- Serialize: shift out bits on each CLK edge (DDR = both edges)
    p_shift : process (CLK)
        variable half_width : integer;
        variable idx        : integer;
    begin
        if DATA_RATE_OQ = "DDR" then
            half_width := DATA_WIDTH / 2;
        else
            half_width := DATA_WIDTH;
        end if;

        if SERDES_MODE = "MASTER" then
            if rising_edge(CLK) then
                if RST = '1' then
                    OQ <= '0';
                elsif loaded = '1' and OCE = '1' then
                    -- Map bit_index to shift_reg position
                    -- bit_index 0 -> D1 (shift_reg(7)), etc.
                    idx := 7 - bit_index;
                    if idx >= 0 and idx <= 7 then
                        OQ <= shift_reg(idx);
                    end if;
                end if;
            end if;

            if falling_edge(CLK) then
                if RST = '1' then
                    OQ <= '0';
                elsif DATA_RATE_OQ = "DDR" and loaded = '1' and OCE = '1' then
                    idx := 7 - bit_index;
                    -- On falling edge, output the next bit
                    if (idx - 1) >= 0 and (idx - 1) <= 7 then
                        OQ <= shift_reg(idx - 1);
                    elsif DATA_WIDTH = 10 then
                        -- Bits 8,9 come from slave cascade (SHIFTIN1, SHIFTIN2)
                        if bit_index = 8 then
                            OQ <= SHIFTIN1;
                        elsif bit_index = 9 then
                            OQ <= SHIFTIN2;
                        end if;
                    end if;
                    -- Advance by 2 for DDR (rising used one, falling used next)
                    if bit_index + 2 < DATA_WIDTH then
                        bit_index <= bit_index + 2;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;

------------------------------------------------------------------------
-- PLLE2_ADV
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity PLLE2_ADV is
    generic (
        BANDWIDTH          : string  := "OPTIMIZED";
        CLKIN1_PERIOD      : real    := 0.000;
        CLKIN2_PERIOD      : real    := 0.000;
        CLKOUT0_DIVIDE     : integer := 1;
        CLKOUT1_DIVIDE     : integer := 1;
        CLKOUT2_DIVIDE     : integer := 1;
        CLKOUT3_DIVIDE     : integer := 1;
        CLKOUT4_DIVIDE     : integer := 1;
        CLKOUT5_DIVIDE     : integer := 1;
        CLKOUT0_PHASE      : real    := 0.0;
        CLKOUT1_PHASE      : real    := 0.0;
        CLKOUT2_PHASE      : real    := 0.0;
        CLKOUT3_PHASE      : real    := 0.0;
        CLKOUT4_PHASE      : real    := 0.0;
        CLKOUT5_PHASE      : real    := 0.0;
        CLKOUT0_DUTY_CYCLE : real    := 0.5;
        CLKOUT1_DUTY_CYCLE : real    := 0.5;
        CLKOUT2_DUTY_CYCLE : real    := 0.5;
        CLKOUT3_DUTY_CYCLE : real    := 0.5;
        CLKOUT4_DUTY_CYCLE : real    := 0.5;
        CLKOUT5_DUTY_CYCLE : real    := 0.5;
        COMPENSATION       : string  := "ZHOLD";
        DIVCLK_DIVIDE      : integer := 1;
        CLKFBOUT_MULT      : integer := 2;
        CLKFBOUT_PHASE     : real    := 0.0;
        REF_JITTER1        : real    := 0.100;
        STARTUP_WAIT       : string  := "FALSE"
    );
    port (
        CLKIN1   : in  std_logic;
        CLKIN2   : in  std_logic;
        CLKFBIN  : in  std_logic;
        CLKINSEL : in  std_logic;
        RST      : in  std_logic;
        PWRDWN   : in  std_logic;
        DADDR    : in  std_logic_vector(6 downto 0);
        DI       : in  std_logic_vector(15 downto 0);
        DWE      : in  std_logic;
        DEN      : in  std_logic;
        DCLK     : in  std_logic;
        DRDY     : out std_logic;
        DO       : out std_logic_vector(15 downto 0);
        CLKOUT0  : out std_logic;
        CLKOUT1  : out std_logic;
        CLKOUT2  : out std_logic;
        CLKOUT3  : out std_logic;
        CLKOUT4  : out std_logic;
        CLKOUT5  : out std_logic;
        CLKFBOUT : out std_logic;
        LOCKED   : out std_logic
    );
end entity PLLE2_ADV;

architecture behavioral of PLLE2_ADV is
    signal clk_src     : std_logic;
    signal lock_cnt    : integer range 0 to 7 := 0;
    signal locked_int  : std_logic := '0';
    -- Clock divider counters
    signal div0_cnt    : integer range 0 to 1023 := 0;
    signal div1_cnt    : integer range 0 to 1023 := 0;
    signal div2_cnt    : integer range 0 to 1023 := 0;
    signal div3_cnt    : integer range 0 to 1023 := 0;
    signal div4_cnt    : integer range 0 to 1023 := 0;
    signal div5_cnt    : integer range 0 to 1023 := 0;
    signal clk0_int    : std_logic := '0';
    signal clk1_int    : std_logic := '0';
    signal clk2_int    : std_logic := '0';
    signal clk3_int    : std_logic := '0';
    signal clk4_int    : std_logic := '0';
    signal clk5_int    : std_logic := '0';
begin

    -- Select input clock
    clk_src <= CLKIN1 when CLKINSEL = '1' else CLKIN2;

    -- DRP interface -- stub unused
    DRDY <= '0';
    DO   <= (others => '0');

    -- Feedback clock passthrough (stub: just forward input clock)
    CLKFBOUT <= clk_src;

    -- Lock counter: assert LOCKED after a few rising edges of input clock
    p_lock : process (clk_src, RST)
    begin
        if RST = '1' then
            lock_cnt   <= 0;
            locked_int <= '0';
        elsif rising_edge(clk_src) then
            if lock_cnt < 5 then
                lock_cnt <= lock_cnt + 1;
            else
                locked_int <= '1';
            end if;
        end if;
    end process;

    LOCKED <= locked_int;

    -- CLKOUT0 divider
    p_clk0 : process (clk_src, RST)
    begin
        if RST = '1' then
            div0_cnt <= 0;
            clk0_int <= '0';
        elsif rising_edge(clk_src) then
            if div0_cnt = CLKOUT0_DIVIDE - 1 then
                div0_cnt <= 0;
                clk0_int <= not clk0_int;
            else
                div0_cnt <= div0_cnt + 1;
            end if;
        end if;
    end process;

    -- CLKOUT1 divider
    p_clk1 : process (clk_src, RST)
    begin
        if RST = '1' then
            div1_cnt <= 0;
            clk1_int <= '0';
        elsif rising_edge(clk_src) then
            if div1_cnt = CLKOUT1_DIVIDE - 1 then
                div1_cnt <= 0;
                clk1_int <= not clk1_int;
            else
                div1_cnt <= div1_cnt + 1;
            end if;
        end if;
    end process;

    -- CLKOUT2 divider
    p_clk2 : process (clk_src, RST)
    begin
        if RST = '1' then
            div2_cnt <= 0;
            clk2_int <= '0';
        elsif rising_edge(clk_src) then
            if div2_cnt = CLKOUT2_DIVIDE - 1 then
                div2_cnt <= 0;
                clk2_int <= not clk2_int;
            else
                div2_cnt <= div2_cnt + 1;
            end if;
        end if;
    end process;

    -- CLKOUT3 divider
    p_clk3 : process (clk_src, RST)
    begin
        if RST = '1' then
            div3_cnt <= 0;
            clk3_int <= '0';
        elsif rising_edge(clk_src) then
            if div3_cnt = CLKOUT3_DIVIDE - 1 then
                div3_cnt <= 0;
                clk3_int <= not clk3_int;
            else
                div3_cnt <= div3_cnt + 1;
            end if;
        end if;
    end process;

    -- CLKOUT4 divider
    p_clk4 : process (clk_src, RST)
    begin
        if RST = '1' then
            div4_cnt <= 0;
            clk4_int <= '0';
        elsif rising_edge(clk_src) then
            if div4_cnt = CLKOUT4_DIVIDE - 1 then
                div4_cnt <= 0;
                clk4_int <= not clk4_int;
            else
                div4_cnt <= div4_cnt + 1;
            end if;
        end if;
    end process;

    -- CLKOUT5 divider
    p_clk5 : process (clk_src, RST)
    begin
        if RST = '1' then
            div5_cnt <= 0;
            clk5_int <= '0';
        elsif rising_edge(clk_src) then
            if div5_cnt = CLKOUT5_DIVIDE - 1 then
                div5_cnt <= 0;
                clk5_int <= not clk5_int;
            else
                div5_cnt <= div5_cnt + 1;
            end if;
        end if;
    end process;

    CLKOUT0 <= clk0_int when locked_int = '1' else '0';
    CLKOUT1 <= clk1_int when locked_int = '1' else '0';
    CLKOUT2 <= clk2_int when locked_int = '1' else '0';
    CLKOUT3 <= clk3_int when locked_int = '1' else '0';
    CLKOUT4 <= clk4_int when locked_int = '1' else '0';
    CLKOUT5 <= clk5_int when locked_int = '1' else '0';

end architecture behavioral;

------------------------------------------------------------------------
-- BUFG
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity BUFG is
    port (
        O : out std_ulogic;
        I : in  std_ulogic
    );
end entity BUFG;

architecture behavioral of BUFG is
begin
    O <= I;
end architecture behavioral;

------------------------------------------------------------------------
-- OBUFDS
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity OBUFDS is
    generic (
        IOSTANDARD : string := "DEFAULT"
    );
    port (
        I  : in  std_logic;
        O  : out std_logic;
        OB : out std_logic
    );
end entity OBUFDS;

architecture behavioral of OBUFDS is
begin
    O  <= I;
    OB <= not I;
end architecture behavioral;

------------------------------------------------------------------------
-- LUT6
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LUT6 is
    generic (
        INIT : bit_vector(63 downto 0) := X"0000000000000000"
    );
    port (
        O  : out std_logic;
        I0 : in  std_logic;
        I1 : in  std_logic;
        I2 : in  std_logic;
        I3 : in  std_logic;
        I4 : in  std_logic;
        I5 : in  std_logic
    );
end entity LUT6;

architecture behavioral of LUT6 is
begin
    process (I0, I1, I2, I3, I4, I5)
        variable addr : integer;
    begin
        addr := 0;
        if I0 = '1' then addr := addr + 1;  end if;
        if I1 = '1' then addr := addr + 2;  end if;
        if I2 = '1' then addr := addr + 4;  end if;
        if I3 = '1' then addr := addr + 8;  end if;
        if I4 = '1' then addr := addr + 16; end if;
        if I5 = '1' then addr := addr + 32; end if;
        O <= to_stdulogic(INIT(addr));
    end process;
end architecture behavioral;

------------------------------------------------------------------------
-- CARRY4
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CARRY4 is
    port (
        CO     : out std_logic_vector(3 downto 0);
        O      : out std_logic_vector(3 downto 0);
        CI     : in  std_logic;
        CYINIT : in  std_logic;
        DI     : in  std_logic_vector(3 downto 0);
        S      : in  std_logic_vector(3 downto 0)
    );
end entity CARRY4;

architecture behavioral of CARRY4 is
    signal cy : std_logic_vector(4 downto 0);
begin
    -- Carry-in is OR of CI and CYINIT (only one should be used at a time)
    cy(0) <= CI or CYINIT;

    -- Ripple carry logic
    gen_carry : for i in 0 to 3 generate
        CO(i) <= (S(i) and cy(i)) or (DI(i) and not S(i));
        cy(i+1) <= (S(i) and cy(i)) or (DI(i) and not S(i));
        O(i) <= S(i) xor cy(i);
    end generate;

end architecture behavioral;
