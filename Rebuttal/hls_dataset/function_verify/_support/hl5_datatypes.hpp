/* Copyright 2017 Columbia University, SLD Group */
// hl5_datatypes.hpp - Data types for HL5 pipeline stages

#ifndef HL5_DATATYPES_H
#define HL5_DATATYPES_H

#include "systemc.h"
#include "defines.hpp"
#include "globals.hpp"

// Fetch
#ifndef fe_in_t_SC_WRAPPER_TYPE
#define fe_in_t_SC_WRAPPER_TYPE 1

struct fe_in_t
{
    sc_bv< 1 > jump;
    sc_bv< 1 > branch;
    sc_bv< PC_LEN > jump_address;
    sc_bv< PC_LEN > branch_address;

    fe_in_t()
    {
        jump    = "0";
        branch  = "0";
        jump_address = (sc_bv< PC_LEN >)0;
        branch_address = (sc_bv< PC_LEN >)0;
    }

    fe_in_t( const fe_in_t& other )
    {
        jump = other.jump;
        branch = other.branch;
        jump_address = other.jump_address;
        branch_address = other.branch_address;
    }

    inline bool operator == ( const fe_in_t& other )
    {
        if ( !(jump == other.jump) ) return false;
        if ( !(branch == other.branch) ) return false;
        if ( !(jump_address == other.jump_address) ) return false;
        if ( !(branch_address == other.branch_address) ) return false;
        return true;
    }

    inline fe_in_t& operator = ( const fe_in_t& other )
    {
        jump = other.jump;
        branch = other.branch;
        jump_address = other.jump_address;
        branch_address = other.branch_address;
        return *this;
    }
};

inline void sc_trace( sc_trace_file* tf, const fe_in_t& object, const std::string& in_name )
{
    if (tf) {
        tf->trace( object.jump, in_name + std::string(".jump"));
        tf->trace( object.branch, in_name + std::string(".branch"));
        tf->trace( object.jump_address, in_name + std::string(".jump_address"));
        tf->trace( object.branch_address, in_name + std::string(".branch_address"));
    }
}

inline ostream & operator << ( ostream & os, const fe_in_t& object )
{
    os << "(" << object.jump << "," << object.branch << "," << object.jump_address << "," << object.branch_address << ")";
    return os;
}
#endif

// Decode
#ifndef de_out_t_SC_WRAPPER_TYPE
#define de_out_t_SC_WRAPPER_TYPE 1

struct de_out_t
{
    sc_bv< 1 > regwrite;
    sc_bv< 1 > memtoreg;
    sc_bv< 3 > ld;
    sc_bv< 2 > st;
    sc_bv< ALUOP_SIZE > alu_op;
    sc_bv< ALUSRC_SIZE > alu_src;
    sc_bv< XLEN > rs1;
    sc_bv< XLEN > rs2;
    sc_bv< REG_ADDR > dest_reg;
    sc_bv< PC_LEN > pc;
    sc_bv< XLEN-12 > imm_u;
    sc_uint< TAG_WIDTH > tag;

    de_out_t()
    {
        regwrite    = "0";
        memtoreg    = "0";
        ld          = NO_LOAD;
        st          = NO_STORE;
        alu_op      = (sc_bv< ALUOP_SIZE >)0;
        alu_src     = (sc_bv< ALUSRC_SIZE >)0;
        rs1         = (sc_bv< XLEN >)0;
        rs2         = (sc_bv< XLEN >)0;
        dest_reg    = (sc_bv< REG_ADDR >)0;
        pc          = (sc_bv< PC_LEN >)0;
        imm_u       = (sc_bv< XLEN-12 >)0;
        tag         = (sc_uint< TAG_WIDTH >)0;
    }

    de_out_t( const de_out_t& other )
    {
        regwrite = other.regwrite;
        memtoreg = other.memtoreg;
        ld = other.ld;
        st = other.st;
        alu_op = other.alu_op;
        alu_src = other.alu_src;
        rs1 = other.rs1;
        rs2 = other.rs2;
        dest_reg = other.dest_reg;
        pc = other.pc;
        imm_u = other.imm_u;
        tag = other.tag;
    }

