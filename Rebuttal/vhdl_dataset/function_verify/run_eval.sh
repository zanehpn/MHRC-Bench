#!/usr/bin/env bash
# =============================================================================
# run_eval.sh  –  VCS-based VHDL function-verification runner for model eval
# Usage:  EVAL_DIR=<dir> bash run_eval.sh [design_name ...]
#   Uses DUT files from $EVAL_DIR (with <TARGET> filled by LLM) instead of
#   _original.vhd files.  Testbenches and dependencies remain the same.
# =============================================================================
set -uo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$BASE/../../.." && pwd)/.."
WORK="$BASE/.vcs_eval_work"
mkdir -p "$WORK"

# EVAL_DIR contains filled-in DUT files (e.g., counter/counter.vhd)
EVAL_DIR="${EVAL_DIR:-$BASE}"

# Helper: resolve DUT file — use EVAL_DIR version if available, else BASE
dut() {
  local rel="$1"
  if [ -f "$EVAL_DIR/$rel" ]; then
    echo "$EVAL_DIR/$rel"
  else
    echo "$BASE/$rel"
  fi
}

PASS=0; FAIL=0; SKIP=0
# Safe increment (avoids set -e triggering on ((n++)) when n==0)
inc() { eval "$1=\$(( \${$1} + 1 ))"; }
RESULTS=()

# ---------------------------------------------------------------------------
# Ensure libncurses.so symlink exists (VCS linker needs -lncurses)
# ---------------------------------------------------------------------------
if [ ! -e /usr/lib/x86_64-linux-gnu/libncurses.so ]; then
  ln -sf /lib/x86_64-linux-gnu/libncurses.so.5 \
         /usr/lib/x86_64-linux-gnu/libncurses.so 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# run_tb <design_name> <file1> [file2 ...] <tb_file>
#   Files are compiled in the order given.  The last file must be (or contain)
#   the testbench entity.  The testbench entity is discovered by grepping for
#   "entity <name> is" lines whose name ends with _tb (case-insensitive).
# ---------------------------------------------------------------------------
run_tb() {
  local name="$1"; shift
  local files=("$@")

  # ------------------------------------------------------------------
  # Optional filter: if arguments were passed to the script, only run
  # designs whose name matches one of them.
  # ------------------------------------------------------------------
  if [ "${#FILTER[@]}" -gt 0 ]; then
    local match=0
    for f in "${FILTER[@]}"; do
      [[ "$name" == "$f" ]] && match=1 && break
    done
    [ $match -eq 0 ] && return
  fi

  local wdir="$WORK/$name"
  rm -rf "$wdir" && mkdir -p "$wdir"

  # Find testbench entity name (last *_tb entity in the last file)
  local tb_file="${files[-1]}"
  local ent
  ent=$(grep -iE "^[[:space:]]*entity[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+is" \
        "$tb_file" 2>/dev/null \
        | grep -i "_tb" \
        | tail -1 \
        | sed -E 's/.*entity[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+is.*/\1/' \
        | tr '[:upper:]' '[:lower:]') || true
  if [ -z "$ent" ]; then
    ent=$(grep -iE "^[[:space:]]*entity[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+is" \
          "$tb_file" 2>/dev/null \
          | tail -1 \
          | sed -E 's/.*entity[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+is.*/\1/' \
          | tr '[:upper:]' '[:lower:]') || true
  fi

  if [ -z "$ent" ]; then
    printf "SKIP  %-40s (cannot find testbench entity)\n" "$name"
    RESULTS+=("SKIP  $name")
    inc SKIP; return 0
  fi

  cd "$wdir"

  # ---- Compile (analyze) with VHDL-2008 support -------------------------
  if ! vhdlan -full64 -vhdl08 "${files[@]}" > compile.log 2>&1; then
    printf "FAIL  %-40s [compile]\n" "$name"
    grep -iE "^Error|^\*\*Error" compile.log | head -5 || true
    RESULTS+=("FAIL  $name [compile]")
    inc FAIL; cd "$BASE"; return 0
  fi

  # ---- Elaborate ---------------------------------------------------------
  if ! vcs -full64 "work.$ent" > elab.log 2>&1; then
    printf "FAIL  %-40s [elab]\n" "$name"
    grep -iE "^Error|common elaboration failed" elab.log | head -5 || true
    RESULTS+=("FAIL  $name [elab]")
    inc FAIL; cd "$BASE"; return 0
  fi

  # ---- Simulate ----------------------------------------------------------
  timeout 120 ./simv > sim.log 2>&1
  local rc=$?

  # Check for explicit assertion failures (FAIL text)
  if grep -qiE "FAIL[^U]|FAIL$" sim.log 2>/dev/null; then
    printf "FAIL  %-40s [assertion]\n" "$name"
    grep -iE "FAIL" sim.log | head -5 || true
    RESULTS+=("FAIL  $name [assertion]")
    inc FAIL; cd "$BASE"; return 0
  fi

  # Check for VCS runtime errors (Error-[...]) and assertion severity error/failure
  if grep -qE "^Error-|Assertion ERROR|Assertion FAILURE|severity error|severity failure" sim.log 2>/dev/null; then
    printf "FAIL  %-40s [runtime_error]\n" "$name"
    grep -E "^Error-|Assertion|severity" sim.log | head -5 || true
    RESULTS+=("FAIL  $name [runtime_error]")
    inc FAIL; cd "$BASE"; return 0
  fi

  # Check non-zero return code from simulation
  if [ $rc -ne 0 ]; then
    printf "FAIL  %-40s [sim_exit_code=%d]\n" "$name" "$rc"
    RESULTS+=("FAIL  $name [sim_exit_code]")
    inc FAIL; cd "$BASE"; return 0
  fi

  printf "PASS  %-40s\n" "$name"
  RESULTS+=("PASS  $name")
  inc PASS
  cd "$BASE"
  return 0
}

