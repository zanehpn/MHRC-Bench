// Testbench for memwb.cpp (target version with <TARGET> placeholder)
// Tests the DUT methods: ext_sign_byte, ext_unsign_byte,
// ext_sign_halfword, ext_unsign_halfword
// by instantiating the memwb SC_MODULE and calling member functions directly.

#include <iostream>
#include <cstdlib>
#include "memwb.cpp"

int main() {
    sc_uint<XLEN> dmem[DCACHE_SIZE] = {};
    memwb dut("memwb_dut", dmem);

    int fail = 0;

    // ---- Test ext_sign_byte (LB) ----

    // Test 1: Positive byte (bit 7 = 0)
    {
        sc_bv<BYTE> data(0x7F);
        sc_bv<XLEN> result = dut.ext_sign_byte(data);
        if (result.to_uint() != 0x0000007F) {
            std::cerr << "FAIL: ext_sign_byte(0x7F) = 0x"
                      << std::hex << result.to_uint() << std::dec << std::endl;
            fail = 1;
        }
    }

    // Test 2: Negative byte (bit 7 = 1)
    {
        sc_bv<BYTE> data(0xFF);
        sc_bv<XLEN> result = dut.ext_sign_byte(data);
        if (result.to_uint() != 0xFFFFFFFF) {
            std::cerr << "FAIL: ext_sign_byte(0xFF) = 0x"
                      << std::hex << result.to_uint() << std::dec
                      << ", expected 0xFFFFFFFF" << std::endl;
            fail = 1;
        }
    }

    // Test 3: 0x80 = -128
    {
        sc_bv<BYTE> data(0x80);
        sc_bv<XLEN> result = dut.ext_sign_byte(data);
        if (result.to_uint() != 0xFFFFFF80) {
            std::cerr << "FAIL: ext_sign_byte(0x80) = 0x"
                      << std::hex << result.to_uint() << std::dec << std::endl;
            fail = 1;
        }
    }

    // ---- Test ext_unsign_byte (LBU) ----

    // Test 4: Zero-extend 0xFF
    {
        sc_bv<BYTE> data(0xFF);
        sc_bv<XLEN> result = dut.ext_unsign_byte(data);
        if (result.to_uint() != 0x000000FF) {
            std::cerr << "FAIL: ext_unsign_byte(0xFF) = 0x"
                      << std::hex << result.to_uint() << std::dec << std::endl;
            fail = 1;
        }
    }

    // Test 5: Zero
    {
        sc_bv<BYTE> data(0);
        sc_bv<XLEN> result = dut.ext_unsign_byte(data);
        if (result.to_uint() != 0) {
            std::cerr << "FAIL: ext_unsign_byte(0)" << std::endl;
            fail = 1;
        }
    }

    // ---- Test ext_sign_halfword (LH) ----

    // Test 6: Positive halfword
    {
        sc_bv<BYTE*2> data(0x7FFF);
        sc_bv<XLEN> result = dut.ext_sign_halfword(data);
        if (result.to_uint() != 0x00007FFF) {
            std::cerr << "FAIL: ext_sign_halfword(0x7FFF) = 0x"
                      << std::hex << result.to_uint() << std::dec << std::endl;
            fail = 1;
        }
    }

    // Test 7: Negative halfword 0xFFFE = -2
    {
        sc_bv<BYTE*2> data(0xFFFE);
        sc_bv<XLEN> result = dut.ext_sign_halfword(data);
        if (result.to_uint() != 0xFFFFFFFE) {
            std::cerr << "FAIL: ext_sign_halfword(0xFFFE) = 0x"
                      << std::hex << result.to_uint() << std::dec
                      << ", expected 0xFFFFFFFE" << std::endl;
            fail = 1;
        }
    }

    // Test 8: 0x8000 = -32768
    {
        sc_bv<BYTE*2> data(0x8000);
        sc_bv<XLEN> result = dut.ext_sign_halfword(data);
        if (result.to_uint() != 0xFFFF8000) {
            std::cerr << "FAIL: ext_sign_halfword(0x8000) = 0x"
                      << std::hex << result.to_uint() << std::dec << std::endl;
            fail = 1;
        }
    }

    // ---- Test ext_unsign_halfword (LHU) ----

    // Test 9: Zero-extend 0xFFFF
    {
        sc_bv<BYTE*2> data(0xFFFF);
        sc_bv<XLEN> result = dut.ext_unsign_halfword(data);
        if (result.to_uint() != 0x0000FFFF) {
            std::cerr << "FAIL: ext_unsign_halfword(0xFFFF) = 0x"
                      << std::hex << result.to_uint() << std::dec << std::endl;
            fail = 1;
        }
    }

    if (!fail)
        std::cout << "PASS: All memwb tests passed." << std::endl;

    return fail;
}
