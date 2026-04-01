#!/usr/bin/env python3
"""
Rule-based classifier for HDL code snippets.
Snippet-level classification: each entry is classified based on its own
groundtruth content + nearby context (left_context tail / right_context head).
Supports: SystemVerilog, VHDL, Chisel, HLS C/C++
"""

import json
import re
import argparse
import os
from typing import Tuple
from collections import defaultdict

RE_I = re.IGNORECASE

# ============================================================
# Helpers
# ============================================================
def _c(pattern, flags=0):
    return re.compile(pattern, flags)

def cnt(text, patterns):
    """Count total matches."""
    return sum(len(p.findall(text)) for p in patterns)

def has(text, patterns):
    """Check if any pattern matches."""
    return any(p.search(text) for p in patterns)


def _get_texts(entry):
    """Return (groundtruth, nearby_context, full_context)."""
    gt = entry.get('groundtruth', '')
    lc = entry.get('left_context', '')
    rc = entry.get('right_context', '')
    # Nearby: last 400 chars of left + first 400 chars of right
    near_lc = lc[-400:] if len(lc) > 400 else lc
    near_rc = rc[:400] if len(rc) > 400 else rc
    near = near_lc + '\n' + gt + '\n' + near_rc
    full = lc + '\n' + gt + '\n' + rc
    return gt, near, full