# ---------------------------------------------------------------------------
# run_tb_unisim <design_name> <file1> [file2 ...] <tb_file>
#   Like run_tb but compiles shared UNISIM stubs first into a UNISIM library.
# ---------------------------------------------------------------------------
run_tb_unisim() {
  local name="$1"; shift
  local files=("$@")

  if [ "${#FILTER[@]}" -gt 0 ]; then
    local match=0
    for f in "${FILTER[@]}"; do
      [[ "$name" == "$f" ]] && match=1 && break
    done
    [ $match -eq 0 ] && return
  fi

  local wdir="$WORK/$name"
  rm -rf "$wdir" && mkdir -p "$wdir"
  cd "$wdir"

  mkdir -p work UNISIM
  cat > synopsys_sim.setup << 'SETUP'
WORK > DEFAULT
DEFAULT : ./work
UNISIM : ./UNISIM
SETUP

  if ! vhdlan -full64 -vhdl08 -work UNISIM \
       "$D/unisim_vcomponents.vhd" \
       "$D/unisim_stubs.vhd" > compile.log 2>&1; then
    printf "FAIL  %-40s [compile UNISIM]\n" "$name"
    grep -iE "^Error" compile.log | head -5 || true
    RESULTS+=("FAIL  $name [compile UNISIM]")
    inc FAIL; cd "$BASE"; return 0
  fi

  if ! vhdlan -full64 -vhdl08 "${files[@]}" >> compile.log 2>&1; then
    printf "FAIL  %-40s [compile]\n" "$name"
    grep -iE "^Error" compile.log | head -5 || true
    RESULTS+=("FAIL  $name [compile]")
    inc FAIL; cd "$BASE"; return 0
  fi

  local tb_file="${files[-1]}"
  local ent
  ent=$(grep -iE "^[[:space:]]*entity[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+is" \
        "$tb_file" 2>/dev/null \
        | grep -i "_tb" | tail -1 \
        | sed -E 's/.*entity[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+is.*/\1/' \
        | tr '[:upper:]' '[:lower:]') || true

  if ! vcs -full64 "work.$ent" > elab.log 2>&1; then
    printf "FAIL  %-40s [elab]\n" "$name"
    grep -iE "^Error|common elaboration failed" elab.log | head -5 || true
    RESULTS+=("FAIL  $name [elab]")
    inc FAIL; cd "$BASE"; return 0
  fi

  timeout 120 ./simv > sim.log 2>&1
  local rc_sim=$?
  if grep -qiE "FAIL[^U]|FAIL$" sim.log 2>/dev/null; then
    printf "FAIL  %-40s [assertion]\n" "$name"
    grep -iE "FAIL" sim.log | head -5 || true
    RESULTS+=("FAIL  $name [assertion]")
    inc FAIL; cd "$BASE"; return 0
  fi

  if grep -qE "^Error-|Assertion ERROR|Assertion FAILURE|severity error|severity failure" sim.log 2>/dev/null; then
    printf "FAIL  %-40s [runtime_error]\n" "$name"
    grep -E "^Error-|Assertion|severity" sim.log | head -5 || true
    RESULTS+=("FAIL  $name [runtime_error]")
    inc FAIL; cd "$BASE"; return 0
  fi

  if [ $rc_sim -ne 0 ]; then
    printf "FAIL  %-40s [sim_exit_code=%d]\n" "$name" "$rc_sim"
    RESULTS+=("FAIL  $name [sim_exit_code]")
    inc FAIL; cd "$BASE"; return 0
  fi

  printf "PASS  %-40s\n" "$name"
  RESULTS+=("PASS  $name")
  inc PASS
  cd "$BASE"
  return 0
}