    inline bool operator == ( const de_out_t& other )
    {
        if ( !(regwrite == other.regwrite) ) return false;
        if ( !(memtoreg == other.memtoreg) ) return false;
        if ( !(ld == other.ld) ) return false;
        if ( !(st == other.st) ) return false;
        if ( !(alu_op == other.alu_op) ) return false;
        if ( !(alu_src == other.alu_src) ) return false;
        if ( !(rs1 == other.rs1) ) return false;
        if ( !(rs2 == other.rs2) ) return false;
        if ( !(dest_reg == other.dest_reg) ) return false;
        if ( !(pc == other.pc) ) return false;
        if ( !(imm_u == other.imm_u) ) return false;
        if ( !(tag == other.tag) ) return false;
        return true;
    }

    inline de_out_t& operator = ( const de_out_t& other )
    {
        regwrite = other.regwrite;
        memtoreg = other.memtoreg;
        ld = other.ld;
        st = other.st;
        alu_op = other.alu_op;
        alu_src = other.alu_src;
        rs1 = other.rs1;
        rs2 = other.rs2;
        dest_reg = other.dest_reg;
        pc = other.pc;
        imm_u = other.imm_u;
        tag = other.tag;
        return *this;
    }
};

inline void sc_trace( sc_trace_file* tf, const de_out_t& object, const std::string& in_name )
{
    if (tf) {
        tf->trace( object.regwrite, in_name + std::string(".regwrite"));
        tf->trace( object.memtoreg, in_name + std::string(".memtoreg"));
        tf->trace( object.ld, in_name + std::string(".ld"));
        tf->trace( object.st, in_name + std::string(".st"));
        tf->trace( object.alu_op, in_name + std::string(".alu_op"));
        tf->trace( object.alu_src, in_name + std::string(".alu_src"));
        tf->trace( object.rs1, in_name + std::string(".rs1"));
        tf->trace( object.rs2, in_name + std::string(".rs2"));
        tf->trace( object.dest_reg, in_name + std::string(".dest_reg"));
        tf->trace( object.pc, in_name + std::string(".pc"));
        tf->trace( object.imm_u, in_name + std::string(".imm_u"));
        tf->trace( object.tag, in_name + std::string(".tag"));
    }
}

inline ostream & operator << ( ostream & os, const de_out_t& object )
{
    os << "(" << object.regwrite << "," << object.memtoreg << ")";
    return os;
}
#endif

// Execute
#ifndef exe_out_t_SC_WRAPPER_TYPE
#define exe_out_t_SC_WRAPPER_TYPE 1

struct exe_out_t
{
    sc_bv< 3 > ld;
    sc_bv< 2 > st;
    sc_bv< 1 > memtoreg;
    sc_bv< 1 > regwrite;
    sc_bv< XLEN > alu_res;
    sc_bv< DATA_SIZE > mem_datain;
    sc_bv< REG_ADDR > dest_reg;
    sc_uint< TAG_WIDTH > tag;

    exe_out_t()
    {
        ld  = NO_LOAD;
        st  = NO_STORE;
        memtoreg    = "0";
        regwrite    = "0";
        alu_res     = (sc_bv< XLEN >)0;
        mem_datain  = (sc_bv< DATA_SIZE >)0;
        dest_reg    = (sc_bv< REG_ADDR >)0;
        tag         = (sc_uint< TAG_WIDTH >)0;
    }

    exe_out_t( const exe_out_t& other )
    {
        ld = other.ld;
        st = other.st;
        memtoreg = other.memtoreg;
        regwrite = other.regwrite;
        alu_res = other.alu_res;
        mem_datain = other.mem_datain;
        dest_reg = other.dest_reg;
        tag = other.tag;
    }

    inline bool operator == ( const exe_out_t& other )
    {
        if ( !(ld == other.ld) ) return false;
        if ( !(st == other.st) ) return false;
        if ( !(memtoreg == other.memtoreg) ) return false;
        if ( !(regwrite == other.regwrite) ) return false;
        if ( !(alu_res == other.alu_res) ) return false;
        if ( !(mem_datain == other.mem_datain) ) return false;
        if ( !(dest_reg == other.dest_reg) ) return false;
        return true;
    }

