`ifndef LOGIC_DRC_SVH
`define LOGIC_DRC_SVH

`define LOGIC_DRC_STRINGIFY(x) `"x`"

`define LOGIC_DRC_TRUE_FALSE(value) \
    if (!((0 == value) || (1 == value))) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(value), value, \
            "must be 0 (false) or 1 (true)" \
        ); \
        $finish; \
    end

`define LOGIC_DRC_RANGE(value, value_min, value_max) \
    if (!((value >= value_min) && (value <= value_max))) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s %s (%0d) %s %s (%0d)", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(value), value, \
            "must be equal or greater than", \
            `LOGIC_DRC_STRINGIFY(value_min), value_min, \
            "and equal or less than", \
            `LOGIC_DRC_STRINGIFY(value_max), value_max \
        ); \
        $finish; \
    end

`define LOGIC_DRC_POWER_OF_2(value) \
    if (!((0 != value) && (0 == (value & (value - 1))))) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(value), value, \
            "must be power of 2" \
        ); \
        $finish; \
    end

`define LOGIC_DRC_NOT_SUPPORTED(value) \
    $display("DRC:%m:%s:%0d: %s (%0d) %s", \
        `__FILE__, `__LINE__, \
        `LOGIC_DRC_STRINGIFY(value), value, \
        "not supported" \
    ); \
    $finish;

`define LOGIC_DRC_EQUAL(lhs, rhs) \
    if (!(lhs == rhs)) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s %s (%0d)", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(lhs), lhs, \
            "must be equal to", \
            `LOGIC_DRC_STRINGIFY(rhs), rhs \
        ); \
        $finish; \
    end

`define LOGIC_DRC_NOT_EQUAL(lhs, rhs) \
    if (!(lhs != rhs)) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s %s (%0d)", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(lhs), lhs, \
            "must be not equal to", \
            `LOGIC_DRC_STRINGIFY(rhs), rhs \
        ); \
        $finish; \
    end

`define LOGIC_DRC_EQUAL_OR_GREATER_THAN(lhs, rhs) \
    if (!(lhs >= rhs)) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s %s (%0d)", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(lhs), lhs, \
            "must be equal or greater than", \
            `LOGIC_DRC_STRINGIFY(rhs), rhs \
        ); \
        $finish; \
    end

`define LOGIC_DRC_EQUAL_OR_LESS_THAN(lhs, rhs) \
    if (!(lhs <= rhs)) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s %s (%0d)", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(lhs), lhs, \
            "must be equal or less than", \
            `LOGIC_DRC_STRINGIFY(rhs), rhs \
        ); \
        $finish; \
    end

`define LOGIC_DRC_GREATER_THAN(lhs, rhs) \
    if (!(lhs > rhs)) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s %s (%0d)", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(lhs), lhs, \
            "must be greater than", \
            `LOGIC_DRC_STRINGIFY(rhs), rhs \
        ); \
        $finish; \
    end

`define LOGIC_DRC_LESS_THAN(lhs, rhs) \
    if (!(lhs < rhs)) begin \
        $display("DRC:%m:%s:%0d: %s (%0d) %s %s (%0d)", \
            `__FILE__, `__LINE__, \
            `LOGIC_DRC_STRINGIFY(lhs), lhs, \
            "must be less than", \
            `LOGIC_DRC_STRINGIFY(rhs), rhs \
        ); \
        $finish; \
    end

`endif /* LOGIC_DRC_SVH */