# ---------------------------------------------------------------------------
# run_tb_axi_servo -- special case: needs library mapping + component stubs
# ---------------------------------------------------------------------------
run_tb_axi_servo() {
  local name="axi_rc_servo_controller"

  if [ "${#FILTER[@]}" -gt 0 ]; then
    local match=0
    for f in "${FILTER[@]}"; do
      [[ "$name" == "$f" ]] && match=1 && break
    done
    [ $match -eq 0 ] && return
  fi

  local wdir="$WORK/$name"
  rm -rf "$wdir" && mkdir -p "$wdir"
  cd "$wdir"

  # Create synopsys_sim.setup to map the self-referencing library
  cat > synopsys_sim.setup << 'SETUP'
WORK > DEFAULT
DEFAULT : ./work
axi_rc_servo_controller : ./work
SETUP
  mkdir -p work

  # Compile component stubs and DUT into work (which is also axi_rc_servo_controller)
  if ! vhdlan -full64 -vhdl08 \
       "$D/axi_rc_servo_controller/clock_divider.vhd" \
       "$D/axi_rc_servo_controller/servo_controller_stub.vhd" \
       "$(dut axi_rc_servo_controller/axi_rc_servo_controller.vhd)" \
       "$D/axi_rc_servo_controller/testbench/axi_rc_servo_controller_original_target_tb.vhd" \
       > compile.log 2>&1; then
    printf "FAIL  %-40s [compile]\n" "$name"
    grep -iE "^Error" compile.log | head -5 || true
    RESULTS+=("FAIL  $name [compile]")
    inc FAIL; cd "$BASE"; return 0
  fi

  local ent
  ent=$(grep -iE "^[[:space:]]*entity[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+is" \
        "$D/axi_rc_servo_controller/testbench/axi_rc_servo_controller_original_target_tb.vhd" 2>/dev/null \
        | grep -i "_tb" | tail -1 \
        | sed -E 's/.*entity[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+is.*/\1/' \
        | tr '[:upper:]' '[:lower:]') || true

  if ! vcs -full64 "work.$ent" > elab.log 2>&1; then
    printf "FAIL  %-40s [elab]\n" "$name"
    grep -iE "^Error|common elaboration failed" elab.log | head -5 || true
    RESULTS+=("FAIL  $name [elab]")
    inc FAIL; cd "$BASE"; return 0
  fi

  timeout 120 ./simv > sim.log 2>&1
  local rc_sim=$?
  if grep -qiE "FAIL[^U]|FAIL$" sim.log 2>/dev/null; then
    printf "FAIL  %-40s [assertion]\n" "$name"
    grep -iE "FAIL" sim.log | head -5 || true
    RESULTS+=("FAIL  $name [assertion]")
    inc FAIL; cd "$BASE"; return 0
  fi

  if grep -qE "^Error-|Assertion ERROR|Assertion FAILURE|severity error|severity failure" sim.log 2>/dev/null; then
    printf "FAIL  %-40s [runtime_error]\n" "$name"
    grep -E "^Error-|Assertion|severity" sim.log | head -5 || true
    RESULTS+=("FAIL  $name [runtime_error]")
    inc FAIL; cd "$BASE"; return 0
  fi

  if [ $rc_sim -ne 0 ]; then
    printf "FAIL  %-40s [sim_exit_code=%d]\n" "$name" "$rc_sim"
    RESULTS+=("FAIL  $name [sim_exit_code]")
    inc FAIL; cd "$BASE"; return 0
  fi

  printf "PASS  %-40s\n" "$name"
  RESULTS+=("PASS  $name")
  inc PASS
  cd "$BASE"
  return 0
}

# Collect optional design-name filter from script arguments
FILTER=("$@")

D="$BASE"

# ===========================================================================
# Simple single-file designs (source + testbench, no external deps)
# ===========================================================================

