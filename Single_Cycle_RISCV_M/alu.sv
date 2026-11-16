`timescale 1ns/1ps

// =============================================================================
// Operation encoding (alu_control → 5 bits):
//
//   00000  ADD
//   00001  SUB
//   00010  XOR
//   00011  OR
//   00100  AND
//   00101  SLL
//   00110  SRL
//   00111  SRA
//   01000  SLT
//   01001  SLTU
//   01010  BEQ
//   01011  BNE
//   01100  BLT
//   01101  BGE
//   01110  BLTU
//   01111  BGEU
//
//   10000 - 10010  Unused (reserved)
//   10011  MUL      rs1 * rs2           [31:0]
//   10100  MULH     signed   x signed   [63:32]
//   10101  MULHSU   signed   x unsigned [63:32]
//   10110  MULHU    unsigned x unsigned [63:32]
//   10111  DIV      signed   division
//   11000  DIVU     unsigned division
//   11001  REM      signed   remainder
//   11010  REMU     unsigned remainder
//   11011 - 11111  Unused
// =============================================================================

module alu #(
    parameter int DATA_WIDTH = 32
)(
    input  logic [4:0]            alu_control,

    input  logic [DATA_WIDTH-1:0] rs1_data,
    input  logic [DATA_WIDTH-1:0] rs2_data,

    output logic [DATA_WIDTH-1:0] alu_out,
    output logic                  zero
);

    // ============================================================
    // Signed views of operands
    // ============================================================
    logic signed [DATA_WIDTH-1:0] rs1_signed;
    logic signed [DATA_WIDTH-1:0] rs2_signed;

    assign rs1_signed = $signed(rs1_data);
    assign rs2_signed = $signed(rs2_data);


    // ============================================================
    // RV32M datapath
    //
    // Full 64-bit products for MUL / MULH / MULHSU / MULHU.
    // Divide / remainder results are only used when the divisor is
    // non-zero and there is no signed overflow (guarded below).
    // ============================================================
    logic [63:0]        mul_u;      // unsigned x unsigned
    logic signed [63:0] mul_s;      // signed   x signed
    logic signed [63:0] mul_su;     // signed   x unsigned

    logic signed [DATA_WIDTH-1:0] div_result;
    logic signed [DATA_WIDTH-1:0] rem_result;

    logic div_by_zero;
    logic div_overflow;             // INT_MIN / -1

    assign mul_u  = rs1_data * rs2_data;
    assign mul_s  = rs1_signed * rs2_signed;
    // Zero-extend rs2 to 33 bits so it is treated as unsigned
    assign mul_su = $signed({rs1_data[DATA_WIDTH-1], rs1_data}) *
                    $signed({1'b0, rs2_data});

    assign div_by_zero  = (rs2_data == {DATA_WIDTH{1'b0}});
    assign div_overflow = (rs1_data == 32'h8000_0000) &&
                          (rs2_data == 32'hFFFF_FFFF);

    // Guard the operator so simulators never evaluate x/0
    assign div_result = div_by_zero ? '0 : (rs1_signed / rs2_signed);
    assign rem_result = div_by_zero ? '0 : (rs1_signed % rs2_signed);


    // ============================================================
    // ALU Operations
    // ============================================================
    always_comb begin

        // Safe defaults
        alu_out = {DATA_WIDTH{1'b0}};
        zero    = 1'b0;

        unique case (alu_control)

            // ----------------------------------------------------
            // Arithmetic
            // ----------------------------------------------------
            5'b00000:
                alu_out = rs1_data + rs2_data;       // ADD / ADDI

            5'b00001:
                alu_out = rs1_data - rs2_data;       // SUB


            // ----------------------------------------------------
            // RV32M: Multiply
            // ----------------------------------------------------
            5'b10011:
                alu_out = mul_u[31:0];               // MUL

            5'b10100:
                alu_out = mul_s[63:32];              // MULH

            5'b10101:
                alu_out = mul_su[63:32];             // MULHSU

            5'b10110:
                alu_out = mul_u[63:32];              // MULHU


            // ----------------------------------------------------
            // RV32M: Divide / Remainder
            //
            //   x / 0         : DIV/DIVU = all ones, REM/REMU = rs1
            //   INT_MIN / -1  : DIV = INT_MIN,       REM = 0
            // ----------------------------------------------------
            5'b10111:                                // DIV
                alu_out = div_by_zero  ? 32'hFFFF_FFFF :
                          div_overflow ? 32'h8000_0000 :
                                         div_result;

            5'b11000:                                // DIVU
                alu_out = div_by_zero  ? 32'hFFFF_FFFF :
                                         (rs1_data / rs2_data);

            5'b11001:                                // REM
                alu_out = div_by_zero  ? rs1_data :
                          div_overflow ? 32'h0000_0000 :
                                         rem_result;

            5'b11010:                                // REMU
                alu_out = div_by_zero  ? rs1_data :
                                         (rs1_data % rs2_data);


            // ----------------------------------------------------
            // Logical
            // ----------------------------------------------------
            5'b00010:
                alu_out = rs1_data ^ rs2_data;       // XOR / XORI

            5'b00011:
                alu_out = rs1_data | rs2_data;       // OR / ORI

            5'b00100:
                alu_out = rs1_data & rs2_data;       // AND / ANDI


            // ----------------------------------------------------
            // Shift operations
            // ----------------------------------------------------
            5'b00101:
                alu_out = rs1_data << rs2_data[4:0]; // SLL / SLLI

            5'b00110:
                alu_out = rs1_data >> rs2_data[4:0]; // SRL / SRLI

            5'b00111:
                alu_out = rs1_signed >>> rs2_data[4:0]; // SRA / SRAI


            // ----------------------------------------------------
            // Set Less Than
            // ----------------------------------------------------
            5'b01000:
                alu_out = (rs1_signed < rs2_signed)
                          ? 32'd1 : 32'd0;            // SLT / SLTI

            5'b01001:
                alu_out = (rs1_data < rs2_data)
                          ? 32'd1 : 32'd0;            // SLTU / SLTIU


            // ----------------------------------------------------
            // Branch comparisons
            //
            // Only 'zero' is used for branches.
            // alu_out remains 0.
            // ----------------------------------------------------
            5'b01010:
                zero = (rs1_data == rs2_data);       // BEQ

            5'b01011:
                zero = (rs1_data != rs2_data);       // BNE

            5'b01100:
                zero = (rs1_signed < rs2_signed);    // BLT

            5'b01101:
                zero = (rs1_signed >= rs2_signed);   // BGE

            5'b01110:
                zero = (rs1_data < rs2_data);        // BLTU

            5'b01111:
                zero = (rs1_data >= rs2_data);       // BGEU


            // ----------------------------------------------------
            // Undefined control codes
            // ----------------------------------------------------
            default:
            begin
                alu_out = {DATA_WIDTH{1'b0}};
                zero    = 1'b0;
            end

        endcase
    end

endmodule
