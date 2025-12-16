
// control.v - Control Unit for RV32I + AES custom instruction
module control(
    input  [31:0] instr,
    output reg    reg_write,
    output reg    mem_write,
    output reg    mem_read,
    output reg    branch,
    output reg    jump_jal,
    output reg    jump_jalr,
    output reg [3:0] alu_op,
    output reg    alu_src_imm,
    output reg    mem_to_reg,
    output        is_ebreak,
    output        is_aes,
    output        aes_dec
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    // EBREAK
    assign is_ebreak = (instr == 32'h00100073);

    // CUSTOM-0
    wire opcode_custom0 = (opcode == 7'b0001011);
    assign is_aes  = opcode_custom0 && (funct3 == 3'b000);
    assign aes_dec = instr[25]; // LSB of funct7

    // Default
    localparam ALU_ADD=4'd0, ALU_SUB=4'd1, ALU_AND=4'd2, ALU_OR=4'd3, ALU_XOR=4'd4,
               ALU_SLL=4'd5, ALU_SRL=4'd6, ALU_SRA=4'd7, ALU_SLT=4'd8, ALU_SLTU=4'd9;

    always @(*) begin
        reg_write=0; mem_write=0; mem_read=0; branch=0; jump_jal=0; jump_jalr=0;
        alu_op=ALU_ADD; alu_src_imm=0; mem_to_reg=0;

        case(opcode)
            7'b0110011: begin // OP
                reg_write=1;
                case({funct7,funct3})
                    {7'b0000000,3'b000}: alu_op=ALU_ADD;
                    {7'b0100000,3'b000}: alu_op=ALU_SUB;
                    {7'b0000000,3'b111}: alu_op=ALU_AND;
                    {7'b0000000,3'b110}: alu_op=ALU_OR;
                    {7'b0000000,3'b100}: alu_op=ALU_XOR;
                    {7'b0000000,3'b001}: alu_op=ALU_SLL;
                    {7'b0000000,3'b101}: alu_op=ALU_SRL;
                    {7'b0100000,3'b101}: alu_op=ALU_SRA;
                    {7'b0000000,3'b010}: alu_op=ALU_SLT;
                    {7'b0000000,3'b011}: alu_op=ALU_SLTU;
                endcase
            end
            7'b0010011: begin // OP-IMM
                reg_write=1; alu_src_imm=1;
                case(funct3)
                    3'b000: alu_op=ALU_ADD;
                    3'b111: alu_op=ALU_AND;
                    3'b110: alu_op=ALU_OR;
                    3'b100: alu_op=ALU_XOR;
                    3'b001: alu_op=ALU_SLL;
                    3'b101: alu_op=(funct7==7'b0100000)?ALU_SRA:ALU_SRL;
                    3'b010: alu_op=ALU_SLT;
                    3'b011: alu_op=ALU_SLTU;
                endcase
            end
            7'b0000011: begin // LOAD
                reg_write=1; mem_read=1; alu_src_imm=1; mem_to_reg=1;
            end
            7'b0100011: begin // STORE
                mem_write=1; alu_src_imm=1;
            end
            7'b1100011: begin // BRANCH
                branch=1;
            end
            7'b1101111: begin // JAL
                jump_jal=1; reg_write=1;
            end
            7'b1100111: begin // JALR
                jump_jalr=1; reg_write=1; alu_src_imm=1;
            end
            7'b0110111: begin // LUI
                reg_write=1; alu_src_imm=1;
            end
            7'b0010111: begin // AUIPC
                reg_write=1; alu_src_imm=1;
            end
            7'b0001011: begin // AES (custom-0)
                // handled in cpu FSM
                reg_write=0; mem_write=0; mem_read=0;
            end
        endcase
    end
endmodule