run_tb counter \
  "$(dut counter/counter.vhd)" \
  "$D/counter/testbench/counter_target_tb.vhd"

run_tb risingEdgeDetector \
  "$(dut risingEdgeDetector/risingEdgeDetector.vhd)" \
  "$D/risingEdgeDetector/testbench/risingEdgeDetector_target_tb.vhd"

run_tb btn_debounce \
  "$(dut btn_debounce/btn_debounce.vhd)" \
  "$D/btn_debounce/testbench/btn_debounce_target_tb.vhd"

run_tb pwm_driver \
  "$(dut pwm_driver/pwm_driver.vhd)" \
  "$D/pwm_driver/testbench/pwm_driver_target_tb.vhd"

run_tb servo_controller \
  "$(dut servo_controller/servo_controller.vhd)" \
  "$D/servo_controller/testbench/servo_controller_target_tb.vhd"

run_tb uart_parity \
  "$(dut uart_parity/uart_parity.vhd)" \
  "$D/uart_parity/testbench/uart_parity_target_tb.vhd"

run_tb uart_debouncer \
  "$(dut uart_debouncer/uart_debouncer.vhd)" \
  "$D/uart_debouncer/testbench/uart_debouncer_target_tb.vhd"

run_tb add_preamble \
  "$(dut add_preamble/add_preamble.vhd)" \
  "$D/add_preamble/testbench/add_preamble_target_tb.vhd"

run_tb pulse_cdc \
  "$(dut pulse_cdc/pulse_cdc.vhd)" \
  "$D/pulse_cdc/testbench/pulse_cdc_target_tb.vhd"

# sha256_transform: VCS 2016 doesn't support unconstrained array element types.
# Create a patched temp copy: replace the single unconstrained type with
# multiple concrete types for each element width (32, 256, 512 bits).
_sha256_patch="$WORK/.sha256_transform_patched.vhd"
sed \
  -e 's|type slv_array_type is array (natural range <>) of std_logic_vector;|type slv32_array_type is array (natural range <>) of std_logic_vector(31 downto 0);\n    type slv256_array_type is array (natural range <>) of std_logic_vector(255 downto 0);\n    type slv512_array_type is array (natural range <>) of std_logic_vector(511 downto 0);|' \
  -e 's|slv_array_type(63 downto 0)(C_WORD_SIZE - 1 downto 0)|slv32_array_type(63 downto 0)|' \
  -e 's|slv_array_type(\([^)]*\))(255 downto 0)|slv256_array_type(\1)|g' \
  -e 's|slv_array_type(\([^)]*\))(511 downto 0)|slv512_array_type(\1)|g' \
  "$(dut sha256_transform/sha256_transform.vhd)" > "$_sha256_patch"

run_tb sha256_transform \
  "$_sha256_patch" \
  "$D/sha256_transform/testbench/sha256_transform_target_tb.vhd"

run_tb objectbuffer \
  "$(dut objectbuffer/objectbuffer.vhd)" \
  "$D/objectbuffer/testbench/objectbuffer_target_tb.vhd"

run_tb pattern_generator \
  "$(dut pattern_generator/pattern_generator.vhd)" \
  "$D/pattern_generator/testbench/pattern_generator_target_tb.vhd"

run_tb sample_packer \
  "$(dut sample_packer/sample_packer.vhd)" \
  "$D/sample_packer/testbench/sample_packer_target_tb.vhd"

run_tb spi_master \
  "$(dut spi_master/spi_master.vhd)" \
  "$D/spi_master/testbench/spi_master_target_tb.vhd"

run_tb spi_slave \
  "$(dut spi_slave/spi_slave.vhd)" \
  "$D/spi_slave/testbench/spi_slave_target_tb.vhd"

run_tb spi2axi \
  "$(dut spi2axi/spi2axi.vhd)" \
  "$D/spi2axi/testbench/spi2axi_target_tb.vhd"

run_tb spi \
  "$(dut spi/spi.vhd)" \
  "$D/spi/testbench/spi_target_tb.vhd"

run_tb control \
  "$(dut control/control.vhd)" \
  "$D/control/testbench/control_target_tb.vhd"

run_tb tmds_encoder \
  "$(dut tmds_encoder/tmds_encoder.vhd)" \
  "$D/tmds_encoder/testbench/tmds_encoder_target_tb.vhd"

# rgmii_tx: needs UNISIM library stub for ODDR primitive
run_tb_unisim rgmii_tx \
  "$(dut rgmii_tx/rgmii_tx.vhd)" \
  "$D/rgmii_tx/testbench/rgmii_tx_target_tb.vhd"

