`timescale 1ns/1ps

module id_stage(
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,

    input  logic [31:0] instruction,
    input  logic [31:0] wb_data,

    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,
    output logic [31:0] imm_out,

    output logic [6:0]  opcode_out_d,
    output logic [6:0]  imm11_5,
    output logic [2:0]  fn3_out_d,
    output logic        fn7_5,
    output logic        fn7_0,

    output logic [2:0]  aluop,
    output logic [1:0]  memtoreg,

    output logic        branch,
    output logic        mem_write,
    output logic        mem_read,
    output logic        alu_src,
    output logic        mux_inp
);

    // ============================================================
    // Decoder outputs
    // ============================================================
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;

    logic [11:0] imm_i_s;
    logic [19:0] imm_u_j;

    logic reg_write_out;
    logic gated_reg_write;


    // ============================================================
    // Register write enable
    //
    // Do not write registers while the pipeline is stalled.
    // ============================================================
    assign gated_reg_write = reg_write_out && !stall;


    // ============================================================
    // Instruction Decoder
    // ============================================================
    decoder decode (
        .instruction(instruction),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .opcode(opcode_out_d),
        .fn3(fn3_out_d),
        .fn7_5(fn7_5),
        .fn7_0(fn7_0),

        .imm(imm_i_s),
        .imm_uj(imm_u_j),
        .imm11_5(imm11_5)
    );


    // ============================================================
    // Immediate Generator
    // ============================================================
    imm_generator imm_gen (
        .imm_input(imm_i_s),
        .imm_input_uj(imm_u_j),
        .opcode(opcode_out_d),
        .fn3(fn3_out_d),
        .imm_output(imm_out)
    );


    // ============================================================
    // Register File
    // ============================================================
    register_file reg_file (
        .clk(clk),
        .reset(reset),

        .rs1_sel(rs1),
        .rs2_sel(rs2),
        .rd_sel(rd),

        .reg_write(gated_reg_write),
        .wb_data(wb_data),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );


    // ============================================================
    // Main Control
    // ============================================================
    main_control mc (
        .opcode(opcode_out_d),
        .fn3(fn3_out_d),

        .branch(branch),
        .memtoreg(memtoreg),
        .aluop(aluop),

        .memwrite(mem_write),
        .alusrc(alu_src),

        .reg_write(reg_write_out),
        .memread(mem_read),

        .mux_inp(mux_inp)
    );

endmodule