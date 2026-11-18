module tb_top (
    input logic clk,
    input logic reset,
    output logic [7:0] debug_out // Forces Verilator to keep the core alive
);

    // 256KB Memory Array (matches your link.ld RAM_LENGTH)
    logic [7:0] mem [0:262143];

    // Wires to connect to your core
    logic [31:0] address;
    logic [31:0] instruction;
    logic [31:0] alu_out;
    logic [31:0] rs2_data;
    logic mem_read;
    logic mem_write;
    logic [31:0] mem_out;
    
    // Dummy wires to clear the PINMISSING warnings
    logic [2:0] fn3;
    logic [6:0] opcode;

    // Combinational Instruction Fetch (Base address 0x80000000)
    logic [31:0] pc_offset;
    assign pc_offset = address - 32'h8000_0000;

    always_comb begin
        if (reset)
            instruction = 32'h00000013; // NOP
        else if (address >= 32'h8000_0000 && pc_offset < 262140)
            instruction = {mem[pc_offset+3], mem[pc_offset+2], mem[pc_offset+1], mem[pc_offset+0]};
        else
            instruction = 32'h00000013; // NOP
    end

 // Combinational Data Read
    logic [31:0] data_offset;
    assign data_offset = alu_out - 32'h8000_0000;
    logic [31:0] raw_read_data;

    // Fetch the raw bytes starting at the target address
    always_comb begin
        if (mem_read && alu_out >= 32'h8000_0000 && data_offset < 262140)
            raw_read_data = {mem[data_offset+3], mem[data_offset+2], mem[data_offset+1], mem[data_offset+0]};
        else
            raw_read_data = 32'h0;
    end

    // Sign-extend or zero-extend based on fn3
    always_comb begin
        case (fn3)
            3'b000: mem_out = {{24{raw_read_data[7]}}, raw_read_data[7:0]};   // lb
            3'b001: mem_out = {{16{raw_read_data[15]}}, raw_read_data[15:0]}; // lh
            3'b010: mem_out = raw_read_data;                                  // lw
            3'b100: mem_out = {24'b0, raw_read_data[7:0]};                    // lbu
            3'b101: mem_out = {16'b0, raw_read_data[15:0]};                   // lhu
            default: mem_out = raw_read_data;
        endcase
    end

    // Data Write
    always_ff @(posedge clk) begin
        if (mem_write && alu_out >= 32'h8000_0000 && data_offset < 262140) begin
            if (fn3 == 3'b000) begin // sb (Store Byte - 1 byte)
                mem[data_offset+0] <= rs2_data[7:0];
            end
            else if (fn3 == 3'b001) begin // sh (Store Halfword - 2 bytes)
                mem[data_offset+0] <= rs2_data[7:0];
                mem[data_offset+1] <= rs2_data[15:8];
            end
            else begin // sw (Store Word - 4 bytes)
                mem[data_offset+0] <= rs2_data[7:0];
                mem[data_offset+1] <= rs2_data[15:8];
                mem[data_offset+2] <= rs2_data[23:16];
                mem[data_offset+3] <= rs2_data[31:24];
            end
        end
    end

    // Instantiate your core
    single_cycle_riscv core (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),
        .instruction(instruction),
        .mem_out(mem_out),
        .address(address),
        .alu_out(alu_out),
        .rs2_data(rs2_data),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .fn3(fn3),
        .opcode(opcode)
    );

    // If the memory index relies on ALU out, Verilator cannot delete the array or ALU
    assign debug_out = mem[alu_out[17:0]];

endmodule