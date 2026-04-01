FIRRTL version 1.2.0
circuit RotationalPrioritySelector :
  module Terminal : @[src/main/scala/RotationalPrioritySelector.scala 136:21]
    input clock : Clock @[src/main/scala/RotationalPrioritySelector.scala 136:21]
    input reset : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 136:21]
    input io_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 139:20]
    output io_upper_out_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 139:20]

    io_upper_out_valid <= io_valid @[src/main/scala/RotationalPrioritySelector.scala 148:29]

  module NodeFirstLayer : @[src/main/scala/RotationalPrioritySelector.scala 108:21]
    input clock : Clock @[src/main/scala/RotationalPrioritySelector.scala 108:21]
    input reset : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 108:21]
    input io_ll_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 111:20]
    input io_lr_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 111:20]
    output io_up_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 111:20]
    output io_up_index : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 111:20]
    input io_up_select : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 111:20]

    node _select_T = bits(io_up_select, 0, 0) @[src/main/scala/RotationalPrioritySelector.scala 123:34]
    node _select_T_1 = and(_select_T, io_ll_valid) @[src/main/scala/RotationalPrioritySelector.scala 123:41]
    node _select_T_2 = eq(io_lr_valid, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 123:60]
    node _select_T_3 = or(_select_T_1, _select_T_2) @[src/main/scala/RotationalPrioritySelector.scala 123:57]
    node _io_up_valid_T = or(io_ll_valid, io_lr_valid) @[src/main/scala/RotationalPrioritySelector.scala 126:36]
    node select = _select_T_3 @[src/main/scala/RotationalPrioritySelector.scala 122:36 123:17]
    node _io_up_index_T = mux(select, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 127:27]
    io_up_valid <= _io_up_valid_T @[src/main/scala/RotationalPrioritySelector.scala 126:21]
    io_up_index <= _io_up_index_T @[src/main/scala/RotationalPrioritySelector.scala 127:21]

  module NodeUpperLayer : @[src/main/scala/RotationalPrioritySelector.scala 68:21]
    input clock : Clock @[src/main/scala/RotationalPrioritySelector.scala 68:21]
    input reset : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 68:21]
    input io_ll_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_ll_index : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_ll_select : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_lr_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_lr_index : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_lr_select : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_up_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_up_index : UInt<2> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_up_select : UInt<2> @[src/main/scala/RotationalPrioritySelector.scala 71:20]

    node select_down = bits(io_up_select, 0, 0) @[src/main/scala/RotationalPrioritySelector.scala 81:51]
    node select_flat = bits(io_up_select, 1, 1) @[src/main/scala/RotationalPrioritySelector.scala 82:51]
    node _select_l_reverse_T = eq(io_ll_valid, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 85:43]
    node _select_l_reverse_T_1 = gt(select_down, io_ll_index) @[src/main/scala/RotationalPrioritySelector.scala 85:88]
    node _select_l_reverse_T_2 = and(io_lr_valid, _select_l_reverse_T_1) @[src/main/scala/RotationalPrioritySelector.scala 85:72]
    node select_l_reverse = or(_select_l_reverse_T, _select_l_reverse_T_2) @[src/main/scala/RotationalPrioritySelector.scala 85:56]
    node _select_r_reverse_T = eq(io_lr_valid, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 86:43]
    node _select_r_reverse_T_1 = gt(select_down, io_lr_index) @[src/main/scala/RotationalPrioritySelector.scala 86:88]
    node _select_r_reverse_T_2 = and(io_ll_valid, _select_r_reverse_T_1) @[src/main/scala/RotationalPrioritySelector.scala 86:72]
    node select_r_reverse = or(_select_r_reverse_T, _select_r_reverse_T_2) @[src/main/scala/RotationalPrioritySelector.scala 86:56]
    node selected_l_index = cat(UInt<1>("h1"), io_ll_index) @[src/main/scala/RotationalPrioritySelector.scala 89:46]
    node selected_r_index = cat(UInt<1>("h0"), io_lr_index) @[src/main/scala/RotationalPrioritySelector.scala 90:46]
    node _io_ll_select_T = mux(select_flat, select_down, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 93:31]
    node _io_lr_select_T = eq(select_flat, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 94:32]
    node _io_lr_select_T_1 = mux(_io_lr_select_T, select_down, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 94:31]
    node _io_up_valid_T = or(io_ll_valid, io_lr_valid) @[src/main/scala/RotationalPrioritySelector.scala 97:40]
    node _io_up_index_T = mux(select_l_reverse, selected_r_index, selected_l_index) @[src/main/scala/RotationalPrioritySelector.scala 99:16]
    node _io_up_index_T_1 = mux(select_r_reverse, selected_l_index, selected_r_index) @[src/main/scala/RotationalPrioritySelector.scala 100:16]
    node _io_up_index_T_2 = mux(select_flat, _io_up_index_T, _io_up_index_T_1) @[src/main/scala/RotationalPrioritySelector.scala 98:31]
    io_ll_select <= _io_ll_select_T @[src/main/scala/RotationalPrioritySelector.scala 93:25]
    io_lr_select <= _io_lr_select_T_1 @[src/main/scala/RotationalPrioritySelector.scala 94:25]
    io_up_valid <= _io_up_valid_T @[src/main/scala/RotationalPrioritySelector.scala 97:25]
    io_up_index <= _io_up_index_T_2 @[src/main/scala/RotationalPrioritySelector.scala 98:25]

  module NodeUpperLayer_2 : @[src/main/scala/RotationalPrioritySelector.scala 68:21]
    input clock : Clock @[src/main/scala/RotationalPrioritySelector.scala 68:21]
    input reset : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 68:21]
    input io_ll_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_ll_index : UInt<2> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_ll_select : UInt<2> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_lr_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_lr_index : UInt<2> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_lr_select : UInt<2> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_up_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    output io_up_index : UInt<3> @[src/main/scala/RotationalPrioritySelector.scala 71:20]
    input io_up_select : UInt<3> @[src/main/scala/RotationalPrioritySelector.scala 71:20]

    node select_down = bits(io_up_select, 1, 0) @[src/main/scala/RotationalPrioritySelector.scala 81:51]
    node select_flat = bits(io_up_select, 2, 2) @[src/main/scala/RotationalPrioritySelector.scala 82:51]
    node _select_l_reverse_T = eq(io_ll_valid, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 85:43]
    node _select_l_reverse_T_1 = gt(select_down, io_ll_index) @[src/main/scala/RotationalPrioritySelector.scala 85:88]
    node _select_l_reverse_T_2 = and(io_lr_valid, _select_l_reverse_T_1) @[src/main/scala/RotationalPrioritySelector.scala 85:72]
    node select_l_reverse = or(_select_l_reverse_T, _select_l_reverse_T_2) @[src/main/scala/RotationalPrioritySelector.scala 85:56]
    node _select_r_reverse_T = eq(io_lr_valid, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 86:43]
    node _select_r_reverse_T_1 = gt(select_down, io_lr_index) @[src/main/scala/RotationalPrioritySelector.scala 86:88]
    node _select_r_reverse_T_2 = and(io_ll_valid, _select_r_reverse_T_1) @[src/main/scala/RotationalPrioritySelector.scala 86:72]
    node select_r_reverse = or(_select_r_reverse_T, _select_r_reverse_T_2) @[src/main/scala/RotationalPrioritySelector.scala 86:56]
    node selected_l_index = cat(UInt<1>("h1"), io_ll_index) @[src/main/scala/RotationalPrioritySelector.scala 89:46]
    node selected_r_index = cat(UInt<1>("h0"), io_lr_index) @[src/main/scala/RotationalPrioritySelector.scala 90:46]
    node _io_ll_select_T = mux(select_flat, select_down, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 93:31]
    node _io_lr_select_T = eq(select_flat, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 94:32]
    node _io_lr_select_T_1 = mux(_io_lr_select_T, select_down, UInt<1>("h0")) @[src/main/scala/RotationalPrioritySelector.scala 94:31]
    node _io_up_valid_T = or(io_ll_valid, io_lr_valid) @[src/main/scala/RotationalPrioritySelector.scala 97:40]
    node _io_up_index_T = mux(select_l_reverse, selected_r_index, selected_l_index) @[src/main/scala/RotationalPrioritySelector.scala 99:16]
    node _io_up_index_T_1 = mux(select_r_reverse, selected_l_index, selected_r_index) @[src/main/scala/RotationalPrioritySelector.scala 100:16]
    node _io_up_index_T_2 = mux(select_flat, _io_up_index_T, _io_up_index_T_1) @[src/main/scala/RotationalPrioritySelector.scala 98:31]
    io_ll_select <= _io_ll_select_T @[src/main/scala/RotationalPrioritySelector.scala 93:25]
    io_lr_select <= _io_lr_select_T_1 @[src/main/scala/RotationalPrioritySelector.scala 94:25]
    io_up_valid <= _io_up_valid_T @[src/main/scala/RotationalPrioritySelector.scala 97:25]
    io_up_index <= _io_up_index_T_2 @[src/main/scala/RotationalPrioritySelector.scala 98:25]

  module RotationalPrioritySelector : @[src/main/scala/RotationalPrioritySelector.scala 49:7]
    input clock : Clock @[src/main/scala/RotationalPrioritySelector.scala 49:7]
    input reset : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 49:7]
    input io_in_valid_0 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_valid_1 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_valid_2 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_valid_3 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_valid_4 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_valid_5 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_valid_6 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_valid_7 : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    input io_in_head : UInt<3> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    output io_out_valid : UInt<1> @[src/main/scala/RotationalPrioritySelector.scala 170:16]
    output io_out_index : UInt<3> @[src/main/scala/RotationalPrioritySelector.scala 170:16]

    inst Terminal of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst Terminal_1 of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst Terminal_2 of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst Terminal_3 of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst Terminal_4 of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst Terminal_5 of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst Terminal_6 of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst Terminal_7 of Terminal @[src/main/scala/RotationalPrioritySelector.scala 184:30]
    inst NodeFirstLayer of NodeFirstLayer @[src/main/scala/RotationalPrioritySelector.scala 197:36]
    inst NodeFirstLayer_1 of NodeFirstLayer @[src/main/scala/RotationalPrioritySelector.scala 197:36]
    inst NodeFirstLayer_2 of NodeFirstLayer @[src/main/scala/RotationalPrioritySelector.scala 197:36]
    inst NodeFirstLayer_3 of NodeFirstLayer @[src/main/scala/RotationalPrioritySelector.scala 197:36]
    inst node of NodeUpperLayer @[src/main/scala/RotationalPrioritySelector.scala 212:33]
    inst node_1 of NodeUpperLayer @[src/main/scala/RotationalPrioritySelector.scala 212:33]
    inst node_2 of NodeUpperLayer_2 @[src/main/scala/RotationalPrioritySelector.scala 229:41]
    io_out_valid <= node_2.io_up_valid @[src/main/scala/RotationalPrioritySelector.scala 243:25]
    io_out_index <= node_2.io_up_index @[src/main/scala/RotationalPrioritySelector.scala 244:25]
    Terminal.clock <= clock
    Terminal.reset <= reset
    Terminal.io_valid <= io_in_valid_0 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    Terminal_1.clock <= clock
    Terminal_1.reset <= reset
    Terminal_1.io_valid <= io_in_valid_1 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    Terminal_2.clock <= clock
    Terminal_2.reset <= reset
    Terminal_2.io_valid <= io_in_valid_2 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    Terminal_3.clock <= clock
    Terminal_3.reset <= reset
    Terminal_3.io_valid <= io_in_valid_3 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    Terminal_4.clock <= clock
    Terminal_4.reset <= reset
    Terminal_4.io_valid <= io_in_valid_4 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    Terminal_5.clock <= clock
    Terminal_5.reset <= reset
    Terminal_5.io_valid <= io_in_valid_5 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    Terminal_6.clock <= clock
    Terminal_6.reset <= reset
    Terminal_6.io_valid <= io_in_valid_6 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    Terminal_7.clock <= clock
    Terminal_7.reset <= reset
    Terminal_7.io_valid <= io_in_valid_7 @[src/main/scala/RotationalPrioritySelector.scala 188:31]
    NodeFirstLayer.clock <= clock
    NodeFirstLayer.reset <= reset
    NodeFirstLayer.io_ll_valid <= Terminal_1.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 201:26]
    NodeFirstLayer.io_lr_valid <= Terminal.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 200:26]
    NodeFirstLayer.io_up_select <= node.io_lr_select @[src/main/scala/RotationalPrioritySelector.scala 214:24]
    NodeFirstLayer_1.clock <= clock
    NodeFirstLayer_1.reset <= reset
    NodeFirstLayer_1.io_ll_valid <= Terminal_3.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 201:26]
    NodeFirstLayer_1.io_lr_valid <= Terminal_2.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 200:26]
    NodeFirstLayer_1.io_up_select <= node.io_ll_select @[src/main/scala/RotationalPrioritySelector.scala 215:24]
    NodeFirstLayer_2.clock <= clock
    NodeFirstLayer_2.reset <= reset
    NodeFirstLayer_2.io_ll_valid <= Terminal_5.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 201:26]
    NodeFirstLayer_2.io_lr_valid <= Terminal_4.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 200:26]
    NodeFirstLayer_2.io_up_select <= node_1.io_lr_select @[src/main/scala/RotationalPrioritySelector.scala 214:24]
    NodeFirstLayer_3.clock <= clock
    NodeFirstLayer_3.reset <= reset
    NodeFirstLayer_3.io_ll_valid <= Terminal_7.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 201:26]
    NodeFirstLayer_3.io_lr_valid <= Terminal_6.io_upper_out_valid @[src/main/scala/RotationalPrioritySelector.scala 200:26]
    NodeFirstLayer_3.io_up_select <= node_1.io_ll_select @[src/main/scala/RotationalPrioritySelector.scala 215:24]
    node.clock <= clock
    node.reset <= reset
    node.io_ll_valid <= NodeFirstLayer_1.io_up_valid @[src/main/scala/RotationalPrioritySelector.scala 215:24]
    node.io_ll_index <= NodeFirstLayer_1.io_up_index @[src/main/scala/RotationalPrioritySelector.scala 215:24]
    node.io_lr_valid <= NodeFirstLayer.io_up_valid @[src/main/scala/RotationalPrioritySelector.scala 214:24]
    node.io_lr_index <= NodeFirstLayer.io_up_index @[src/main/scala/RotationalPrioritySelector.scala 214:24]
    node.io_up_select <= node_2.io_lr_select @[src/main/scala/RotationalPrioritySelector.scala 231:32]
    node_1.clock <= clock
    node_1.reset <= reset
    node_1.io_ll_valid <= NodeFirstLayer_3.io_up_valid @[src/main/scala/RotationalPrioritySelector.scala 215:24]
    node_1.io_ll_index <= NodeFirstLayer_3.io_up_index @[src/main/scala/RotationalPrioritySelector.scala 215:24]
    node_1.io_lr_valid <= NodeFirstLayer_2.io_up_valid @[src/main/scala/RotationalPrioritySelector.scala 214:24]
    node_1.io_lr_index <= NodeFirstLayer_2.io_up_index @[src/main/scala/RotationalPrioritySelector.scala 214:24]
    node_1.io_up_select <= node_2.io_ll_select @[src/main/scala/RotationalPrioritySelector.scala 232:32]
    node_2.clock <= clock
    node_2.reset <= reset
    node_2.io_ll_valid <= node_1.io_up_valid @[src/main/scala/RotationalPrioritySelector.scala 232:32]
    node_2.io_ll_index <= node_1.io_up_index @[src/main/scala/RotationalPrioritySelector.scala 232:32]
    node_2.io_lr_valid <= node.io_up_valid @[src/main/scala/RotationalPrioritySelector.scala 231:32]
    node_2.io_lr_index <= node.io_up_index @[src/main/scala/RotationalPrioritySelector.scala 231:32]
    node_2.io_up_select <= io_in_head @[src/main/scala/RotationalPrioritySelector.scala 241:49]