run_tb AddressDecoder \
  "$(dut AddressDecoder/AddressDecoder.vhd)" \
  "$D/AddressDecoder/testbench/AddressDecoder_target_tb.vhd"

run_tb MixG_FlopPipe_4 \
  "$(dut MixG_FlopPipe_4/MixG_FlopPipe_4.vhd)" \
  "$D/MixG_FlopPipe_4/testbench/MixG_FlopPipe_4_target_tb.vhd"

run_tb SpiController \
  "$(dut SpiController/SpiController.vhd)" \
  "$D/SpiController/testbench/SpiController_target_tb.vhd"

run_tb disk_ii_rom \
  "$(dut disk_ii_rom/disk_ii_rom.vhd)" \
  "$D/disk_ii_rom/testbench/disk_ii_rom_target_tb.vhd"

# axi_rc_servo_controller: needs library mapping + component stubs
run_tb_axi_servo

# ===========================================================================
# Designs where the testbench defines an inline package used by the DUT.
# Compile testbench FIRST so the package is in the work library before the
# DUT source is analyzed.
# ===========================================================================

# can_tx: testbench defines "package can" that DUT imports via use work.can
run_tb can_tx \
  "$D/can_tx/testbench/can_tx_target_tb.vhd" \
  "$(dut can_tx/can_tx.vhd)"

# nr_r4_cel: testbench defines "package mypackage" (YBITS constant)
run_tb nr_r4_cel \
  "$D/nr_r4_cel/testbench/nr_r4_cel_target_tb.vhd" \
  "$(dut nr_r4_cel/nr_r4_cel.vhd)"

# ===========================================================================
# Designs with local package file (mypackage.vhd) in their source directory
# ===========================================================================

run_tb cond_add \
  "$D/cond_add/mypackage.vhd" \
  "$(dut cond_add/cond_add.vhd)" \
  "$D/cond_add/testbench/cond_add_target_tb.vhd"

# ===========================================================================
# Designs with cross-directory dependencies
# ===========================================================================

# sha256d_wrapper instantiates sha256_transform via component
# Use the patched sha256_transform (see above)
run_tb sha256d_wrapper \
  "$_sha256_patch" \
  "$(dut sha256d_wrapper/sha256d_wrapper.vhd)" \
  "$D/sha256d_wrapper/testbench/sha256d_wrapper_target_tb.vhd"

# uart_tx internally instantiates UART_CLK_DIV and UART_PARITY
# Use local fixed copy of uart_clk_div (original has <TARGET> placeholder)
run_tb uart_tx \
  "$D/uart_tx/uart_clk_div.vhd" \
  "$(dut uart_parity/uart_parity.vhd)" \
  "$(dut uart_tx/uart_tx.vhd)" \
  "$D/uart_tx/testbench/uart_tx_target_tb.vhd"

# I2C_minion instantiates entity work.debounce
# Use local debounce entity (different interface from BTN_DEBOUNCE)
# Patch: add missing scl_rising_reg default reset (VCS-safe temp copy)
_i2c_patch="$WORK/.I2C_minion_patched.vhd"
sed 's/if scl_prev_reg = '\''0'\'' and scl_internal = '\''1'\'' then/scl_rising_reg <= '\''0'\'';\n      if scl_prev_reg = '\''0'\'' and scl_internal = '\''1'\'' then/' \
    "$(dut I2C_minion/I2C_minion.vhd)" > "$_i2c_patch"

run_tb I2C_minion \
  "$D/I2C_minion/debounce.vhd" \
  "$_i2c_patch" \
  "$D/I2C_minion/testbench/I2C_minion_target_tb.vhd"

# ===========================================================================
# NEW DESIGNS (batch 2)
# ===========================================================================

# ---------------------------------------------------------------------------
# Patch external dependencies (all have <TARGET> placeholders)
# ---------------------------------------------------------------------------
_T65_PACK_PATCH="$WORK/.T65_Pack_patched.vhd"
sed 's/<TARGET>/    when Cycle_1=> return Cycle_2;\n    when Cycle_2=> return Cycle_3;/' \
    "$REPO_ROOT/vhdl/Apple-II_MiSTer/rtl/t65/T65_Pack.vhd" > "$_T65_PACK_PATCH"

