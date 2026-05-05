package cf_math_pkg;

    function automatic integer ceil_div (input longint dividend, input longint divisor);
        automatic longint remainder;
        remainder = dividend;
        for (ceil_div = 0; remainder > 0; ceil_div++) begin
            remainder = remainder - divisor;
        end
    endfunction

    function automatic integer unsigned idx_width (input integer unsigned num_idx);
        return (num_idx > 32'd1) ? unsigned'($clog2(num_idx)) : 32'd1;
    endfunction

    function automatic bit is_power_of_2 (input integer unsigned value);
        return (value != 0) && ((value & (value - 1)) == 0);
    endfunction

endpackage
