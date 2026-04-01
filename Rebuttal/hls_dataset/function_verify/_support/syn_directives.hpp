// Mock syn_directives.hpp - HLS synthesis directives stubbed out for g++
#ifndef SYN_DIRECTIVES_H
#define SYN_DIRECTIVES_H

// All HLS directives are no-ops for software compilation
#define HLS_FLATTEN_ARRAY(x)
#define HLS_MAP_TO_MEMORY(x, y)
#define HLS_DEFINE_PROTOCOL(x)
#define HLS_BREAK_PROTOCOL(x)
#define HLS_BREAK_ARRAY_DEPENDENCY(x)
#define HLS_UNROLL_LOOP(...)
#define HLS_SPLIT_MULTIPLY(...)
#define HLS_SPLIT_ADD(...)

#define FLAT_PROGRAM
#define FLAT_REGFILE
#define FLAT_SENTINEL
#define MAP_ICACHE
#define MAP_DCACHE
#define PROTO_FEDEC_RST
#define PROTO_FEDEC_BODY
#define PROTO_EXE_RST
#define PROTO_PERF_RST
#define PROTO_EXE_BODY
#define PROTO_PERF_BODY
#define PROTO_MEMWB_RST
#define PROTO_MEMWB_BODY
#define BREAK_DMEM_DEP
#define DIV_UNROLL
#define MUL_SPLIT
#define ADD_SPLIT

#endif // SYN_DIRECTIVES_H
