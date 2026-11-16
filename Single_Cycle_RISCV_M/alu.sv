`timescale 1ns/1ps

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
    // RV32M: Bulletproof 64-bit Multipliers
    // Explicitly extend operands to 64 bits to avoid any Verilog
    // implicit sizing or signedness quirks in Yosys/Simulators.
    // ============================================================
    logic [63:0]        rs1_u_ext, rs2_u_ext;
    logic signed [63:0] rs1_s_ext, rs2_s_ext;

    assign rs1_u_ext = {32'd0, rs1_data};
    assign rs2_u_ext = {32'd0, rs2_data};

    // Replicate the sign bit 32 times, then append the 32-bit data
    assign rs1_s_ext = {{32{rs1_data[31]}}, rs1_data};
    assign rs2_s_ext = {{32{rs2_data[31]}}, rs2_data};

    logic [63:0]        mul_u;      // unsigned x unsigned
    logic signed [63:0] mul_s;      // signed   x signed
    logic signed [63:0] mul_su;     // signed   x unsigned

    assign mul_u  = rs1_u_ext * rs2_u_ext;
    assign mul_s  = rs1_s_ext * rs2_s_ext;
    assign mul_su = rs1_s_ext * $signed(rs2_u_ext);


    // ============================================================
    // RV32M: Safe Division
    // Mask divisors to prevent simulator (C++/x86) crashes (SIGFPE)
    // ============================================================
    logic div_by_zero;
    logic div_overflow;

    assign div_by_zero  = (rs2_data == 32'd0);
    assign div_overflow = (rs1_data == 32'h8000_0000) && (rs2_data == 32'hFFFF_FFFF);

    // Safe divisors guarantee the hardware operator never panics
    logic signed [31:0] safe_rs2_s;
    logic [31:0]        safe_rs2_u;

    assign safe_rs2_s = (div_by_zero || div_overflow) ? 32'd1 : rs2_signed;
    assign safe_rs2_u = div_by_zero ? 32'd1 : rs2_data;

    logic signed [31:0] div_result;
    logic signed [31:0] rem_result;
    logic [31:0]        divu_result;
    logic [31:0]        remu_result;

    assign div_result  = rs1_signed / safe_rs2_s;
    assign rem_result  = rs1_signed % safe_rs2_s;
    assign divu_result = rs1_data / safe_rs2_u;
    assign remu_result = rs1_data % safe_rs2_u;


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
            5'b00000: alu_out = rs1_data + rs2_data;       // ADD / ADDI
            5'b00001: alu_out = rs1_data - rs2_data;       // SUB

            // ----------------------------------------------------
            // RV32M: Multiply
            // ----------------------------------------------------
            5'b10011: alu_out = mul_u[31:0];               // MUL
            5'b10100: alu_out = mul_s[63:32];              // MULH
            5'b10101: alu_out = mul_su[63:32];             // MULHSU
            5'b10110: alu_out = mul_u[63:32];              // MULHU

            // ----------------------------------------------------
            // RV32M: Divide / Remainder
            // ----------------------------------------------------
            5'b10111:                                      // DIV
                alu_out = div_by_zero  ? 32'hFFFF_FFFF :
                          div_overflow ? 32'h8000_0000 :
                                         div_result;

            5'b11000:                                      // DIVU
                alu_out = div_by_zero  ? 32'hFFFF_FFFF :
                                         divu_result;

            5'b11001:                                      // REM
                alu_out = div_by_zero  ? rs1_data :
                          div_overflow ? 32'h0000_0000 :
                                         rem_result;

            5'b11010:                                      // REMU
                alu_out = div_by_zero  ? rs1_data :
                                         remu_result;

            // ----------------------------------------------------
            // Logical
            // ----------------------------------------------------
            5'b00010: alu_out = rs1_data ^ rs2_data;       // XOR / XORI
            5'b00011: alu_out = rs1_data | rs2_data;       // OR / ORI
            5'b00100: alu_out = rs1_data & rs2_data;       // AND / ANDI

            // ----------------------------------------------------
            // Shift operations
            // ----------------------------------------------------
            5'b00101: alu_out = rs1_data << rs2_data[4:0]; // SLL / SLLI
            5'b00110: alu_out = rs1_data >> rs2_data[4:0]; // SRL / SRLI
            5'b00111: alu_out = rs1_signed >>> rs2_data[4:0]; // SRA / SRAI

            // ----------------------------------------------------
            // Set Less Than
            // ----------------------------------------------------
            5'b01000: alu_out = (rs1_signed < rs2_signed) ? 32'd1 : 32'd0; // SLT
            5'b01001: alu_out = (rs1_data < rs2_data)     ? 32'd1 : 32'd0; // SLTU

            // ----------------------------------------------------
            // Branch comparisons
            // ----------------------------------------------------
            5'b01010: zero = (rs1_data == rs2_data);       // BEQ
            5'b01011: zero = (rs1_data != rs2_data);       // BNE
            5'b01100: zero = (rs1_signed < rs2_signed);    // BLT
            5'b01101: zero = (rs1_signed >= rs2_signed);   // BGE
            5'b01110: zero = (rs1_data < rs2_data);        // BLTU
            5'b01111: zero = (rs1_data >= rs2_data);       // BGEU

            default: begin
                alu_out = {DATA_WIDTH{1'b0}};
                zero    = 1'b0;
            end
        endcase
    end

endmodule
