`timescale 1ns / 1ps

// ============================================================================
// TOP LEVEL MODULE FOR EDGE ARTIX-7 FPGA BOARD (XC7A35T)
// ============================================================================
module top_edge_artix7(
    input         clk,             // 50 MHz Onboard Clock (PIN N11)
    input  [15:0] sw,              // 16 Slide Switches
    input  [4:0]  pb,              // Push Buttons (pb[0] = Reset, PIN K13)
    output [15:0] led,             // 16 Output LEDs
    output [3:0]  digit,           // 4-Digit 7-Segment Enables (Active-Low)
    output [7:0]  Seven_Seg        // 7-Segment Cathodes A..G + DP (Active-Low)
);

    // Synchronize active-high push button pb[0] to active-low reset_n
    reg [1:0] rst_sync = 2'b00;
    always @(posedge clk) begin
        rst_sync <= {rst_sync[0], pb[0]};
    end
    wire reset_n = ~rst_sync[1];

    // Core Interconnects
    wire [31:0] imem_addr, imem_instr;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_we, dmem_re, halted;
    wire [31:0] debug_pc, debug_reg_data;

    // Use slide switches sw[4:0] to select which Register (x0 to x31) to view
    wire [4:0] debug_reg_addr = sw[4:0];

    // CPU Core Instance
    cpu U_CPU (
        .clk(clk),
        .reset_n(reset_n),
        .imem_addr(imem_addr),
        .imem_instr(imem_instr),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_re(dmem_re),
        .halted(halted),
        .debug_pc(debug_pc),
        .debug_reg_data(debug_reg_data),
        .debug_reg_addr(debug_reg_addr)
    );

    // Instruction Memory Instance
    imem U_IMEM (
        .addr(imem_addr),
        .instr(imem_instr)
    );

    // Data Memory Instance
    dmem U_DMEM (
        .clk(clk),
        .mem_write(dmem_we),
        .mem_read(dmem_re),
        .addr(dmem_addr),
        .wd(dmem_wdata),
        .rd(dmem_rdata)
    );

    // Status Diagnostic LEDs
    assign led[0]    = halted;          // Turns ON when CPU reaches EBREAK
    assign led[1]    = ~reset_n;        // Turns ON when Reset button is pressed
    assign led[2]    = dmem_we;         // Pulses when Data Memory write occurs
    assign led[7:3]  = debug_reg_addr;  // Shows currently inspected register address
    assign led[15:8] = debug_pc[7:0];   // Shows lower 8 bits of Program Counter

    // 7-Segment Value Selection: sw[15]=0 -> Reg[15:0], sw[15]=1 -> Reg[31:16]
    wire [15:0] disp_hex = (sw[15] == 1'b0) ? debug_reg_data[15:0] : debug_reg_data[31:16];

    // Dynamic 7-Segment Multiplexing Controller (~1 kHz refresh)
    reg [16:0] clk_div = 0;
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end

    wire [1:0] scan_sel = clk_div[16:15];
    reg [3:0]  nibble;
    reg [3:0]  an_reg;

    always @(*) begin
        case (scan_sel)
            2'b00: begin an_reg = 4'b1110; nibble = disp_hex[3:0];   end
            2'b01: begin an_reg = 4'b1101; nibble = disp_hex[7:4];   end
            2'b10: begin an_reg = 4'b1011; nibble = disp_hex[11:8];  end
            2'b11: begin an_reg = 4'b0111; nibble = disp_hex[15:12]; end
        endcase
    end
    assign digit = an_reg;

    // Hexadecimal to 7-Segment Cathode Decoder (Active-Low: A, B, C, D, E, F, G)
    reg [6:0] seg_hex;
    always @(*) begin
        case (nibble)
            4'h0: seg_hex = 7'b1000000;
            4'h1: seg_hex = 7'b1111001;
            4'h2: seg_hex = 7'b0100100;
            4'h3: seg_hex = 7'b0110000;
            4'h4: seg_hex = 7'b0011001;
            4'h5: seg_hex = 7'b0010010;
            4'h6: seg_hex = 7'b0000010;
            4'h7: seg_hex = 7'b1111000;
            4'h8: seg_hex = 7'b0000000;
            4'h9: seg_hex = 7'b0010000;
            4'hA: seg_hex = 7'b0001000;
            4'hB: seg_hex = 7'b0000011;
            4'hC: seg_hex = 7'b1000110;
            4'hD: seg_hex = 7'b0100001;
            4'hE: seg_hex = 7'b0000110;
            4'hF: seg_hex = 7'b0001110;
        endcase
    end
    assign Seven_Seg = {1'b1, seg_hex}; // Decimal point DP is kept OFF (1'b1)

endmodule


// ============================================================================
// CPU CORE MODULE
// ============================================================================
module cpu(
    input         clk,
    input         reset_n,
    output [31:0] imem_addr,
    input  [31:0] imem_instr,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    input  [31:0] dmem_rdata,
    output        dmem_we,
    output        dmem_re,
    output        halted,
    output [31:0] debug_pc,
    output [31:0] debug_reg_data,
    input  [4:0]  debug_reg_addr
);
    reg [31:0] pc;
    assign imem_addr = pc;
    assign debug_pc  = pc;

    wire [31:0] instr = imem_instr;
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1_i  = instr[19:15];
    wire [4:0]  rs2_i  = instr[24:20];

    wire reg_write, mem_write, mem_read, branch, jump_jal, jump_jalr;
    wire [3:0] alu_op;
    wire alu_src_imm, mem_to_reg, is_ebreak, is_aes, aes_dec;

    control u_ctl(
        .instr(instr), .reg_write(reg_write), .mem_write(mem_write), .mem_read(mem_read),
        .branch(branch), .jump_jal(jump_jal), .jump_jalr(jump_jalr),
        .alu_op(alu_op), .alu_src_imm(alu_src_imm), .mem_to_reg(mem_to_reg),
        .is_ebreak(is_ebreak), .is_aes(is_aes), .aes_dec(aes_dec)
    );

    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    immgen u_imm(.instr(instr), .imm_i(imm_i), .imm_s(imm_s), .imm_b(imm_b), .imm_u(imm_u), .imm_j(imm_j));

    reg        aes_busy, boot_busy;
    reg [3:0]  aes_state;
    reg [4:0]  aes_rs1_base, aes_rs2_base, aes_rd_base;

    wire [4:0] rs1_mux = (aes_busy && (aes_state < 4)) ? (aes_rs1_base + aes_state[1:0]) : rs1_i;
    wire [4:0] rs2_mux = (aes_busy && (aes_state < 4)) ? (aes_rs2_base + aes_state[1:0]) : rs2_i;
    wire [31:0] rs1_val, rs2_val;
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;

    regfile u_rf(
        .clk(clk), .we(rf_we),
        .rs1(rs1_mux), .rs2(rs2_mux),
        .rd(rf_waddr), .wd(rf_wdata),
        .rd1(rs1_val), .rd2(rs2_val),
        .debug_addr(debug_reg_addr),
        .debug_data(debug_reg_data)
    );

    wire [31:0] imm_for_alu = (opcode==7'b0100011) ? imm_s : (opcode==7'b0110111) ? imm_u : imm_i;
    wire [31:0] alu_b = alu_src_imm ? imm_for_alu : rs2_val;
    wire [31:0] alu_a = (opcode==7'b0010111) ? pc : rs1_val;
    wire [31:0] alu_y;
    alu u_alu(.alu_op(alu_op), .a(alu_a), .b(alu_b), .y(alu_y));

    assign dmem_addr  = alu_y;
    assign dmem_wdata = rs2_val;
    assign dmem_we    = (!aes_busy && !boot_busy) ? mem_write : 1'b0;
    assign dmem_re    = (!aes_busy && !boot_busy) ? mem_read  : 1'b0;

    reg        aes_mode_dec;
    reg [127:0] key_buf, data_buf, aes_res;
    wire [127:0] aes_comb_out;
    aes_core u_aes(
        .data_in(data_buf), .key(key_buf), .enc_dec(aes_mode_dec), .data_out(aes_comb_out)
    );

    wire take_beq = (funct3==3'b000) && (rs1_val == rs2_val);
    wire take_bne = (funct3==3'b001) && (rs1_val != rs2_val);
    wire do_branch = branch && (take_beq || take_bne);

    wire [31:0] pc_next_norm = do_branch ? (pc + imm_b) :
                               jump_jal  ? (pc + imm_j) :
                               jump_jalr ? ((rs1_val + imm_i) & ~32'd1) :
                               (pc + 32'd4);

    reg halt_r;
    assign halted = halt_r;
    reg [3:0] boot_idx;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pc <= 32'b0;
            halt_r <= 1'b0;
            aes_busy <= 0;
            aes_state <= 0;
            key_buf <= 0;
            data_buf <= 0;
            aes_res <= 0;
            rf_we <= 0;
            rf_waddr <= 0;
            rf_wdata <= 0;
            boot_busy <= 1'b1;
            boot_idx <= 0;
        end else begin
            rf_we <= 0;

            if (is_ebreak && !aes_busy && !boot_busy) begin
                halt_r <= 1'b1;
            end

            // Boot-preload AES vectors into x10..x17
            if (boot_busy) begin
                rf_we <= 1'b1;
                case (boot_idx)
                    4'd0: begin rf_waddr <= 5'd10; rf_wdata <= 32'hd4c3b2a1; end
                    4'd1: begin rf_waddr <= 5'd11; rf_wdata <= 32'h1807f6e5; end
                    4'd2: begin rf_waddr <= 5'd12; rf_wdata <= 32'h5c4b3a29; end
                    4'd3: begin rf_waddr <= 5'd13; rf_wdata <= 32'h90f8e7d6; end
                    4'd4: begin rf_waddr <= 5'd14; rf_wdata <= 32'hcaa0470f; end
                    4'd5: begin rf_waddr <= 5'd15; rf_wdata <= 32'h2e7f5dcc; end
                    4'd6: begin rf_waddr <= 5'd16; rf_wdata <= 32'h28093d1b; end
                    4'd7: begin rf_waddr <= 5'd17; rf_wdata <= 32'hd8c6a1f4; end
                    default: rf_we <= 1'b0;
                endcase
                if (boot_idx == 4'd7)
                    boot_busy <= 1'b0;
                else
                    boot_idx <= boot_idx + 1'b1;
            end
            else if (aes_busy) begin
                case (aes_state)
                    4'd0: begin key_buf[31:0]   <= rs1_val; data_buf[31:0]   <= rs2_val; aes_state <= 4'd1; end
                    4'd1: begin key_buf[63:32]  <= rs1_val; data_buf[63:32]  <= rs2_val; aes_state <= 4'd2; end
                    4'd2: begin key_buf[95:64]  <= rs1_val; data_buf[95:64]  <= rs2_val; aes_state <= 4'd3; end
                    4'd3: begin key_buf[127:96] <= rs1_val; data_buf[127:96] <= rs2_val; aes_state <= 4'd4; end
                    4'd4: begin aes_res <= aes_comb_out; aes_state <= 4'd8; end
                    4'd8: begin rf_we <= 1'b1; rf_waddr <= aes_rd_base + 0; rf_wdata <= aes_res[31:0];   aes_state <= 4'd9;  end
                    4'd9: begin rf_we <= 1'b1; rf_waddr <= aes_rd_base + 1; rf_wdata <= aes_res[63:32];  aes_state <= 4'd10; end
                   4'd10: begin rf_we <= 1'b1; rf_waddr <= aes_rd_base + 2; rf_wdata <= aes_res[95:64];  aes_state <= 4'd11; end
                   4'd11: begin rf_we <= 1'b1; rf_waddr <= aes_rd_base + 3; rf_wdata <= aes_res[127:96]; aes_state <= 4'd15; end
                 default: begin aes_busy <= 1'b0; aes_state <= 4'd0; end
                endcase
            end
            else if (!halt_r) begin
                pc <= pc_next_norm;

                if (reg_write) begin
                    rf_we    <= 1'b1;
                    rf_waddr <= rd;
                    if (mem_to_reg)
                        rf_wdata <= dmem_rdata;
                    else if (opcode == 7'b0110111) // LUI
                        rf_wdata <= imm_u;
                    else if (jump_jal || jump_jalr)
                        rf_wdata <= pc + 32'd4;
                    else
                        rf_wdata <= alu_y;
                end

                if (is_aes) begin
                    aes_busy      <= 1'b1;
                    aes_state     <= 4'd0;
                    aes_rs1_base  <= rs1_i;
                    aes_rs2_base  <= rs2_i;
                    aes_rd_base   <= rd;
                    aes_mode_dec  <= aes_dec;
                end
            end
        end
    end
endmodule


// ============================================================================
// REGISTER FILE
// ============================================================================
module regfile(
    input             clk,
    input             we,
    input      [4:0]  rs1,
    input      [4:0]  rs2,
    input      [4:0]  rd,
    input      [31:0] wd,
    output     [31:0] rd1,
    output     [31:0] rd2,
    input      [4:0]  debug_addr,
    output     [31:0] debug_data
);
    reg [31:0] regs[0:31];
    integer j;
    initial begin
        for (j = 0; j < 32; j = j + 1)
            regs[j] = 32'b0;
    end

    assign rd1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];
    assign debug_data = (debug_addr == 5'd0) ? 32'b0 : regs[debug_addr];

    always @(posedge clk) begin
        if (we && rd != 5'd0)
            regs[rd] <= wd;
    end
endmodule


// ============================================================================
// CONTROL UNIT
// ============================================================================
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

    assign is_ebreak = (instr == 32'h00100073);
    wire opcode_custom0 = (opcode == 7'b0001011);
    assign is_aes  = opcode_custom0 && (funct3 == 3'b000);
    assign aes_dec = instr[25];

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
            7'b0001011: begin // AES
                reg_write=0; mem_write=0; mem_read=0;
            end
        endcase
    end
endmodule


// ============================================================================
// ALU
// ============================================================================
module alu(
    input  [3:0]  alu_op,
    input  [31:0] a,
    input  [31:0] b,
    output reg [31:0] y
);
    localparam ALU_ADD=4'd0, ALU_SUB=4'd1, ALU_AND=4'd2, ALU_OR=4'd3, ALU_XOR=4'd4,
               ALU_SLL=4'd5, ALU_SRL=4'd6, ALU_SRA=4'd7, ALU_SLT=4'd8, ALU_SLTU=4'd9;
    wire signed [31:0] sa=a, sb=b;

    always @(*) begin
        case(alu_op)
            ALU_ADD: y = a + b;
            ALU_SUB: y = a - b;
            ALU_AND: y = a & b;
            ALU_OR : y = a | b;
            ALU_XOR: y = a ^ b;
            ALU_SLL: y = a << b[4:0];
            ALU_SRL: y = a >> b[4:0];
            ALU_SRA: y = sa >>> b[4:0];
            ALU_SLT: y = (sa < sb) ? 32'd1 : 32'd0;
            ALU_SLTU:y = (a < b) ? 32'd1 : 32'd0;
            default: y = 32'b0;
        endcase
    end
endmodule


// ============================================================================
// IMMEDIATE GENERATOR
// ============================================================================
module immgen(
    input  [31:0] instr,
    output reg [31:0] imm_i,
    output reg [31:0] imm_s,
    output reg [31:0] imm_b,
    output reg [31:0] imm_u,
    output reg [31:0] imm_j
);
    always @(*) begin
        imm_i = {{20{instr[31]}}, instr[31:20]};
        imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        imm_u = {instr[31:12], 12'b0};
        imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    end
endmodule


// ============================================================================
// INSTRUCTION MEMORY (ROM)
// ============================================================================
module imem(
    input  [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem[0:63];
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1) mem[i] = 32'h00000013; // NOP

        mem[0]  = 32'h3e700093; // addi x1, x0, 999
        mem[1]  = 32'h30900113; // addi x2, x0, 777
        mem[2]  = 32'h07310113; // addi x2, x2, 115 -> x2 = 892
        mem[3]  = 32'h002081b3; // add  x3, x1, x2  -> x3 = 1891 (0x763)
        mem[4]  = 32'h40208233; // sub  x4, x1, x2  -> x4 = 107
        mem[5]  = 32'h0020c2b3; // xor  x5, x1, x2
        mem[6]  = 32'h0020e333; // or   x6, x1, x2
        mem[7]  = 32'h002073b3; // and  x7, x1, x2

        // AES Encryption and Decryption Instructions
        mem[8]  = 32'h00a7090b; // AES-ENC x18..x21 from PT(x10..x13), KEY(x14..x17)
        mem[9]  = 32'h03270b0b; // AES-DEC x22..x25 from CT(x18..x21), KEY(x14..x17)

        // Store to Data Memory
        mem[10] = 32'h00a02023; // sw x10, 0(x0)
        mem[11] = 32'h00b02223; // sw x11, 4(x0)
        mem[12] = 32'h00c02423; // sw x12, 8(x0)
        mem[13] = 32'h00d02623; // sw x13, 12(x0)

        mem[14] = 32'h00e02823; // sw x14, 16(x0)
        mem[15] = 32'h00f02a23; // sw x15, 20(x0)
        mem[16] = 32'h01002c23; // sw x16, 24(x0)
        mem[17] = 32'h01102e23; // sw x17, 28(x0)

        mem[18] = 32'h03202023; // sw x18, 32(x0)
        mem[19] = 32'h03302223; // sw x19, 36(x0)
        mem[20] = 32'h03402423; // sw x20, 40(x0)
        mem[21] = 32'h03502623; // sw x21, 44(x0)

        mem[22] = 32'h03602823; // sw x22, 48(x0)
        mem[23] = 32'h03702a23; // sw x23, 52(x0)
        mem[24] = 32'h03802c23; // sw x24, 56(x0)
        mem[25] = 32'h03902e23; // sw x25, 60(x0)

        mem[26] = 32'h00100073; // ebreak (Halt)
    end
    assign instr = mem[addr[7:2]];
endmodule


// ============================================================================
// DATA MEMORY (RAM)
// ============================================================================
module dmem(
    input         clk,
    input         mem_write,
    input         mem_read,
    input  [31:0] addr,
    input  [31:0] wd,
    output [31:0] rd
);
    reg [7:0] mem[0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) mem[i] = 8'b0;
    end
    wire [7:0] a = addr[7:0];
    assign rd = mem_read ? {mem[a+3], mem[a+2], mem[a+1], mem[a+0]} : 32'b0;

    always @(posedge clk) begin
        if (mem_write) begin
            mem[a+0] <= wd[7:0];
            mem[a+1] <= wd[15:8];
            mem[a+2] <= wd[23:16];
            mem[a+3] <= wd[31:24];
        end
    end
endmodule


// ============================================================================
// AES ACCELERATOR ENGINE & CRYPTO UNITS
// ============================================================================
module aes_core(
    input  [127:0] data_in,
    input  [127:0] key,
    input          enc_dec,
    output [127:0] data_out
);
    wire [127:0] sb, sr, mc, ark_e;
    wire [127:0] isb, isr, imc, ark_d;

    subbytes       U_SB  (.in(data_in), .out(sb));
    shiftrows      U_SR  (.in(sb),      .out(sr));
    mixcolumns     U_MC  (.in(sr),      .out(mc));
    assign ark_e = mc ^ key;

    assign ark_d = data_in ^ key;
    inv_mixcolumns U_IMC (.in(ark_d),    .out(imc));
    inv_shiftrows  U_ISR (.in(imc),      .out(isr));
    inv_subbytes   U_ISB (.in(isr),      .out(isb));

    assign data_out = (enc_dec == 1'b0) ? ark_e : isb;
endmodule

module subbytes(input [127:0] in, output [127:0] out);
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin: G_SB
            sbox SB(.in(in[8*k +: 8]), .out(out[8*k +: 8]));
        end
    endgenerate
endmodule

module inv_subbytes(input [127:0] in, output [127:0] out);
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin: G_ISB
            inv_sbox ISB(.in(in[8*k +: 8]), .out(out[8*k +: 8]));
        end
    endgenerate
endmodule

module shiftrows(input [127:0] in, output [127:0] out);
    assign out[8*0  +: 8] = in[8*0  +: 8];
    assign out[8*1  +: 8] = in[8*5  +: 8];
    assign out[8*2  +: 8] = in[8*10 +: 8];
    assign out[8*3  +: 8] = in[8*15 +: 8];
    assign out[8*4  +: 8] = in[8*4  +: 8];
    assign out[8*5  +: 8] = in[8*9  +: 8];
    assign out[8*6  +: 8] = in[8*14 +: 8];
    assign out[8*7  +: 8] = in[8*3  +: 8];
    assign out[8*8  +: 8] = in[8*8  +: 8];
    assign out[8*9  +: 8] = in[8*13 +: 8];
    assign out[8*10 +: 8] = in[8*2  +: 8];
    assign out[8*11 +: 8] = in[8*7  +: 8];
    assign out[8*12 +: 8] = in[8*12 +: 8];
    assign out[8*13 +: 8] = in[8*1  +: 8];
    assign out[8*14 +: 8] = in[8*6  +: 8];
    assign out[8*15 +: 8] = in[8*11 +: 8];
endmodule

module inv_shiftrows(input [127:0] in, output [127:0] out);
    assign out[8*0  +: 8] = in[8*0  +: 8];
    assign out[8*1  +: 8] = in[8*13 +: 8];
    assign out[8*2  +: 8] = in[8*10 +: 8];
    assign out[8*3  +: 8] = in[8*7  +: 8];
    assign out[8*4  +: 8] = in[8*4  +: 8];
    assign out[8*5  +: 8] = in[8*1  +: 8];
    assign out[8*6  +: 8] = in[8*14 +: 8];
    assign out[8*7  +: 8] = in[8*11 +: 8];
    assign out[8*8  +: 8] = in[8*8  +: 8];
    assign out[8*9  +: 8] = in[8*5  +: 8];
    assign out[8*10 +: 8] = in[8*2  +: 8];
    assign out[8*11 +: 8] = in[8*15 +: 8];
    assign out[8*12 +: 8] = in[8*12 +: 8];
    assign out[8*13 +: 8] = in[8*9  +: 8];
    assign out[8*14 +: 8] = in[8*6  +: 8];
    assign out[8*15 +: 8] = in[8*3  +: 8];
endmodule

module mixcolumns(input [127:0] in, output [127:0] out);
    function [7:0] xtime2(input [7:0] a);
        xtime2 = {a[6:0], 1'b0} ^ (8'h1b & {8{a[7]}});
    endfunction
    function [7:0] xtime3(input [7:0] a);
        xtime3 = xtime2(a) ^ a;
    endfunction

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin: G_MC
            wire [7:0] s0 = in[8*(c*4+0) +: 8];
            wire [7:0] s1 = in[8*(c*4+1) +: 8];
            wire [7:0] s2 = in[8*(c*4+2) +: 8];
            wire [7:0] s3 = in[8*(c*4+3) +: 8];

            assign out[8*(c*4+0) +: 8] = xtime2(s0) ^ xtime3(s1) ^ s2 ^ s3;
            assign out[8*(c*4+1) +: 8] = s0 ^ xtime2(s1) ^ xtime3(s2) ^ s3;
            assign out[8*(c*4+2) +: 8] = s0 ^ s1 ^ xtime2(s2) ^ xtime3(s3);
            assign out[8*(c*4+3) +: 8] = xtime3(s0) ^ s1 ^ s2 ^ xtime2(s3);
        end
    endgenerate
endmodule

module inv_mixcolumns(input [127:0] in, output [127:0] out);
    function [7:0] xtime(input [7:0] a);
        xtime = {a[6:0], 1'b0} ^ (8'h1b & {8{a[7]}});
    endfunction
    function [7:0] mul2(input [7:0] a);  mul2 = xtime(a); endfunction
    function [7:0] mul4(input [7:0] a);  mul4 = mul2(mul2(a)); endfunction
    function [7:0] mul8(input [7:0] a);  mul8 = mul2(mul4(a)); endfunction
    function [7:0] mul9(input [7:0] a);  mul9 = mul8(a) ^ a; endfunction
    function [7:0] mul11(input [7:0] a); mul11 = mul8(a) ^ mul2(a) ^ a; endfunction
    function [7:0] mul13(input [7:0] a); mul13 = mul8(a) ^ mul4(a) ^ a; endfunction
    function [7:0] mul14(input [7:0] a); mul14 = mul8(a) ^ mul4(a) ^ mul2(a); endfunction

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin: G_IMC
            wire [7:0] s0 = in[8*(c*4+0) +: 8];
            wire [7:0] s1 = in[8*(c*4+1) +: 8];
            wire [7:0] s2 = in[8*(c*4+2) +: 8];
            wire [7:0] s3 = in[8*(c*4+3) +: 8];

            assign out[8*(c*4+0) +: 8] = mul14(s0) ^ mul11(s1) ^ mul13(s2) ^ mul9(s3);
            assign out[8*(c*4+1) +: 8] = mul9(s0)  ^ mul14(s1) ^ mul11(s2) ^ mul13(s3);
            assign out[8*(c*4+2) +: 8] = mul13(s0) ^ mul9(s1)  ^ mul14(s2) ^ mul11(s3);
            assign out[8*(c*4+3) +: 8] = mul11(s0) ^ mul13(s1) ^ mul9(s2)  ^ mul14(s3);
        end
    endgenerate
endmodule

module sbox(input [7:0] in, output reg [7:0] out);
    always @(*) begin
        case (in)
            8'h00:out=8'h63;8'h01:out=8'h7c;8'h02:out=8'h77;8'h03:out=8'h7b;8'h04:out=8'hf2;8'h05:out=8'h6b;8'h06:out=8'h6f;8'h07:out=8'hc5;
            8'h08:out=8'h30;8'h09:out=8'h01;8'h0a:out=8'h67;8'h0b:out=8'h2b;8'h0c:out=8'hfe;8'h0d:out=8'hd7;8'h0e:out=8'hab;8'h0f:out=8'h76;
            8'h10:out=8'hca;8'h11:out=8'h82;8'h12:out=8'hc9;8'h13:out=8'h7d;8'h14:out=8'hfa;8'h15:out=8'h59;8'h16:out=8'h47;8'h17:out=8'hf0;
            8'h18:out=8'had;8'h19:out=8'hd4;8'h1a:out=8'ha2;8'h1b:out=8'haf;8'h1c:out=8'h9c;8'h1d:out=8'ha4;8'h1e:out=8'h72;8'h1f:out=8'hc0;
            8'h20:out=8'hb7;8'h21:out=8'hfd;8'h22:out=8'h93;8'h23:out=8'h26;8'h24:out=8'h36;8'h25:out=8'h3f;8'h26:out=8'hf7;8'h27:out=8'hcc;
            8'h28:out=8'h34;8'h29:out=8'ha5;8'h2a:out=8'he5;8'h2b:out=8'hf1;8'h2c:out=8'h71;8'h2d:out=8'hd8;8'h2e:out=8'h31;8'h2f:out=8'h15;
            8'h30:out=8'h04;8'h31:out=8'hc7;8'h32:out=8'h23;8'h33:out=8'hc3;8'h34:out=8'h18;8'h35:out=8'h96;8'h36:out=8'h05;8'h37:out=8'h9a;
            8'h38:out=8'h07;8'h39:out=8'h12;8'h3a:out=8'h80;8'h3b:out=8'he2;8'h3c:out=8'heb;8'h3d:out=8'h27;8'h3e:out=8'hb2;8'h3f:out=8'h75;
            8'h40:out=8'h09;8'h41:out=8'h83;8'h42:out=8'h2c;8'h43:out=8'h1a;8'h44:out=8'h1b;8'h45:out=8'h6e;8'h46:out=8'h5a;8'h47:out=8'ha0;
            8'h48:out=8'h52;8'h49:out=8'h3b;8'h4a:out=8'hd6;8'h4b:out=8'hb3;8'h4c:out=8'h29;8'h4d:out=8'he3;8'h4e:out=8'h2f;8'h4f:out=8'h84;
            8'h50:out=8'h53;8'h51:out=8'hd1;8'h52:out=8'h00;8'h53:out=8'hed;8'h54:out=8'h20;8'h55:out=8'hfc;8'h56:out=8'hb1;8'h57:out=8'h5b;
            8'h58:out=8'h6a;8'h59:out=8'hcb;8'h5a:out=8'hbe;8'h5b:out=8'h39;8'h5c:out=8'h4a;8'h5d:out=8'h4c;8'h5e:out=8'h58;8'h5f:out=8'hcf;
            8'h60:out=8'hd0;8'h61:out=8'hef;8'h62:out=8'haa;8'h63:out=8'hfb;8'h64:out=8'h43;8'h65:out=8'h4d;8'h66:out=8'h33;8'h67:out=8'h85;
            8'h68:out=8'h45;8'h69:out=8'hf9;8'h6a:out=8'h02;8'h6b:out=8'h7f;8'h6c:out=8'h50;8'h6d:out=8'h3c;8'h6e:out=8'h9f;8'h6f:out=8'ha8;
            8'h70:out=8'h51;8'h71:out=8'ha3;8'h72:out=8'h40;8'h73:out=8'h8f;8'h74:out=8'h92;8'h75:out=8'h9d;8'h76:out=8'h38;8'h77:out=8'hf5;
            8'h78:out=8'hbc;8'h79:out=8'hb6;8'h7a:out=8'hda;8'h7b:out=8'h21;8'h7c:out=8'h10;8'h7d:out=8'hff;8'h7e:out=8'hf3;8'h7f:out=8'hd2;
            8'h80:out=8'hcd;8'h81:out=8'h0c;8'h82:out=8'h13;8'h83:out=8'hec;8'h84:out=8'h5f;8'h85:out=8'h97;8'h44:out=8'h44;8'h87:out=8'h17;
            8'h88:out=8'hc4;8'h89:out=8'ha7;8'h8a:out=8'h7e;8'h8b:out=8'h3d;8'h8c:out=8'h64;8'h8d:out=8'h5d;8'h8e:out=8'h19;8'h8f:out=8'h73;
            8'h90:out=8'h60;8'h91:out=8'h81;8'h92:out=8'h4f;8'h93:out=8'hdc;8'h94:out=8'h22;8'h95:out=8'h2a;8'h96:out=8'h90;8'h97:out=8'h88;
            8'h98:out=8'h46;8'h99:out=8'hee;8'h9a:out=8'hb8;8'h9b:out=8'h14;8'h9c:out=8'hde;8'h9d:out=8'h5e;8'h9e:out=8'h0b;8'h9f:out=8'hdb;
            8'ha0:out=8'he0;8'ha1:out=8'h32;8'ha2:out=8'h3a;8'ha3:out=8'h0a;8'ha4:out=8'h49;8'ha5:out=8'h06;8'ha6:out=8'h24;8'ha7:out=8'h5c;
            8'ha8:out=8'hc2;8'ha9:out=8'hd3;8'haa:out=8'hac;8'hab:out=8'h62;8'hac:out=8'h91;8'had:out=8'h95;8'hae:out=8'he4;8'haf:out=8'h79;
            8'hb0:out=8'he7;8'hb1:out=8'hc8;8'hb2:out=8'h37;8'hb3:out=8'h6d;8'hb4:out=8'h8d;8'hb5:out=8'hd5;8'hb6:out=8'h4e;8'hb7:out=8'ha9;
            8'hb8:out=8'h6c;8'hb9:out=8'h56;8'hba:out=8'hf4;8'hbb:out=8'hea;8'hbc:out=8'h65;8'hbd:out=8'h7a;8'hbe:out=8'hae;8'hbf:out=8'h08;
            8'hc0:out=8'hba;8'hc1:out=8'h78;8'hc2:out=8'h25;8'hc3:out=8'h2e;8'hc4:out=8'h1c;8'hc5:out=8'ha6;8'hc6:out=8'hb4;8'hc7:out=8'hc6;
            8'hc8:out=8'he8;8'hc9:out=8'hdd;8'hca:out=8'h74;8'hcb:out=8'h1f;8'hcc:out=8'h4b;8'hcd:out=8'hbd;8'hce:out=8'h8b;8'hcf:out=8'h8a;
            8'hd0:out=8'h70;8'hd1:out=8'h3e;8'hd2:out=8'hb5;8'hd3:out=8'h66;8'hd4:out=8'h48;8'hd5:out=8'h03;8'hd6:out=8'hf6;8'hd7:out=8'h0e;
            8'hd8:out=8'h61;8'hd9:out=8'h35;8'hda:out=8'h57;8'hdb:out=8'hb9;8'hdc:out=8'h86;8'hdd:out=8'hc1;8'hde:out=8'h1d;8'hdf:out=8'h9e;
            8'he0:out=8'he1;8'he1:out=8'hf8;8'he2:out=8'h98;8'he3:out=8'h11;8'he4:out=8'h69;8'he5:out=8'hd9;8'he6:out=8'h8e;8'he7:out=8'h94;
            8'he8:out=8'h9b;8'he9:out=8'h1e;8'hea:out=8'h87;8'heb:out=8'he9;8'hec:out=8'hce;8'hed:out=8'h55;8'hee:out=8'h28;8'hef:out=8'hdf;
            8'hf0:out=8'h8c;8'hf1:out=8'ha1;8'hf2:out=8'h89;8'hf3:out=8'h0d;8'hf4:out=8'hbf;8'hf5:out=8'he6;8'hf6:out=8'h42;8'hf7:out=8'h68;
            8'hf8:out=8'h41;8'hf9:out=8'h99;8'hfa:out=8'h2d;8'hfb:out=8'h0f;8'hfc:out=8'hb0;8'hfd:out=8'h54;8'hfe:out=8'hbb;8'hff:out=8'h16;
            default: out=8'h00;
        endcase
    end
endmodule

module inv_sbox(input [7:0] in, output reg [7:0] out);
    always @(*) begin
        case (in)
            8'h00:out=8'h52;8'h01:out=8'h09;8'h02:out=8'h6a;8'h03:out=8'hd5;8'h04:out=8'h30;8'h05:out=8'h36;8'h06:out=8'ha5;8'h07:out=8'h38;
            8'h08:out=8'hbf;8'h09:out=8'h40;8'h0a:out=8'ha3;8'h0b:out=8'h9e;8'h0c:out=8'h81;8'h0d:out=8'hf3;8'h0e:out=8'hd7;8'h0f:out=8'hfb;
            8'h10:out=8'h7c;8'h11:out=8'he3;8'h12:out=8'h39;8'h13:out=8'h82;8'h14:out=8'h9b;8'h15:out=8'h2f;8'h16:out=8'hff;8'h17:out=8'h87;
            8'h18:out=8'h34;8'h19:out=8'h8e;8'h1a:out=8'h43;8'h1b:out=8'h44;8'h1c:out=8'hc4;8'h1d:out=8'hde;8'h1e:out=8'he9;8'h1f:out=8'hcb;
            8'h20:out=8'h54;8'h21:out=8'h7b;8'h22:out=8'h94;8'h23:out=8'h32;8'h24:out=8'ha6;8'h25:out=8'hc2;8'h26:out=8'h23;8'h27:out=8'h3d;
            8'h28:out=8'hee;8'h29:out=8'h4c;8'h2a:out=8'h95;8'h2b:out=8'h0b;8'h2c:out=8'h42;8'h2d:out=8'hfa;8'h2e:out=8'hc3;8'h2f:out=8'h4e;
            8'h30:out=8'h08;8'h31:out=8'h2e;8'h32:out=8'ha1;8'h33:out=8'h66;8'h34:out=8'h28;8'h35:out=8'hd9;8'h36:out=8'h24;8'h37:out=8'hb2;
            8'h38:out=8'h76;8'h39:out=8'h5b;8'h3a:out=8'ha2;8'h3b:out=8'h49;8'h3c:out=8'h6d;8'h3d:out=8'h8b;8'h3e:out=8'hd1;8'h3f:out=8'h25;
            8'h40:out=8'h72;8'h41:out=8'hf8;8'h42:out=8'hf6;8'h43:out=8'h64;8'h44:out=8'h86;8'h45:out=8'h68;8'h46:out=8'h98;8'h47:out=8'h16;
            8'h48:out=8'hd4;8'h49:out=8'ha4;8'h4a:out=8'h5c;8'h4b:out=8'hcc;8'h4c:out=8'h5d;8'h4d:out=8'h65;8'h4e:out=8'hb6;8'h4f:out=8'h92;
            8'h50:out=8'h6c;8'h51:out=8'h70;8'h52:out=8'h48;8'h53:out=8'h50;8'h54:out=8'hfd;8'h55:out=8'hed;8'h56:out=8'hb9;8'h57:out=8'hda;
            8'h58:out=8'h5e;8'h59:out=8'h15;8'h5a:out=8'h46;8'h5b:out=8'h57;8'h5c:out=8'ha7;8'h5d:out=8'h8d;8'h5e:out=8'h9d;8'h5f:out=8'h84;
            8'h60:out=8'h90;8'h61:out=8'hd8;8'h62:out=8'hab;8'h63:out=8'h00;8'h64:out=8'h8c;8'h65:out=8'hbc;8'h66:out=8'hd3;8'h67:out=8'h0a;
            8'h68:out=8'hf7;8'h69:out=8'he4;8'h6a:out=8'h58;8'h6b:out=8'h05;8'h6c:out=8'hb8;8'h6d:out=8'hb3;8'h6e:out=8'h45;8'h6f:out=8'h06;
            8'h70:out=8'hd0;8'h71:out=8'h2c;8'h72:out=8'h1e;8'h73:out=8'h8f;8'h74:out=8'hca;8'h75:out=8'h3f;8'h76:out=8'h0f;8'h77:out=8'h02;
            8'h78:out=8'hc1;8'h79:out=8'haf;8'h7a:out=8'hbd;8'h7b:out=8'h03;8'h7c:out=8'h01;8'h7d:out=8'h13;8'h7e:out=8'h8a;8'h7f:out=8'h6b;
            8'h80:out=8'h3a;8'h81:out=8'h91;8'h82:out=8'h11;8'h83:out=8'h41;8'h84:out=8'h4f;8'h85:out=8'h67;8'h86:out=8'hdc;8'h87:out=8'hea;
            8'h88:out=8'h97;8'h89:out=8'hf2;8'h8a:out=8'hcf;8'h8b:out=8'hce;8'h8c:out=8'hf0;8'h8d:out=8'hb4;8'h8e:out=8'he6;8'h8f:out=8'h73;
            8'h90:out=8'h96;8'h91:out=8'hac;8'h92:out=8'h74;8'h93:out=8'h22;8'h94:out=8'he7;8'h95:out=8'had;8'h96:out=8'h35;8'h97:out=8'h85;
            8'h98:out=8'he2;8'h99:out=8'hf9;8'h9a:out=8'h37;8'h9b:out=8'he8;8'h9c:out=8'h1c;8'h9d:out=8'h75;8'h9e:out=8'hdf;8'h9f:out=8'h6e;
            8'ha0:out=8'h47;8'ha1:out=8'hf1;8'ha2:out=8'h1a;8'ha3:out=8'h71;8'ha4:out=8'h1d;8'ha5:out=8'h29;8'ha6:out=8'hc5;8'ha7:out=8'h89;
            8'ha8:out=8'h6f;8'ha9:out=8'hb7;8'haa:out=8'h62;8'hab:out=8'h0e;8'hac:out=8'haa;8'had:out=8'h18;8'hae:out=8'hbe;8'haf:out=8'h1b;
            8'hb0:out=8'he7;8'hb1:out=8'hc8;8'hb2:out=8'h37;8'hb3:out=8'h6d;8'hb4:out=8'h8d;8'hb5:out=8'hd5;8'hb6:out=8'h4e;8'hb7:out=8'ha9;
            8'hb8:out=8'h6c;8'hb9:out=8'h56;8'hba:out=8'hf4;8'hbb:out=8'hea;8'hbc:out=8'h65;8'hbd:out=8'h7a;8'hbe:out=8'hae;8'hbf:out=8'h08;
            8'hc0:out=8'hba;8'hc1:out=8'h78;8'hc2:out=8'h25;8'hc3:out=8'h2e;8'hc4:out=8'h1c;8'hc5:out=8'ha6;8'hc6:out=8'hb4;8'hc7:out=8'hc6;
            8'hc8:out=8'he8;8'hc9:out=8'hdd;8'hca:out=8'h74;8'hcb:out=8'h1f;8'hcc:out=8'h4b;8'hcd:out=8'hbd;8'hce:out=8'h8b;8'hcf:out=8'h8a;
            8'hd0:out=8'h70;8'hd1:out=8'h3e;8'hd2:out=8'hb5;8'hd3:out=8'h66;8'hd4:out=8'h48;8'hd5:out=8'h03;8'hd6:out=8'hf6;8'hd7:out=8'h0e;
            8'hd8:out=8'h61;8'hd9:out=8'h35;8'hda:out=8'h57;8'hdb:out=8'hb9;8'hdc:out=8'h86;8'hdd:out=8'hc1;8'hde:out=8'h1d;8'hdf:out=8'h9e;
            8'he0:out=8'ha0;8'he1:out=8'he0;8'he2:out=8'h3b;8'he3:out=8'h4d;8'he4:out=8'hae;8'he5:out=8'h2a;8'he6:out=8'hf5;8'he7:out=8'hb0;
            8'he8:out=8'hc8;8'he9:out=8'heb;8'hea:out=8'hbb;8'heb:out=8'h3c;8'hec:out=8'h83;8'hed:out=8'h53;8'hee:out=8'h99;8'hef:out=8'h61;
            8'hf0:out=8'h17;8'hf1:out=8'h2b;8'hf2:out=8'h04;8'hf3:out=8'h7e;8'hf4:out=8'hba;8'hf5:out=8'h77;8'hf6:out=8'hd6;8'hf7:out=8'h26;
            8'hf8:out=8'he1;8'hf9:out=8'h69;8'hfa:out=8'h14;8'hfb:out=8'h63;8'hfc:out=8'h55;8'hfd:out=8'h21;8'hfe:out=8'h0c;8'hff:out=8'h7d;
            default: out=8'h00;
        endcase
    end
endmodule