_PKG_BLAKE_PATCH="$WORK/.PkgBlake2b_patched.vhd"
sed "s/<TARGET>/  constant kHashLen : unsigned(7 downto 0) := x\"20\";/" \
    "$REPO_ROOT/vhdl/SiaFpgaMiner/PkgBlake2b.vhd" > "$_PKG_BLAKE_PATCH"

_QUAD_G_PATCH="$WORK/.QuadG_patched.vhd"
sed 's/<TARGET>/    A_in  : in  U64Array_t(3 downto 0);\n    B_in  : in  U64Array_t(3 downto 0);\n    C_in  : in  U64Array_t(3 downto 0);/' \
    "$REPO_ROOT/vhdl/SiaFpgaMiner/QuadG.vhd" > "$_QUAD_G_PATCH"

_MYPKG_PATCH="$WORK/.MyPkg_patched.vhd"
sed 's/<TARGET>/   subtype sl is std_logic;/' \
    "$REPO_ROOT/vhdl/zynq_tdc/AXITDC/src/MyPkg.vhd" > "$_MYPKG_PATCH"

_ADDERTREE_PATCH="$WORK/.adderTreeLegacy_patched.vhd"
sed 's/<TARGET>/         result := op1 + op2;/' \
    "$REPO_ROOT/vhdl/zynq_tdc/AXITDC/src/adderTreeLegacy.vhd" > "$_ADDERTREE_PATCH"

_RST_SYNC_PATCH="$WORK/.rst_sync_patched.vhd"
sed 's/<TARGET>/begin/' \
    "$REPO_ROOT/vhdl/spi-fpga/examples/common/rst_sync.vhd" > "$_RST_SYNC_PATCH"

_CLK_EN_GEN_PATCH="$WORK/.clk_en_gen_patched.vhd"
sed 's/<TARGET>/            clk_en_1k_reg <= '"'"'0'"'"';\n        elsif (rising_edge(CLK)) then\n            clk_en_1k_reg <= clk_en_1k_comb;\n        end if;\n    end process;/' \
    "$REPO_ROOT/vhdl/spi-fpga/examples/common/clk_en_gen.vhd" > "$_CLK_EN_GEN_PATCH"

_SSEG_DRIVER_PATCH="$WORK/.sseg_driver_patched.vhd"
sed 's/<TARGET>/                sseg_dp    <= not DOTS(2);\n                sseg_anode <= "1011";/' \
    "$REPO_ROOT/vhdl/spi-fpga/examples/common/sseg_driver.vhd" > "$_SSEG_DRIVER_PATCH"

# ---------------------------------------------------------------------------
# Simple single-file designs
# ---------------------------------------------------------------------------

# delayLine uses UNISIM (CARRY4) and entity work.risingEdgeDetector
run_tb_unisim delayLine \
  "$(dut risingEdgeDetector/risingEdgeDetector.vhd)" \
  "$(dut delayLine/delayLine.vhd)" \
  "$D/delayLine/testbench/delayLine_target_tb.vhd"

# uart_1 needs UART_CLK_DIV, UART_PARITY, UART_TX, UART_DEBOUNCER, UART_RX
run_tb uart_1 \
  "$D/uart_tx/uart_clk_div.vhd" \
  "$(dut uart_parity/uart_parity.vhd)" \
  "$(dut uart_debouncer/uart_debouncer.vhd)" \
  "$(dut uart_tx/uart_tx.vhd)" \
  "$D/uart_1/uart_rx_stub.vhd" \
  "$(dut uart_1/uart.vhd)" \
  "$D/uart_1/testbench/uart_target_tb.vhd"

run_tb uart_2 \
  "$(dut uart_2/uart.vhd)" \
  "$D/uart_2/testbench/uart_target_tb.vhd"

# video_generator needs character_rom (stub in apple2_stubs)
run_tb video_generator \
  "$D/apple2/apple2_stubs.vhd" \
  "$(dut video_generator/video_generator.vhd)" \
  "$D/video_generator/testbench/video_generator_original_target_tb.vhd"

run_tb video_vicII_656x \
  "$(dut video_vicII_656x/video_vicII_656x.vhd)" \
  "$D/video_vicII_656x/testbench/video_vicII_656x_original_target_tb.vhd"

# keyboard needs PS2_Ctrl (stub in apple2_stubs)
run_tb keyboard \
  "$D/apple2/apple2_stubs.vhd" \
  "$(dut keyboard/keyboard.vhd)" \
  "$D/keyboard/testbench/keyboard_original_target_tb.vhd"

