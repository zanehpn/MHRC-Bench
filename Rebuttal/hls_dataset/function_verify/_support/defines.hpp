/* Copyright 2017 Columbia University, SLD Group */
// defines.hpp - HL5 processor configuration defines

#ifndef DEFINES_H
#define DEFINES_H

// Enable/disable multiplier, divider, CSR.
#define MUL32       1
#define MUL64       1
#define DIV         1
#define REM         1
#define CSR_LOGIC   1

// Cache size
#define ICACHE_SIZE 51200
#define DCACHE_SIZE 51200

#define TAG_WIDTH 4
#define FWD_ENABLE

// Dbg directives.
#define VERBOSE

#endif // DEFINES_H