# ============================================================
# SystemVerilog snippet-level classifier
# ============================================================
def classify_sv(entry) -> Tuple[str, str, float, str]:
    gt, near, full = _get_texts(entry)
    gt_s = gt.strip()

    # ----------------------------------------------------------
    # 1. Property and Assertion Specification
    # ----------------------------------------------------------
    if has(gt, [_c(r'\bassert\s+property\b', RE_I),
                _c(r'\bcover\s+property\b', RE_I),
                _c(r'\bassume\s+property\b', RE_I)]):
        return 'Property and Assertion Specification', 'Assertion Definition', 0.90, \
               'Contains assert/cover/assume property statement'

    if has(gt, [_c(r'\bproperty\s+\w+', RE_I)]) and has(gt, [_c(r'\bendproperty\b', RE_I)]):
        return 'Property and Assertion Specification', 'Assertion Definition', 0.85, \
               'Property definition block'

    if has(gt, [_c(r'\bproperty\s+\w+', RE_I)]) and has(near, [_c(r'\bassert\s+property\b', RE_I)]):
        return 'Property and Assertion Specification', 'Assertion Definition', 0.80, \
               'Property definition near assert property'

    # ----------------------------------------------------------
    # 2. Monitoring and Checking Logic
    # ----------------------------------------------------------
    display_in_gt = cnt(gt, [_c(r'\$(display|error|warning|fatal|info|write|monitor|fwrite)\b')])
    if display_in_gt >= 1:
        # If inside initial/always block, could be testbench
        # If standalone or in macro definition, it's monitoring
        if has(gt, [_c(r'`define\b')]) or has(gt, [_c(r'`ASSERT\b')]):
            return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.85, \
                   'Display/error macro definition'
        # If not in testbench context (no initial block nearby driving signals)
        if not has(gt, [_c(r'\binitial\b', RE_I)]) and not has(gt, [_c(r'#\d+')]):
            if display_in_gt >= 2 or not has(near, [_c(r'\binitial\b', RE_I)]):
                return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.75, \
                       'Display/error statement'

    # ----------------------------------------------------------
    # 3. Testbench Stimulus and Environment
    # ----------------------------------------------------------
    # UVM class definition
    if has(gt, [_c(r'\bextends\s+uvm_(test|env|agent|driver|monitor|scoreboard|subscriber)\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Environment and Harness Construction', 0.90, \
               'UVM testbench class definition'
    if has(gt, [_c(r'\bextends\s+uvm_sequence\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Test Scenario and Sequencing', 0.90, \
               'UVM sequence class definition'
    if has(gt, [_c(r'\buvm_config_db\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Environment and Harness Construction', 0.85, \
               'UVM config_db usage'

    # initial block with clock/signal driving
    if has(gt, [_c(r'\binitial\b', RE_I)]):
        if has(gt, [_c(r'(clk|clock)\s*[=<]', RE_I), _c(r'\bforever\b', RE_I),
                     _c(r'#\d+'), _c(r'\$finish\b'), _c(r'\$stop\b')]):
            return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.85, \
                   'Initial block with clock/delay/finish'
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.70, \
               'Initial block'

    # Delay-heavy code (not in always block)
    if cnt(gt, [_c(r'#\d+')]) >= 2 and not has(gt, [_c(r'\balways\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.75, \
               'Multiple delay statements'

    # $finish / $stop
    if has(gt, [_c(r'\$finish\b'), _c(r'\$stop\b')]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.70, \
               '$finish/$stop statement'

    # DUT instantiation in testbench context
    if has(gt, [_c(r'\b(dut|uut)\b', RE_I)]) and has(gt, [_c(r'\.\w+\s*\(')]):
        return 'Testbench Stimulus and Environment', 'Environment and Harness Construction', 0.80, \
               'DUT/UUT instantiation'

    # wait statement
    if has(gt, [_c(r'\bwait\s*\(', RE_I)]):
        if has(near, [_c(r'\binitial\b', RE_I), _c(r'\$finish\b')]):
            return 'Testbench Stimulus and Environment', 'Test Scenario and Sequencing', 0.75, \
                   'Wait statement in testbench context'

    # clocking block
    if has(gt, [_c(r'\bclocking\b', RE_I)]) and has(gt, [_c(r'\bendclocking\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Environment and Harness Construction', 0.80, \
               'Clocking block definition'

    # forever block
    if has(gt, [_c(r'\bforever\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.75, \
               'Forever block (clock generation)'

    # ----------------------------------------------------------
    # 4. Design Structure
    # ----------------------------------------------------------
    # module definition
    if has(gt, [_c(r'\bmodule\s+\w+', RE_I)]):
        return 'Design Structure', 'Top-level Structure', 0.85, \
               'Module definition'

    if has(gt, [_c(r'\bendmodule\b', RE_I)]):
        return 'Design Structure', 'Top-level Structure', 0.80, \
               'Endmodule'

    # package / endpackage
    if has(gt, [_c(r'\bpackage\s+\w+', RE_I)]) or has(gt, [_c(r'\bendpackage\b', RE_I)]):
        return 'Design Structure', 'Package and Namespace Definition', 0.85, \
               'Package definition'

    # import / include
    if has(gt, [_c(r'\bimport\s+\w+::', RE_I)]) or has(gt, [_c(r'`include\b')]):
        # Only if this is the main content (not part of larger block)
        if not has(gt, [_c(r'\balways\b', RE_I), _c(r'\binitial\b', RE_I), _c(r'\bassign\b', RE_I)]):
            return 'Design Structure', 'Package and Namespace Definition', 0.75, \
                   'Import/include statement'

    # ----------------------------------------------------------
    # 5. Interface — Port Definition
    # ----------------------------------------------------------
    # input/output/inout declarations
    port_count = cnt(gt, [_c(r'\b(input|output|inout)\s+', RE_I)])
    if port_count >= 1:
        # Make sure it's a port declaration, not inside behavioral block
        if not has(gt, [_c(r'\balways\b', RE_I), _c(r'\binitial\b', RE_I),
                        _c(r'\bif\s*\(', RE_I), _c(r'\bcase\b', RE_I)]):
            return 'Interface', 'Port Definition', 0.85, \
                   'Port declaration (input/output/inout)'

    # UVM port/imp/export
    if has(gt, [_c(r'\buvm_\w+_(port|imp|export)\b', RE_I)]):
        return 'Interface', 'Port Definition', 0.85, \
               'UVM port/imp/export declaration'

    # ----------------------------------------------------------
    # 6. Interface — Component and Module Connection
    # ----------------------------------------------------------
    # Module instantiation: .port(signal) patterns
    dot_count = cnt(gt, [_c(r'\.\w+\s*\(\s*\w+')])
    if dot_count >= 2:
        if not has(gt, [_c(r'\balways\b', RE_I), _c(r'\binitial\b', RE_I),
                        _c(r'\b(input|output)\b', RE_I)]):
            # Check if in module instantiation context
            if has(near, [_c(r'\.\w+\s*\(')]):
                return 'Interface', 'Component and Module Connection', 0.80, \
                       'Module instantiation with port connections'

    # ----------------------------------------------------------
    # 7. Interface — Handshake and Flow Control
    # ----------------------------------------------------------
    if has(gt, [_c(r'\bvalid\s*<=|\bvalid\s*=|\.valid\b', RE_I)]) and \
       has(gt, [_c(r'\bready\s*<=|\bready\s*=|\.ready\b', RE_I)]):
        return 'Interface', 'Handshake and Flow Control', 0.80, \
               'Valid/ready handshake logic'

    if has(gt, [_c(r'(tvalid|tready|awvalid|awready|wvalid|wready|arvalid|arready|rvalid|rready|bvalid|bready)', RE_I)]):
        if has(gt, [_c(r'<=|=')]):
            return 'Interface', 'Handshake and Flow Control', 0.80, \
                   'AXI handshake signal assignment'

    # ----------------------------------------------------------
    # 8. Storage Block
    # ----------------------------------------------------------
    # always_ff block
    if has(gt, [_c(r'\balways_ff\s+@', RE_I)]):
        if has(gt, [_c(r'\bmemory\s*\[|\bmem\s*\[|\bram\s*\[', RE_I)]):
            return 'Storage Block', 'Memory and Array Storage', 0.85, \
                   'always_ff with memory/array access'
        return 'Storage Block', 'Register-based Storage', 0.85, \
               'always_ff block (register inference)'

    # always @(posedge ...) with non-blocking assignment (sequential logic)
    if has(gt, [_c(r'\balways\s*@\s*\(\s*posedge', RE_I)]):
        if has(gt, [_c(r'<=')]):
            if has(gt, [_c(r'\bmemory\s*\[|\bmem\s*\[|\bram\s*\[', RE_I)]):
                return 'Storage Block', 'Memory and Array Storage', 0.80, \
                       'Clocked always with memory access'
            return 'Storage Block', 'Register-based Storage', 0.80, \
                   'Clocked always block with non-blocking assignment'

    # Memory array read/write in clocked context
    if has(gt, [_c(r'\bmemory\s*\[|\bmem\s*\[|\bram\s*\[', RE_I)]):
        if has(gt, [_c(r'<=')]):
            return 'Storage Block', 'Memory and Array Storage', 0.75, \
                   'Memory array write'
        if has(near, [_c(r'\balways_ff\b|\balways\s*@\s*\(\s*posedge', RE_I)]):
            return 'Storage Block', 'Memory and Array Storage', 0.70, \
                   'Memory array access in clocked context'

    # ----------------------------------------------------------
    # 9. Control Flow Block
    # ----------------------------------------------------------
    # State machine: case with state
    if has(gt, [_c(r'\bcase\b', RE_I)]):
        if has(gt, [_c(r'\bstate\b|STATE_', RE_I)]) or has(near, [_c(r'\bnext_state\b', RE_I)]):
            return 'Control Flow Block', 'State-machine Control', 0.85, \
                   'Case statement with state variables'
        return 'Control Flow Block', 'State-machine Control', 0.75, \
               'Case statement'

    if has(gt, [_c(r'\bendcase\b', RE_I)]):
        return 'Control Flow Block', 'State-machine Control', 0.70, \
               'Endcase'

    # next_state / next_*_state assignment
    if has(gt, [_c(r'\bnext_\w*state\b', RE_I)]):
        return 'Control Flow Block', 'State-machine Control', 0.85, \
               'next_state assignment'

    # STATE_ constants
    if cnt(gt, [_c(r'STATE_\w+')]) >= 2:
        return 'Control Flow Block', 'State-machine Control', 0.80, \
               'State constant references'

    # if/else in always block
    if has(gt, [_c(r'\bif\s*\(', RE_I)]):
        if has(gt, [_c(r'\balways\b', RE_I)]) or has(near, [_c(r'\balways\b', RE_I)]):
            # Check if it's in a clocked context (storage) or combinational (control)
            if has(near, [_c(r'\balways_comb\b', RE_I)]) or \
               (has(near, [_c(r'\balways\s*@\s*\(\s*\*\s*\)', RE_I)])):
                return 'Control Flow Block', 'Conditional Control', 0.75, \
                       'If statement in combinational always block'
            if has(gt, [_c(r'\bstate\b', RE_I)]):
                return 'Control Flow Block', 'Conditional Control', 0.75, \
                       'If statement with state variable'

    # ----------------------------------------------------------
    # 10. Declaration and Definition
    # ----------------------------------------------------------
    # parameter / localparam
    if has(gt, [_c(r'\bparameter\b', RE_I), _c(r'\blocalparam\b', RE_I)]):
        return 'Declaration and Definition', 'Parameter and Generic Definition', 0.85, \
               'Parameter/localparam definition'

    # `define / `timescale
    if has(gt, [_c(r'`define\b'), _c(r'`timescale\b')]):
        return 'Declaration and Definition', 'Parameter and Generic Definition', 0.85, \
               'Preprocessor define/timescale'

    # function / task definition
    if has(gt, [_c(r'\bfunction\b', RE_I), _c(r'\bendfunction\b', RE_I),
                _c(r'\btask\b', RE_I), _c(r'\bendtask\b', RE_I)]):
        return 'Declaration and Definition', 'Function and Procedure Signature', 0.80, \
               'Function/task definition'

    # typedef / struct
    if has(gt, [_c(r'\btypedef\b', RE_I)]):
        return 'Declaration and Definition', 'Type Definition', 0.80, \
               'Typedef definition'

    # wire / logic / reg declaration (standalone, not port)
    if has(gt, [_c(r'\b(wire|logic|reg)\s+', RE_I)]):
        if not has(gt, [_c(r'\b(input|output|inout)\b', RE_I),
                        _c(r'\balways\b', RE_I), _c(r'\binitial\b', RE_I)]):
            return 'Declaration and Definition', 'Signal and Wire Declaration', 0.75, \
                   'Wire/logic/reg signal declaration'

    # ----------------------------------------------------------
    # 11. Computation Block
    # ----------------------------------------------------------
    # assign with bit operations
    if has(gt, [_c(r'\bassign\b', RE_I)]):
        if has(gt, [_c(r'\{.*,.*\}'), _c(r'\[\d+:\d+\]'), _c(r'<<|>>'),
                     _c(r'[\^~|&]')]):
            return 'Computation Block', 'Bit-level Manipulation', 0.80, \
                   'Assign with bit operations'
        if has(gt, [_c(r'[\+\-\*/%]')]):
            return 'Computation Block', 'Bit-level Manipulation', 0.75, \
                   'Assign with arithmetic'
        return 'Computation Block', 'Bit-level Manipulation', 0.65, \
               'Continuous assignment'

    # Concatenation / bit slicing standalone
    if has(gt, [_c(r'\{.*,.*\}')]) and has(gt, [_c(r'\[\d+:\d+\]')]):
        return 'Computation Block', 'Bit-level Manipulation', 0.70, \
               'Bit concatenation/slicing'

    # ----------------------------------------------------------
    # 12. Remaining Interface (port connection in context)
    # ----------------------------------------------------------
    if dot_count >= 1 and has(near, [_c(r'\.\w+\s*\(\s*\w+\s*\)')]):
        if cnt(near, [_c(r'\.\w+\s*\(')]) >= 4:
            return 'Interface', 'Component and Module Connection', 0.65, \
                   'Port connection in instantiation context'

    # ----------------------------------------------------------
    # 13. Remaining Control Flow (if/else not yet classified)
    # ----------------------------------------------------------
    if has(gt, [_c(r'\bif\s*\(', RE_I), _c(r'\belse\b', RE_I)]):
        if has(gt, [_c(r'<=')]):
            # Non-blocking in if/else → likely sequential control
            if has(near, [_c(r'\bstate\b', RE_I)]):
                return 'Control Flow Block', 'State-machine Control', 0.65, \
                       'If/else with state in context'
            return 'Control Flow Block', 'Conditional Control', 0.60, \
                   'If/else with non-blocking assignment'

    # ----------------------------------------------------------
    # 14. UVM-related (catch-all)
    # ----------------------------------------------------------
    if has(gt, [_c(r'\buvm_\w+', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Environment and Harness Construction', 0.65, \
               'UVM-related code'

    # ----------------------------------------------------------
    # 15. Non-blocking assignment in clocked context
    # ----------------------------------------------------------
    if has(gt, [_c(r'<=')]) and not has(gt, [_c(r'\bassign\b', RE_I)]):
        if has(near, [_c(r'\balways_ff\b|\balways\s*@\s*\(\s*posedge', RE_I)]):
            return 'Storage Block', 'Register-based Storage', 0.60, \
                   'Non-blocking assignment in clocked context'
        if has(near, [_c(r'\balways\b', RE_I)]):
            return 'Control Flow Block', 'Conditional Control', 0.55, \
                   'Non-blocking assignment in always block'

    # ----------------------------------------------------------
    # 16. Ternary operator
    # ----------------------------------------------------------
    if has(gt, [_c(r'\?\s*\S+\s*:')]):
        return 'Computation Block', 'Bit-level Manipulation', 0.65, \
               'Ternary conditional expression'

    # ----------------------------------------------------------
    # 17. Additional patterns to reduce fallback
    # ----------------------------------------------------------
    # return statement (inside function/case) → Control Flow
    if has(gt, [_c(r'\breturn\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.65, \
               'Return statement in function/case'

    # Bit-slice or concat without assign → Computation
    if has(gt, [_c(r'\[\d+:\d+\]')]) and has(gt, [_c(r'<=|=')]):
        return 'Computation Block', 'Bit-level Manipulation', 0.60, \
               'Bit-slice with assignment'

    # begin/end with if → Control Flow
    if has(gt, [_c(r'\bbegin\b', RE_I)]) and has(gt, [_c(r'\bif\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.60, \
               'Begin/if block'

    # UVM macro usage → Testbench
    if has(gt, [_c(r'`uvm_\w+', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Environment and Harness Construction', 0.65, \
               'UVM macro'

    # constraint → Declaration
    if has(gt, [_c(r'\bconstraint\b', RE_I)]):
        return 'Declaration and Definition', 'Function and Procedure Signature', 0.65, \
               'Constraint definition'

    # Module instantiation with .* or single .port()
    if has(gt, [_c(r'\.\*')]) or (dot_count >= 1 and has(near, [_c(r'\.\w+\s*\(')])):
        return 'Interface', 'Component and Module Connection', 0.60, \
               'Module instantiation connection'

    # Blocking assignment with arithmetic → Computation
    if has(gt, [_c(r'=.*[\+\-\*]')]) and not has(gt, [_c(r'<=|==|!=')]):
        return 'Computation Block', 'Bit-level Manipulation', 0.60, \
               'Blocking assignment with arithmetic'

    # Non-blocking <= anywhere → likely in sequential context
    if has(gt, [_c(r'<=')]) and not has(gt, [_c(r'==|!=|>=')]):
        return 'Storage Block', 'Register-based Storage', 0.55, \
               'Non-blocking assignment'

    # end/endmodule/endfunction → Design Structure
    if has(gt, [_c(r'\bend\b', RE_I)]) and not has(gt, [_c(r'<=|=|if|else', RE_I)]):
        return 'Design Structure', 'Top-level Structure', 0.50, \
               'Block end statement'

    # ----------------------------------------------------------
    # Fallback (last resort)
    # ----------------------------------------------------------
    if has(near, [_c(r'\binitial\b', RE_I), _c(r'\$finish\b')]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.60, \
               'Code in testbench context'

    if has(near, [_c(r'\balways\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.60, \
               'Code in always block context'

    return 'Declaration and Definition', 'Signal and Wire Declaration', 0.50, \
           'General declaration/definition'


# ============================================================
# VHDL snippet-level classifier
# ============================================================
def classify_vhdl(entry) -> Tuple[str, str, float, str]:
    gt, near, full = _get_texts(entry)

    # 1. Testbench
    if has(gt, [_c(r'\bwait\s+for\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.85, \
               'wait for statement (stimulus timing)'
    if has(gt, [_c(r'\bwait\s+until\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.80, \
               'wait until statement'

    # 1b. Monitoring and Checking Logic
    if has(gt, [_c(r'\breport\b', RE_I)]) and has(gt, [_c(r'\bassert\b', RE_I)]):
        return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.85, \
               'Assert with report (checking logic)'
    if has(gt, [_c(r'\breport\s+"', RE_I)]):
        return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.75, \
               'Report statement'
    if has(gt, [_c(r'\bassert\b', RE_I)]) and has(gt, [_c(r'\bseverity\b', RE_I)]):
        return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.80, \
               'Assert with severity'

    # 1c. Design Issues
    if has(gt, [_c(r'--\s*(todo|fixme|hack|bug|note|warning)\b', RE_I)]):
        return 'Design Issues', 'Clarification', 0.70, 'TODO/FIXME/note comment'

    # 2. Design Structure
    if has(gt, [_c(r'\bentity\s+\w+\s+is\b', RE_I)]):
        return 'Design Structure', 'Top-level Structure', 0.90, 'Entity declaration'
    if has(gt, [_c(r'\barchitecture\s+\w+\s+of\b', RE_I)]):
        return 'Design Structure', 'Top-level Structure', 0.90, 'Architecture declaration'
    if has(gt, [_c(r'\bend\s+(entity|architecture)\b', RE_I)]):
        return 'Design Structure', 'Top-level Structure', 0.80, 'End entity/architecture'
    if has(gt, [_c(r'\bpackage\s+\w+\s+is\b', RE_I)]) or has(gt, [_c(r'\bpackage\s+body\b', RE_I)]):
        return 'Design Structure', 'Package and Namespace Definition', 0.85, 'Package definition'
    if has(gt, [_c(r'\blibrary\s+\w+', RE_I)]) and has(gt, [_c(r'\buse\s+\w+\.\w+', RE_I)]):
        return 'Design Structure', 'Package and Namespace Definition', 0.80, 'Library/use declaration'
    if has(gt, [_c(r'\bgeneric\s*\(', RE_I)]):
        return 'Design Structure', 'Parameterization and Configuration', 0.80, 'Generic clause'
    if has(gt, [_c(r'\bgenerate\b', RE_I)]):
        return 'Design Structure', 'Hierarchical Composition', 0.80, 'Generate statement'
    if has(gt, [_c(r'\bconfiguration\b', RE_I)]):
        return 'Design Structure', 'Parameterization and Configuration', 0.75, 'Configuration'

    # 3. Interface
    if has(gt, [_c(r'\bport\s+map\b', RE_I)]):
        return 'Interface', 'Component and Module Connection', 0.85, 'Port map'
    if has(gt, [_c(r'\bgeneric\s+map\b', RE_I)]):
        return 'Interface', 'Component and Module Connection', 0.80, 'Generic map'
    if has(gt, [_c(r'\bcomponent\s+\w+', RE_I)]):
        return 'Interface', 'Component and Module Connection', 0.75, 'Component declaration'
    if has(gt, [_c(r':\s*(in|out|inout|buffer)\s+(std_logic|std_ulogic|unsigned|signed|integer|natural|bit)', RE_I)]):
        return 'Interface', 'Port Definition', 0.85, 'Port direction with type'
    if has(gt, [_c(r'\bport\s*\(', RE_I)]):
        return 'Interface', 'Port Definition', 0.80, 'Port clause'
    # protocol
    if has(gt, [_c(r'\b(axi|wishbone|amba|avalon)\b', RE_I)]):
        if has(gt, [_c(r':\s*(in|out)\b', RE_I)]) or has(gt, [_c(r'<=|:=')]):
            return 'Interface', 'Protocol-based Interface', 0.75, 'Protocol interface signal'
    if has(gt, [_c(r'\b(s_axi_|m_axi_|axi_\w+)', RE_I)]) and has(gt, [_c(r'<=|:\s*(in|out)', RE_I)]):
        return 'Interface', 'Protocol-based Interface', 0.75, 'AXI interface signal'

    # 3b. Property and Assertion (PSL / assert)
    if has(gt, [_c(r'\bassert\b', RE_I)]) and not has(gt, [_c(r'\breport\b', RE_I)]):
        if has(gt, [_c(r'\bpsl\b', RE_I)]) or has(near, [_c(r'\bpsl\b', RE_I)]):
            return 'Property and Assertion Specification', 'Assertion Definition', 0.80, \
                   'PSL assertion'

    # 4. Storage
    if has(gt, [_c(r"\brising_edge\s*\(", RE_I), _c(r"\bfalling_edge\s*\(", RE_I),
                _c(r"'event\s+and", RE_I)]):
        return 'Storage Block', 'Register-based Storage', 0.85, 'Clock edge detection (register)'

    if has(gt, [_c(r'\bprocess\b', RE_I)]) and has(gt, [_c(r'\b(clk|clock)\b', RE_I)]):
        if has(gt, [_c(r'<=')]):
            return 'Storage Block', 'Register-based Storage', 0.80, 'Clocked process with assignment'

    # 5. Control Flow
    if has(gt, [_c(r'\bcase\b.*\bis\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.80, 'Case statement'
    if has(gt, [_c(r'\bprocess\b', RE_I)]) and has(gt, [_c(r'\bif\b.*\bthen\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.75, 'Process with if-then'
    if has(gt, [_c(r'\bif\b.*\bthen\b', RE_I)]):
        if has(near, [_c(r'\bprocess\b', RE_I)]):
            return 'Control Flow Block', 'Conditional Control', 0.70, 'If-then in process context'

    # 6. Computation
    if has(gt, [_c(r'\bwith\b.*\bselect\b', RE_I)]):
        return 'Computation Block', 'Mux and Selection Logic', 0.85, 'With-select multiplexer'
    if has(gt, [_c(r'<=.*\bwhen\b.*\belse\b', RE_I)]):
        return 'Computation Block', 'Mux and Selection Logic', 0.80, 'When-else conditional assignment'
    if has(gt, [_c(r'<=.*\bwhen\b', RE_I)]):
        return 'Computation Block', 'Mux and Selection Logic', 0.75, 'When conditional assignment'

    if has(gt, [_c(r'<=.*[\+\-\*]')]):
        return 'Computation Block', 'Arithmetic Computation', 0.75, 'Arithmetic signal assignment'

    if has(gt, [_c(r'\b(to_unsigned|to_signed|to_integer|std_logic_vector)\s*\(', RE_I)]):
        return 'Computation Block', 'Type Casting and Conversion', 0.75, 'Type conversion function'

    if has(gt, [_c(r'\b(sll|srl|sla|sra|rol|ror)\b', RE_I)]):
        return 'Computation Block', 'Bit-level Manipulation', 0.75, 'Shift/rotate operation'

    if has(gt, [_c(r'\(\d+\s+(downto|to)\s+\d+\)', RE_I)]) and has(gt, [_c(r'<=')]):
        return 'Computation Block', 'Bit-level Manipulation', 0.70, 'Bit range selection assignment'

    # 7. Declaration
    if has(gt, [_c(r'\bsignal\s+\w+', RE_I)]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.85, 'Signal declaration'
    if has(gt, [_c(r'\bvariable\s+\w+', RE_I)]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.80, 'Variable declaration'
    if has(gt, [_c(r'\bconstant\s+\w+', RE_I)]):
        return 'Declaration and Definition', 'Parameter and Generic Definition', 0.80, 'Constant declaration'
    if has(gt, [_c(r'\btype\s+\w+\s+is\b', RE_I)]):
        return 'Declaration and Definition', 'Type Definition', 0.85, 'Type definition'
    if has(gt, [_c(r'\bsubtype\s+\w+', RE_I)]):
        return 'Declaration and Definition', 'Type Definition', 0.80, 'Subtype definition'

    # 8. Concurrent signal assignment (outside process)
    if has(gt, [_c(r'<=')]) and not has(gt, [_c(r'\bprocess\b', RE_I)]):
        return 'Computation Block', 'Mux and Selection Logic', 0.65, \
               'Concurrent signal assignment'

    # 9. Additional patterns to reduce fallback
    # => association (generic map / port map context)
    if has(gt, [_c(r'=>')]) and has(near, [_c(r'\bgeneric\s+map\b|\bport\s+map\b', RE_I)]):
        return 'Interface', 'Component and Module Connection', 0.65, \
               'Map association (=> in port/generic map)'

    # elsif/else → Control Flow
    if has(gt, [_c(r'\belsif\b|\belse\b', RE_I)]):
        if has(near, [_c(r'\bprocess\b', RE_I)]):
            return 'Control Flow Block', 'Conditional Control', 0.65, \
                   'Elsif/else in process'

    # end if / end process → Control Flow
    if has(gt, [_c(r'\bend\s+if\b|\bend\s+process\b|\bend\s+case\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.60, \
               'End if/process/case'

    # when => (case alternative in process) → Control Flow
    if has(gt, [_c(r"\bwhen\b.*=>", RE_I)]) and has(near, [_c(r'\bcase\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.65, \
               'Case when alternative'

    # := variable assignment in process → Control Flow
    if has(gt, [_c(r':=')]) and has(near, [_c(r'\bprocess\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.60, \
               'Variable assignment in process'

    # generic parameter declaration (: positive/natural/integer)
    if has(gt, [_c(r':\s*(positive|natural|integer|boolean|string|real)\b', RE_I)]):
        if has(near, [_c(r'\bgeneric\b', RE_I)]):
            return 'Design Structure', 'Parameterization and Configuration', 0.65, \
                   'Generic parameter'
        return 'Declaration and Definition', 'Parameter and Generic Definition', 0.60, \
               'Typed parameter declaration'

    # <= in process context → Storage or Control Flow
    if has(gt, [_c(r'<=')]) and has(near, [_c(r'\bprocess\b', RE_I)]):
        if has(near, [_c(r"rising_edge|falling_edge|'event", RE_I)]):
            return 'Storage Block', 'Register-based Storage', 0.60, \
                   'Signal assignment in clocked process'
        return 'Control Flow Block', 'Conditional Control', 0.60, \
               'Signal assignment in combinational process'

    # 10. Design Issues
    if has(gt, [_c(r'--\s*(todo|fixme|hack|bug|note)\b', RE_I)]):
        return 'Design Issues', 'Clarification', 0.60, 'TODO/FIXME comment'

    # Fallback with better confidence
    if has(near, [_c(r'\bprocess\b', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.55, 'Code in process context'
    if has(gt, [_c(r':\s*(in|out|inout|buffer)\s+', RE_I)]):
        return 'Interface', 'Port Definition', 0.55, 'Port direction keyword'
    if has(gt, [_c(r'=>')]):
        return 'Interface', 'Component and Module Connection', 0.55, 'Association operator'
    return 'Computation Block', 'Mux and Selection Logic', 0.50, 'General computation'


# ============================================================
# Chisel snippet-level classifier
# ============================================================
def classify_chisel(entry) -> Tuple[str, str, float, str]:
    gt, near, full = _get_texts(entry)

    # 0. Monitoring — expect (golden check)
    if has(gt, [_c(r'\bexpect\s*\(')]):
        return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.85, \
               'Chisel expect (golden check)'

    # 0b. Testbench (poke/peek/step)
    if has(gt, [_c(r'\bpoke\s*\('), _c(r'\bpeek\s*\('), _c(r'\bstep\s*\(')]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.85, \
               'Chisel test harness (poke/peek/step)'

    # 1. Design Structure
    if has(gt, [_c(r'\bpackage\s+\w+')]):
        return 'Design Structure', 'Package and Namespace Definition', 0.85, 'Package declaration'
    if has(gt, [_c(r'\bimport\s+\w+\.')]):
        if not has(gt, [_c(r'\bval\b'), _c(r'\bdef\b'), _c(r':=')]):
            return 'Design Structure', 'Package and Namespace Definition', 0.75, 'Import statement'
    if has(gt, [_c(r'\bclass\s+\w+.*extends\s+\w*Module\b')]):
        return 'Design Structure', 'Top-level Structure', 0.85, 'Module class definition'
    if has(gt, [_c(r'\bobject\s+\w+.*extends\s+App\b')]):
        return 'Design Structure', 'Top-level Structure', 0.80, 'App object definition'
    if has(gt, [_c(r'case\s+class\b.*(?:Params|Config)', RE_I)]):
        return 'Design Structure', 'Parameterization and Configuration', 0.85, 'Params/Config case class'
    if has(gt, [_c(r'\bp\s*\(\s*\w+\)')]) and has(gt, [_c(r'\bParameters\b')]):
        return 'Design Structure', 'Parameterization and Configuration', 0.75, 'Parameters access'

    # 2. Interface
    if has(gt, [_c(r'\bval\s+io\s*=\s*IO\b')]):
        return 'Interface', 'Port Definition', 0.90, 'IO bundle definition'
    if has(gt, [_c(r'\bclass\s+\w+.*extends\s+Bundle\b')]):
        return 'Interface', 'Port Definition', 0.90, 'Bundle class definition'
    if has(gt, [_c(r'\bInput\s*\(')]) and has(gt, [_c(r'\bOutput\s*\(')]):
        return 'Interface', 'Port Definition', 0.85, 'Input/Output port declarations'
    if has(gt, [_c(r'\bInput\s*\(')]) or has(gt, [_c(r'\bOutput\s*\(')]):
        if has(near, [_c(r'\bBundle\b'), _c(r'\bIO\s*\(')]):
            return 'Interface', 'Port Definition', 0.80, 'Input or Output in Bundle/IO context'

    if has(gt, [_c(r'\bDecoupled\s*\(')]):
        return 'Interface', 'Handshake and Flow Control', 0.85, 'Decoupled interface'
    if has(gt, [_c(r'\bIrrevocable\b')]):
        return 'Interface', 'Handshake and Flow Control', 0.80, 'Irrevocable interface'
    if has(gt, [_c(r'\.ready\s*:=')]) or has(gt, [_c(r'\.valid\s*:=')]):
        return 'Interface', 'Handshake and Flow Control', 0.80, 'Ready/valid handshake assignment'
    if has(gt, [_c(r'\bFlipped\s*\(')]):
        return 'Interface', 'Port Definition', 0.75, 'Flipped port'

    # 3. Storage
    if has(gt, [_c(r'\bRegInit\b')]):
        return 'Storage Block', 'Register-based Storage', 0.85, 'RegInit register'
    if has(gt, [_c(r'\bRegNext\b')]):
        return 'Storage Block', 'Register-based Storage', 0.85, 'RegNext register'
    if has(gt, [_c(r'\bRegEnable\b')]):
        return 'Storage Block', 'Register-based Storage', 0.85, 'RegEnable register'
    if has(gt, [_c(r'\bReg\s*\(')]):
        return 'Storage Block', 'Register-based Storage', 0.80, 'Reg declaration'
    if has(gt, [_c(r'\bShiftRegister\b')]):
        return 'Storage Block', 'Register-based Storage', 0.80, 'ShiftRegister'
    if has(gt, [_c(r'\bMem\s*\(|\bSyncReadMem\b')]):
        return 'Storage Block', 'Memory and Array Storage', 0.85, 'Memory declaration'

    # 4. Control Flow
    if has(gt, [_c(r'\bwhen\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.85, 'when conditional'
    if has(gt, [_c(r'\.elsewhen\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.85, '.elsewhen conditional'
    if has(gt, [_c(r'\.otherwise\b')]):
        return 'Control Flow Block', 'Conditional Control', 0.80, '.otherwise clause'
    if has(gt, [_c(r'\bswitch\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.85, 'switch statement'
    if has(gt, [_c(r'\bis\s*\(')]) and has(near, [_c(r'\bswitch\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.75, 'is() in switch context'
    if has(gt, [_c(r'\bfor\s*\(')]):
        return 'Control Flow Block', 'Loop-based Control', 0.80, 'for loop'
    if has(gt, [_c(r'\.foreach\b|\.map\s*[\({]|\.foldLeft\b|\.reduce\b')]):
        return 'Control Flow Block', 'Loop-based Control', 0.75, 'Functional iteration'

    # 5. Computation
    if has(gt, [_c(r'\bMux\s*\('), _c(r'\bMux1H\b'), _c(r'\bMuxLookup\b'),
                _c(r'\bMuxCase\b'), _c(r'\bPriorityMux\b')]):
        return 'Computation Block', 'Mux and Selection Logic', 0.85, 'Mux selection'
    if has(gt, [_c(r'\.asUInt\b'), _c(r'\.asSInt\b'), _c(r'\.asBool\b'), _c(r'\.asTypeOf\b')]):
        return 'Computation Block', 'Type Casting and Conversion', 0.80, 'Type casting'
    if has(gt, [_c(r'\bCat\s*\('), _c(r'\bFill\s*\(')]):
        return 'Computation Block', 'Type Casting and Conversion', 0.75, 'Cat/Fill operation'

    # 6. Declaration
    if has(gt, [_c(r'\bWire\s*\('), _c(r'\bWireInit\b'), _c(r'\bWireDefault\b')]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.85, 'Wire declaration'
    if has(gt, [_c(r'\bdef\s+\w+\s*[\[(:=]')]):
        return 'Declaration and Definition', 'Function and Procedure Signature', 0.80, 'Method definition'
    if has(gt, [_c(r'\bChiselEnum\b')]):
        return 'Declaration and Definition', 'Type Definition', 0.80, 'ChiselEnum'
    if has(gt, [_c(r'\bval\s+\w+\s*=\s*\d+\.[USW]\b')]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.70, 'Literal value binding'

    # 7. Connection operator → check context
    if has(gt, [_c(r':=')]):
        if has(near, [_c(r'\bwhen\s*\('), _c(r'\.otherwise\b'), _c(r'\bswitch\s*\(')]):
            return 'Control Flow Block', 'Conditional Control', 0.60, ':= in when/switch context'
        if has(near, [_c(r'\.valid\b|\.ready\b|Decoupled|Valid')]):
            return 'Interface', 'Handshake and Flow Control', 0.55, ':= in handshake context'
        if has(near, [_c(r'\bio\.\w+')]):
            return 'Interface', 'Port Definition', 0.50, ':= to io port'

    # 8. Scala case/match → Control Flow
    if has(gt, [_c(r'\bcase\s+\w+\s*=>')]):
        return 'Control Flow Block', 'Conditional Control', 0.70, 'Scala case/match expression'

    # 9. case object/class extending Field → Design Structure
    if has(gt, [_c(r'\bcase\s+object\b.*extends\s+Field\b')]):
        return 'Design Structure', 'Parameterization and Configuration', 0.70, 'Config Field definition'
    if has(gt, [_c(r'\bcase\s+class\b')]):
        return 'Declaration and Definition', 'Type Definition', 0.70, 'Case class definition'

    # 10. Module(new ...) → Design Structure
    if has(gt, [_c(r'\bModule\s*\(\s*new\b')]):
        return 'Design Structure', 'Hierarchical Composition', 0.70, 'Module instantiation'

    # 11. require/assert → Property
    if has(gt, [_c(r'\brequire\s*\('), _c(r'\bassert\s*\(')]):
        return 'Property and Assertion Specification', 'Assertion Definition', 0.65, \
               'Require/assert check'

    # 12. val binding
    if has(gt, [_c(r'\bval\s+\w+\s*=')]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.60, 'val binding'

    # 13. := connection → check context
    if has(gt, [_c(r':=')]):
        return 'Control Flow Block', 'Conditional Control', 0.55, ':= connection'

    # Fallback
    if has(near, [_c(r'\bwhen\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.55, 'Code near when block'
    if has(near, [_c(r'\bBundle\b|\bIO\s*\(')]):
        return 'Interface', 'Port Definition', 0.55, 'Code near IO/Bundle'
    return 'Declaration and Definition', 'Signal and Wire Declaration', 0.50, \
           'General declaration'


# ============================================================
# HLS C/C++ snippet-level classifier
# ============================================================
def classify_hls(entry) -> Tuple[str, str, float, str]:
    gt, near, full = _get_texts(entry)

    # 0. Testbench
    if has(gt, [_c(r'\btestbench\b', RE_I)]) or \
       (has(gt, [_c(r'\bwhile\s*\(')]) and has(gt, [_c(r'\bgolden\b|\breference\b|\bexpected\b', RE_I)])):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.75, \
               'Testbench loop or golden comparison'
    if has(gt, [_c(r'\bsc_main\b'), _c(r'\bsc_start\b'), _c(r'\bsc_trace\b')]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.80, \
               'SystemC testbench'
    if has(gt, [_c(r'\bint\s+main\s*\(')]) and has(near, [_c(r'\bgolden\b|\breference\b|\btest\b', RE_I)]):
        return 'Testbench Stimulus and Environment', 'Stimulus Generation', 0.70, \
               'main() testbench function'

    # 0b. Monitoring / golden check
    if has(gt, [_c(r'\bgolden\b|\breference\b|\bexpected\b', RE_I)]) and has(gt, [_c(r'!=|==')]):
        return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.75, \
               'Golden/reference comparison check'
    if has(gt, [_c(r'\bprintf\s*\('), _c(r'\bfprintf\s*\('), _c(r'\bcout\s*<<')]):
        if has(gt, [_c(r'\berror\b|\bfail\b|\bmismatch\b', RE_I)]):
            return 'Monitoring and Checking Logic', 'Error Reporting and Logging', 0.75, \
                   'Error/fail print statement'

    # 0c. Interface — AXI / Stream
    if has(gt, [_c(r'#pragma\s+HLS\s+INTERFACE', RE_I)]):
        if has(gt, [_c(r'\baxi\b|\baxis\b|\bap_ctrl\b|\bs_axilite\b|\bm_axi\b', RE_I)]):
            return 'Interface', 'Protocol-based Interface', 0.85, \
                   'HLS interface pragma (AXI)'
        return 'Interface', 'Port Definition', 0.80, 'HLS interface pragma'
    if has(gt, [_c(r'\bhls::stream\b')]) and has(gt, [_c(r'\bread\s*\(|\bwrite\s*\(')]):
        return 'Interface', 'Protocol-based Interface', 0.75, \
               'HLS stream read/write (stream interface)'

    # 1. Assertion
    if has(gt, [_c(r'\bassert\s*\('), _c(r'\bstatic_assert\b')]):
        return 'Property and Assertion Specification', 'Assertion Definition', 0.85, \
               'Assert statement'

    # 2. Design Structure
    if has(gt, [_c(r'#pragma\s+HLS\s+(top|interface)', RE_I),
                _c(r'#pragma\s+hls_design\b', RE_I)]):
        return 'Design Structure', 'Top-level Structure', 0.85, 'HLS pragma top/interface'
    if has(gt, [_c(r'#include\b')]):
        if not has(gt, [_c(r'\bfor\b'), _c(r'\bif\b'), _c(r'=')]):
            return 'Design Structure', 'Package and Namespace Definition', 0.80, '#include directive'
    if has(gt, [_c(r'#ifndef\b'), _c(r'#endif\b'), _c(r'#pragma\s+once\b')]):
        return 'Design Structure', 'Package and Namespace Definition', 0.75, 'Include guard'
    if has(gt, [_c(r'\bnamespace\b'), _c(r'\busing\s+namespace\b')]):
        return 'Design Structure', 'Package and Namespace Definition', 0.75, 'Namespace'

    # 3. Storage — stream/channel
    if has(gt, [_c(r'\bhls::stream\b'), _c(r'\bac_channel\b')]):
        return 'Storage Block', 'Memory and Array Storage', 0.85, 'HLS stream/channel'
    if has(gt, [_c(r'#pragma\s+HLS\s+(array_partition|array_reshape|stream|bind_storage)', RE_I)]):
        return 'Storage Block', 'Memory and Array Storage', 0.85, 'HLS array pragma'

    # 4. Storage — array declaration
    if has(gt, [_c(r'\b(int|float|double|char|short|long|unsigned|bool|ap_uint|ap_int|ac_int|ac_fixed)\s+\w+\s*\[', RE_I)]):
        return 'Storage Block', 'Memory and Array Storage', 0.80, 'Array declaration'

    # 5. Control Flow — loops
    if has(gt, [_c(r'\bfor\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.80, 'For loop'
    if has(gt, [_c(r'\bwhile\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.80, 'While loop'
    if has(gt, [_c(r'#pragma\s+HLS\s+(unroll|pipeline|loop)', RE_I)]):
        return 'Control Flow Block', 'Conditional Control', 0.80, 'HLS loop pragma'

    # 6. Control Flow — if/switch
    if has(gt, [_c(r'\bif\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.75, 'If statement'
    if has(gt, [_c(r'\bswitch\s*\(')]):
        return 'Control Flow Block', 'Conditional Control', 0.75, 'Switch statement'

    # 7. Declaration — function/class/struct
    if has(gt, [_c(r'\b(void|int|float|double|bool|auto)\s+\w+\s*\(')]):
        return 'Declaration and Definition', 'Function and Procedure Signature', 0.80, \
               'Function signature'
    if has(gt, [_c(r'\btemplate\s*<')]):
        return 'Declaration and Definition', 'Function and Procedure Signature', 0.75, \
               'Template declaration'
    if has(gt, [_c(r'\bclass\s+\w+'), _c(r'\bstruct\s+\w+')]):
        return 'Declaration and Definition', 'Function and Procedure Signature', 0.75, \
               'Class/struct definition'

    # 8. Declaration — constants/defines
    if has(gt, [_c(r'#define\s+\w+\s+')]):
        return 'Declaration and Definition', 'Parameter and Generic Definition', 0.80, '#define'
    if has(gt, [_c(r'\bstatic\s+const\b'), _c(r'\bconstexpr\b')]):
        return 'Declaration and Definition', 'Parameter and Generic Definition', 0.80, \
               'Static const/constexpr'
    if has(gt, [_c(r'\btypedef\b'), _c(r'\benum\b')]):
        return 'Declaration and Definition', 'Parameter and Generic Definition', 0.75, \
               'Typedef/enum'

    # 9. Declaration — variable
    if has(gt, [_c(r'\b(int|float|double|char|short|long|unsigned|bool|auto|ap_uint|ap_int|ac_int|ac_fixed)\s+\w+\s*[;=]', RE_I)]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.70, 'Variable declaration'

    # 10. Computation
    if has(gt, [_c(r'[\+\-\*/%]=')]):
        return 'Computation Block', 'Arithmetic Computation', 0.75, 'Compound arithmetic assignment'
    if has(gt, [_c(r'=\s*\w+\s*[\+\-\*/]\s*\w+')]):
        return 'Computation Block', 'Arithmetic Computation', 0.70, 'Arithmetic expression'
    if has(gt, [_c(r'\?\s*\S+\s*:')]):
        return 'Computation Block', 'Mux and Selection Logic', 0.70, 'Ternary operator'

    # 11. Array access
    if has(gt, [_c(r'\w+\s*\[\s*\w+\s*\]')]):
        return 'Storage Block', 'Memory and Array Storage', 0.65, 'Array access'

    # 12. Additional patterns
    # Stream parameter declaration
    if has(gt, [_c(r'\bstream\s*<', RE_I)]):
        return 'Interface', 'Protocol-based Interface', 0.65, 'Stream type parameter'

    # Pointer/new/malloc → Storage
    if has(gt, [_c(r'\bnew\s+\w+\s*\['), _c(r'\bmalloc\b'), _c(r'\bcalloc\b')]):
        return 'Storage Block', 'Memory and Array Storage', 0.65, 'Dynamic memory allocation'

    # Pointer declaration
    if has(gt, [_c(r'\b\w+\s*\*\s*\w+')]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.60, 'Pointer declaration'

    # Return statement
    if has(gt, [_c(r'\breturn\b')]):
        return 'Control Flow Block', 'Conditional Control', 0.60, 'Return statement'

    # General assignment with =
    if has(gt, [_c(r'\w+\s*=\s*\w+')]):
        return 'Computation Block', 'Arithmetic Computation', 0.55, 'Assignment expression'

    # Closing braces / function end
    if has(gt, [_c(r'^\s*\}\s*$', re.MULTILINE)]):
        return 'Design Structure', 'Top-level Structure', 0.55, 'Block closing brace'

    # Fallback
    if has(gt, [_c(r'=')]):
        return 'Declaration and Definition', 'Signal and Wire Declaration', 0.55, 'General assignment'
    return 'Declaration and Definition', 'Signal and Wire Declaration', 0.50, 'General declaration'


# ============================================================
# Dispatcher
# ============================================================
def detect_language(filepath: str) -> str:
    fp = filepath.lower()
    if 'systemverilog' in fp: return 'systemverilog'
    elif 'vhdl' in fp: return 'vhdl'
    elif 'chisel' in fp: return 'chisel'
    elif 'hls' in fp: return 'hls'
    return 'unknown'

CLASSIFIERS = {
    'systemverilog': classify_sv,
    'vhdl': classify_vhdl,
    'chisel': classify_chisel,
    'hls': classify_hls,
}

def classify_entry(entry, language):
    fn = CLASSIFIERS.get(language)
    if not fn:
        return entry
    cat, sub, conf, reason = fn(entry)
    entry['category'] = cat
    entry['subcategory'] = sub
    entry['confidence'] = conf
    entry['category_reason'] = reason
    return entry


def process_file(input_path, output_path, language=None):
    if language is None:
        language = detect_language(input_path)

    entries = []
    with open(input_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                entries.append(json.loads(line))

    for e in entries:
        classify_entry(e, language)

    with open(output_path, 'w', encoding='utf-8') as f:
        for e in entries:
            f.write(json.dumps(e, ensure_ascii=False) + '\n')

    print(f"Processed {len(entries)} entries: {input_path} -> {output_path}")


def evaluate(pred_path, gold_path):
    preds = [json.loads(l) for l in open(pred_path) if l.strip()]
    golds = [json.loads(l) for l in open(gold_path) if l.strip()]
    assert len(preds) == len(golds)

    cat_correct = subcat_correct = 0
    total = len(preds)
    cat_confusion = {}
    cat_total = defaultdict(int)
    cat_hit = defaultdict(int)

    for p, g in zip(preds, golds):
        gc, pc = g.get('category',''), p.get('category','')
        gs, ps = g.get('subcategory',''), p.get('subcategory','')
        cat_total[gc] += 1
        if gc == pc:
            cat_correct += 1
            cat_hit[gc] += 1
        else:
            k = (gc, pc)
            cat_confusion[k] = cat_confusion.get(k, 0) + 1
        if gc == pc and gs == ps:
            subcat_correct += 1

    print(f"\n{'='*60}")
    print(f"Evaluation: {os.path.basename(os.path.dirname(pred_path))}")
    print(f"{'='*60}")
    print(f"Total:     {total}")
    print(f"Category:  {cat_correct}/{total} = {cat_correct/total*100:.1f}%")
    print(f"Subcat:    {subcat_correct}/{total} = {subcat_correct/total*100:.1f}%")

    # Distribution comparison
    pred_cats = defaultdict(int)
    for p in preds:
        pred_cats[p.get('category','')] += 1
    all_cats = sorted(set(cat_total) | set(pred_cats))
    print(f"\n  {'Category':<45s} {'Gold':>5s} {'Rule':>5s} {'Hit':>5s}")
    print(f"  {'-'*45} {'-'*5} {'-'*5} {'-'*5}")
    for cat in all_cats:
        g = cat_total.get(cat, 0)
        p = pred_cats.get(cat, 0)
        h = cat_hit.get(cat, 0)
        print(f"  {cat:<45s} {g:>5d} {p:>5d} {h:>5d}")

    if cat_confusion:
        print(f"\nTop confusions:")
        for (g, p), c in sorted(cat_confusion.items(), key=lambda x: -x[1])[:10]:
            print(f"  {g} -> {p} : {c}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', '-i', type=str)
    parser.add_argument('--output', '-o', type=str)
    parser.add_argument('--language', '-l', type=str, choices=['systemverilog','vhdl','chisel','hls'])
    parser.add_argument('--evaluate', '-e', type=str)
    parser.add_argument('--run-all', action='store_true')
    args = parser.parse_args()

    if args.run_all:
        datasets = [
            ('systemverilog', '/ssd1/zqy/Multi-hdl-language-repo/systemverilog_dataset'),
            ('hls', '/ssd1/zqy/Multi-hdl-language-repo/hls_dataset'),
            ('vhdl', '/ssd1/zqy/Multi-hdl-language-repo/vhdl_dataset'),
            ('chisel', '/ssd1/zqy/Multi-hdl-language-repo/chisel_dataset'),
        ]
        for lang, base_dir in datasets:
            inp = os.path.join(base_dir, 'test_content.jsonl')
            gold = os.path.join(base_dir, 'test_content_classfied.jsonl')
            out = os.path.join(base_dir, 'test_content_classfied_rulebased.jsonl')
            if not os.path.exists(inp): inp = gold
            if os.path.exists(inp):
                process_file(inp, out, lang)
                if os.path.exists(gold):
                    evaluate(out, gold)
    else:
        if not args.input:
            parser.error("--input required (or --run-all)")
        out = args.output or args.input.replace('.jsonl', '_rulebased.jsonl')
        process_file(args.input, out, args.language)
        if args.evaluate:
            evaluate(out, args.evaluate)

if __name__ == '__main__':
    main()