# Boards_VUnit: testbench-only (original is a VUnit TB, not a DUT)
run_tb Boards_VUnit \
  "$D/Boards_VUnit/testbench/Boards_VUnit_original_target_tb.vhd"

# ===========================================================================
# T65 family — need T65_Pack (patched)
# ===========================================================================
run_tb T65_ALU \
  "$_T65_PACK_PATCH" \
  "$(dut T65_ALU/T65_ALU.vhd)" \
  "$D/T65_ALU/testbench/T65_ALU_original_target_tb.vhd"

run_tb T65_MCode \
  "$_T65_PACK_PATCH" \
  "$(dut T65_MCode/T65_MCode.vhd)" \
  "$D/T65_MCode/testbench/T65_MCode_original_target_tb.vhd"

run_tb T65 \
  "$_T65_PACK_PATCH" \
  "$(dut T65_MCode/T65_MCode.vhd)" \
  "$(dut T65_ALU/T65_ALU.vhd)" \
  "$(dut T65/T65.vhd)" \
  "$D/T65/testbench/T65_original_target_tb.vhd"

# ===========================================================================
# Blake2bMinerCore — needs PkgBlake2b + QuadG (both patched)
# ===========================================================================
# QuadG uses entity work.MixG_FlopPipe_4 — must compile it first
run_tb Blake2bMinerCore \
  "$_PKG_BLAKE_PATCH" \
  "$(dut MixG_FlopPipe_4/MixG_FlopPipe_4.vhd)" \
  "$_QUAD_G_PATCH" \
  "$(dut Blake2bMinerCore/Blake2bMinerCore.vhd)" \
  "$D/Blake2bMinerCore/testbench/Blake2bMinerCore_target_tb.vhd"

# ===========================================================================
# encoder — needs MyPkg + adderTreeLegacy (both patched)
# ===========================================================================
# encoder uses UNISIM library
run_tb_unisim encoder \
  "$_MYPKG_PATCH" \
  "$_ADDERTREE_PATCH" \
  "$(dut encoder/encoder.vhd)" \
  "$D/encoder/testbench/encoder_target_tb.vhd"

# ===========================================================================
# spi_loopback — needs many sub-entities (all patched)
# ===========================================================================
run_tb spi_loopback \
  "$_RST_SYNC_PATCH" \
  "$_CLK_EN_GEN_PATCH" \
  "$(dut btn_debounce/btn_debounce.vhd)" \
  "$(dut spi_master/spi_master.vhd)" \
  "$(dut spi_slave/spi_slave.vhd)" \
  "$_SSEG_DRIVER_PATCH" \
  "$(dut spi_loopback/spi_loopback.vhd)" \
  "$D/spi_loopback/testbench/spi_loopback_target_tb.vhd"

# ===========================================================================
# serializer — needs UNISIM (OSERDESE2 + OBUFDS)
# ===========================================================================
run_tb_unisim serializer \
  "$(dut serializer/serializer.vhd)" \
  "$D/serializer/testbench/serializer_target_tb.vhd"

# ===========================================================================
# Clocking_K7 — needs UNISIM (PLLE2_ADV, BUFG)
# ===========================================================================
run_tb_unisim Clocking_K7 \
  "$(dut Clocking_K7/Clocking_K7.vhd)" \
  "$D/Clocking_K7/testbench/Clocking_K7_original_target_tb.vhd"

# ===========================================================================
# Mandelbrot — needs ieee.fixed_pkg (VCS 2016 limitation: not available)
# Patching ieee_proposed→ieee doesn't help since VCS 2016 lacks the package.
# These designs are skipped if ieee.fixed_pkg is unavailable.
# ===========================================================================
_CUST_FIXED_SRC="$REPO_ROOT/vhdl/MandelbrotInVHDL/GHDL/src/custom_fixed_point_types.vhdl"
_PIPE_TYPES_SRC="$REPO_ROOT/vhdl/MandelbrotInVHDL/GHDL/src/pipeline_types.vhdl"

_CUST_FIXED_PATCH="$WORK/.custom_fixed_point_types_patched.vhd"
_PIPE_TYPES_PATCH="$WORK/.pipeline_types_patched.vhd"
_MANDELBROT_UC_PATCH="$WORK/.Mandelbrot_patched.vhd"