    inline exe_out_t& operator = ( const exe_out_t& other )
    {
        ld = other.ld;
        st = other.st;
        memtoreg = other.memtoreg;
        regwrite = other.regwrite;
        alu_res = other.alu_res;
        mem_datain = other.mem_datain;
        dest_reg = other.dest_reg;
        tag = other.tag;
        return *this;
    }
};

inline void sc_trace( sc_trace_file* tf, const exe_out_t& object, const std::string& in_name )
{
    if (tf) {
        tf->trace( object.ld, in_name + std::string(".ld"));
        tf->trace( object.st, in_name + std::string(".st"));
    }
}

inline ostream & operator << ( ostream & os, const exe_out_t& object )
{
    os << "(" << object.ld << "," << object.st << ")";
    return os;
}
#endif

// Memory
#ifndef mem_out_t_SC_WRAPPER_TYPE
#define mem_out_t_SC_WRAPPER_TYPE 1

struct mem_out_t
{
    sc_bv< 1 > regwrite;
    sc_bv< REG_ADDR > regfile_address;
    sc_bv< XLEN > regfile_data;
    sc_uint< TAG_WIDTH > tag;

    mem_out_t()
    {
        regwrite    = "0";
        regfile_data    = (sc_bv< XLEN >)0;
        regfile_address = (sc_bv< REG_ADDR >)0;
        tag             = (sc_uint< TAG_WIDTH >)0;
    }

    mem_out_t( const mem_out_t& other )
    {
        regwrite = other.regwrite;
        regfile_data = other.regfile_data;
        regfile_address = other.regfile_address;
        tag = other.tag;
    }

    inline bool operator == ( const mem_out_t& other )
    {
        if ( !(regwrite == other.regwrite) ) return false;
        if ( !(regfile_data == other.regfile_data) ) return false;
        if ( !(regfile_address == other.regfile_address) ) return false;
        if ( !(tag == other.tag) ) return false;
        return true;
    }

    inline mem_out_t& operator = ( const mem_out_t& other )
    {
        regwrite = other.regwrite;
        regfile_data = other.regfile_data;
        regfile_address = other.regfile_address;
        tag = other.tag;
        return *this;
    }
};

inline void sc_trace( sc_trace_file* tf, const mem_out_t& object, const std::string& in_name )
{
    if (tf) {
        tf->trace( object.regwrite, in_name + std::string(".regwrite"));
    }
}

inline ostream & operator << ( ostream & os, const mem_out_t& object )
{
    os << "(" << object.regwrite << ")";
    return os;
}
#endif

// Forward
#ifndef reg_forward_t_SC_WRAPPER_TYPE
#define reg_forward_t_SC_WRAPPER_TYPE 1

struct reg_forward_t
{
    sc_bv< XLEN > regfile_data;
    bool ldst;
    sc_uint< TAG_WIDTH > tag;

    reg_forward_t()
    {
        regfile_data    = (sc_bv< XLEN >)0;
        ldst            = false;
        tag             = (sc_uint< TAG_WIDTH >)0;
    }

    reg_forward_t( const reg_forward_t& other )
    {
        regfile_data = other.regfile_data;
        ldst = other.ldst;
        tag = other.tag;
    }

    inline bool operator == ( const reg_forward_t& other )
    {
        if ( !(regfile_data == other.regfile_data) ) return false;
        if ( !(ldst == other.ldst) ) return false;
        if ( !(tag == other.tag) ) return false;
        return true;
    }

    inline reg_forward_t& operator = ( const reg_forward_t& other )
    {
        regfile_data = other.regfile_data;
        ldst = other.ldst;
        tag = other.tag;
        return *this;
    }
};

inline void sc_trace( sc_trace_file* tf, const reg_forward_t& object, const std::string& in_name )
{
    if (tf) {
        tf->trace( object.regfile_data, in_name + std::string(".regfile_data"));
    }
}

inline ostream & operator << ( ostream & os, const reg_forward_t& object )
{
    os << "(" << std::hex << object.regfile_data.to_uint() << std::dec << ")";
    return os;
}
#endif

#endif  // HL5_DATATYPES_H
