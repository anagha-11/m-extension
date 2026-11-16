`timescale 1ns/1ps

module decoder(
    input  logic [31:0] instruction,

    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,

    output logic [6:0]  opcode,
    output logic [6:0]  imm11_5,

    output logic [2:0]  fn3,

    output logic [11:0] imm,
    output logic [19:0] imm_uj,

    output logic        fn7_5,
    output logic        fn7_0           // instruction[25]: RV32M select
);

always_comb
begin
    // Default values
    rd       = 5'd0;
    fn3      = 3'd0;
    rs1      = 5'd0;
    rs2      = 5'd0;
    imm      = 12'd0;
    imm_uj   = 20'd0;
    imm11_5  = 7'd0;
    fn7_5    = 1'b0;
    fn7_0    = 1'b0;

    opcode = instruction[6:0];

    case(opcode)

        // ========================================================
        // R-Type
        // ========================================================
        7'b0110011:
        begin
            rd     = instruction[11:7];
            fn3    = instruction[14:12];
            rs1    = instruction[19:15];
            rs2    = instruction[24:20];
            fn7_5  = instruction[30];
            fn7_0  = instruction[25];   // 1 = RV32M (MUL/DIV/REM family)
        end


        // ========================================================
        // I-Type ALU
        // ========================================================
        7'b0010011:
        begin
            rd       = instruction[11:7];
            fn3      = instruction[14:12];
            rs1      = instruction[19:15];
            imm      = instruction[31:20];
            imm11_5  = instruction[31:25];
        end


        // ========================================================
        // Load
        // ========================================================
        7'b0000011:
        begin
            rd     = instruction[11:7];
            fn3    = instruction[14:12];
            rs1    = instruction[19:15];
            imm    = instruction[31:20];
        end


        // ========================================================
        // Store
        // ========================================================
        7'b0100011:
        begin
            fn3 = instruction[14:12];
            rs1 = instruction[19:15];
            rs2 = instruction[24:20];

            imm = {
                instruction[31:25],
                instruction[11:7]
            };
        end


        // ========================================================
        // B-Type Branch
        // ========================================================
        7'b1100011:
        begin
            fn3 = instruction[14:12];
            rs1 = instruction[19:15];
            rs2 = instruction[24:20];

            imm = {
                instruction[31],
                instruction[7],
                instruction[30:25],
                instruction[11:8]
            };
        end


        // ========================================================
        // J-Type JAL
        // ========================================================
        7'b1101111:
        begin
            rd = instruction[11:7];

            imm_uj = {
                instruction[31],
                instruction[19:12],
                instruction[20],
                instruction[30:21]
            };
        end


        // ========================================================
        // U-Type LUI
        // ========================================================
        7'b0110111:
        begin
            rd = instruction[11:7];

            imm_uj = instruction[31:12];
        end


        // ========================================================
        // J-Type JALR
        // ========================================================
        7'b1100111:
        begin
            rd  = instruction[11:7];
            rs1 = instruction[19:15];
            fn3 = instruction[14:12];

            imm = instruction[31:20];
        end


        // ========================================================
        // U-Type AUIPC
        // ========================================================
        7'b0010111:
        begin
            rd = instruction[11:7];

            imm_uj = instruction[31:12];
        end


        // ========================================================
        // No SYSTEM / CSR instruction
        // ========================================================
        default:
        begin
            rd       = 5'd0;
            fn3      = 3'd0;
            rs1      = 5'd0;
            rs2      = 5'd0;
            imm      = 12'd0;
            imm_uj   = 20'd0;
            imm11_5  = 7'd0;
            fn7_5    = 1'b0;
            fn7_0    = 1'b0;
        end

    endcase
end

endmodule