sed 's/<TARGET>/constant integerPart : integer := 6;/' "$_CUST_FIXED_SRC" > "$_CUST_FIXED_PATCH"
sed 's/<TARGET>/subtype iterations is unsigned(7 downto 0);/' "$_PIPE_TYPES_SRC" > "$_PIPE_TYPES_PATCH"
sed -e 's/library ieee_proposed;/library ieee;/' \
    -e 's/use ieee_proposed\.fixed_pkg\.all;/use ieee.fixed_pkg.all;/' \
    "$(dut Mandelbrot/Mandelbrot.vhd)" > "$_MANDELBROT_UC_PATCH"

# Mandelbrot designs need ieee.fixed_pkg which VCS 2016 lacks.
# We provide a work-library replacement (fixed_pkg.vhd) and patch the DUTs
# to use work.fixed_pkg instead of ieee.fixed_pkg / ieee_proposed.fixed_pkg.

_MANDELBROT_UC_PATCH2="$WORK/.Mandelbrot_patched2.vhd"
sed -e 's/^library ieee_proposed;/-- library ieee_proposed;  -- replaced by work.fixed_pkg/' \
    -e 's/use ieee_proposed\.fixed_pkg\.all;/use work.fixed_pkg.all;/' \
    "$(dut Mandelbrot/Mandelbrot.vhd)" > "$_MANDELBROT_UC_PATCH2"

_CUST_FIXED_PATCH2="$WORK/.custom_fixed_point_types_patched2.vhd"
sed -e 's/<TARGET>/constant integerPart : integer := 6;/' \
    -e 's/use ieee\.fixed_pkg\.all;/use work.fixed_pkg.all;/' \
    "$_CUST_FIXED_SRC" > "$_CUST_FIXED_PATCH2"

_PIPE_TYPES_PATCH2="$WORK/.pipeline_types_patched2.vhd"
sed 's/<TARGET>/subtype iterations is unsigned(7 downto 0);/' \
    "$_PIPE_TYPES_SRC" > "$_PIPE_TYPES_PATCH2"

run_tb Mandelbrot \
  "$D/fixed_pkg.vhd" \
  "$_CUST_FIXED_PATCH2" \
  "$_PIPE_TYPES_PATCH2" \
  "$_MANDELBROT_UC_PATCH2" \
  "$D/Mandelbrot/testbench/Mandelbrot_target_tb.vhd"

_MANDELBROT_LC_PATCH2="$WORK/.mandelbrot_lc_patched2.vhdl"
sed -e 's/<TARGET>//' \
    -e 's/use ieee\.fixed_pkg\.all;/use work.fixed_pkg.all;\nuse ieee.std_logic_textio.all;/' \
    "$(dut mandelbrot/mandelbrot.vhdl)" > "$_MANDELBROT_LC_PATCH2"

run_tb mandelbrot \
  "$D/fixed_pkg.vhd" \
  "$_CUST_FIXED_PATCH2" \
  "$_PIPE_TYPES_PATCH2" \
  "$D/mandelbrot/test_data.vhd" \
  "$_MANDELBROT_LC_PATCH2" \
  "$D/mandelbrot/testbench/mandelbrot_target_tb.vhd"

# ===========================================================================
# apple2 — needs T65 family + stubs for other sub-entities
# ===========================================================================
run_tb apple2 \
  "$_T65_PACK_PATCH" \
  "$(dut T65_MCode/T65_MCode.vhd)" \
  "$(dut T65_ALU/T65_ALU.vhd)" \
  "$(dut T65/T65.vhd)" \
  "$D/apple2/apple2_stubs.vhd" \
  "$(dut video_generator/video_generator.vhd)" \
  "$(dut keyboard/keyboard.vhd)" \
  "$(dut apple2/apple2.vhd)" \
  "$D/apple2/testbench/apple2_original_target_tb.vhd"

# ===========================================================================
# miner_top — needs sha256d_wrapper + pulse_cdc + stubs
# ===========================================================================
run_tb miner_top \
  "$_sha256_patch" \
  "$(dut sha256d_wrapper/sha256d_wrapper.vhd)" \
  "$(dut pulse_cdc/pulse_cdc.vhd)" \
  "$D/miner_top/miner_top_stubs.vhd" \
  "$(dut miner_top/miner_top.vhd)" \
  "$D/miner_top/testbench/miner_top_target_tb.vhd"

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "============================================================"
printf "  PASS: %d   FAIL: %d   SKIP: %d\n" "$PASS" "$FAIL" "$SKIP"
echo "============================================================"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed designs:"
  for r in "${RESULTS[@]}"; do
    [[ "$r" == FAIL* ]] && echo "  $r"
  done
fi
echo ""
[ $FAIL -eq 0 ]   # exit 0 iff no failures
