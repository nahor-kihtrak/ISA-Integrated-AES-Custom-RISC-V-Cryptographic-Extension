// cpu.v - Single-cycle RV32I + AES single-round (multi-cycle writeback) + reset preload
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
    output        halted
);
    reg [31:0] pc;
    assign imem_addr = pc;

    // Decode fields
    wire [31:0] instr = imem_instr;
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1_i  = instr[19:15];
    wire [4:0]  rs2_i  = instr[24:20];

    // Control
    wire reg_write, mem_write, mem_read, branch, jump_jal, jump_jalr;
    wire [3:0] alu_op;
    wire alu_src_imm, mem_to_reg, is_ebreak, is_aes, aes_dec;
    control u_ctl(.instr(instr), .reg_write(reg_write), .mem_write(mem_write), .mem_read(mem_read),
                  .branch(branch), .jump_jal(jump_jal), .jump_jalr(jump_jalr),
                  .alu_op(alu_op), .alu_src_imm(alu_src_imm), .mem_to_reg(mem_to_reg),
                  .is_ebreak(is_ebreak), .is_aes(is_aes), .aes_dec(aes_dec));

    // Immediates
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    immgen u_imm(.instr(instr), .imm_i(imm_i), .imm_s(imm_s), .imm_b(imm_b), .imm_u(imm_u), .imm_j(imm_j));

    // Regfile and mux for AES gather
    wire [4:0] rs1_mux = (aes_busy && (aes_state<4)) ? (aes_rs1_base + aes_state[1:0]) : rs1_i;
    wire [4:0] rs2_mux = (aes_busy && (aes_state<4)) ? (aes_rs2_base + aes_state[1:0]) : rs2_i;
    wire [31:0] rs1_val, rs2_val;
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;
    regfile u_rf(.clk(clk), .we(rf_we), .rs1(rs1_mux), .rs2(rs2_mux), .rd(rf_waddr), .wd(rf_wdata), .rd1(rs1_val), .rd2(rs2_val));

    // ALU
    wire [31:0] imm_for_alu = (opcode==7'b0100011) ? imm_s : (opcode==7'b0110111) ? imm_u : imm_i;
    wire [31:0] alu_b = alu_src_imm ? imm_for_alu : rs2_val;
    wire [31:0] alu_a = (opcode==7'b0010111) ? pc : rs1_val;
    wire [31:0] alu_y;
    alu u_alu(.alu_op(alu_op), .a(alu_a), .b(alu_b), .y(alu_y));

    // DMEM
    assign dmem_addr  = alu_y;
    assign dmem_wdata = rs2_val;
    assign dmem_we    = (!aes_busy && !boot_busy) ? mem_write : 1'b0;
    assign dmem_re    = (!aes_busy && !boot_busy) ? mem_read  : 1'b0;

    // AES
    reg        aes_busy;
    reg [3:0]  aes_state;
    reg [4:0]  aes_rs1_base, aes_rs2_base, aes_rd_base;
    reg        aes_mode_dec;
    reg [127:0] key_buf, data_buf, aes_res;
    wire [127:0] aes_comb_out;
    aes_core u_aes(.data_in(data_buf), .key(key_buf), .enc_dec(aes_mode_dec), .data_out(aes_comb_out));

    // Branch decision (only beq/bne demo)
    wire take_beq = (funct3==3'b000) && (rs1_val == rs2_val);
    wire take_bne = (funct3==3'b001) && (rs1_val != rs2_val);
    wire do_branch = branch && (take_beq || take_bne);

    // PC next (stall when busy)
    wire [31:0] pc_next_norm = do_branch ? (pc + imm_b) :
                               jump_jal  ? (pc + imm_j) :
                               jump_jalr ? ((rs1_val + imm_i) & ~32'd1) :
                               (pc + 32'd4);
    wire [31:0] pc_next = (aes_busy || boot_busy) ? pc : pc_next_norm;

    // Halt
    reg halt_r; assign halted = halt_r;

    // Boot preload FSM (writes the exact PT/KEY into x10-x17)
    reg        boot_busy;
    reg [3:0]  boot_idx;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pc <= 32'b0; halt_r <= 1'b0;
            aes_busy<=0; aes_state<=0; key_buf<=0; data_buf<=0; aes_res<=0;
            rf_we<=0; rf_waddr<=0; rf_wdata<=0;
            boot_busy<=1; boot_idx<=0;
        end else begin
            rf_we <= 0;

            // EBREAK
            if (is_ebreak && !aes_busy && !boot_busy) halt_r <= 1'b1;

            // Boot preload registers x10..x17
            if (boot_busy) begin
                rf_we <= 1'b1;
                case (boot_idx)
                    //0: begin rf_waddr<=5'd10; rf_wdata<=32'hddccbbaa; end // x10
                    //1: begin rf_waddr<=5'd11; rf_wdata<=32'h44332211; end // x11
                    //2: begin rf_waddr<=5'd12; rf_wdata<=32'h88776655; end // x12
                    //3: begin rf_waddr<=5'd13; rf_wdata<=32'hccbbaa99; end // x13
                    //4: begin rf_waddr<=5'd14; rf_wdata<=32'h3c2d1e0f; end // x14
                    //5: begin rf_waddr<=5'd15; rf_wdata<=32'h78695a4b; end // x15
                    //6: begin rf_waddr<=5'd16; rf_wdata<=32'hb4a59687; end // x16
                    //7: begin rf_waddr<=5'd17; rf_wdata<=32'hf0e1d2c3; end // x17
                    //0: begin rf_waddr<=5'd10; rf_wdata<=32'hd4c3b2a1; end

0: begin rf_waddr<=5'd10; rf_wdata<=32'hd4c3b2a1; end
1: begin rf_waddr<=5'd11; rf_wdata<=32'h1807f6e5; end
2: begin rf_waddr<=5'd12; rf_wdata<=32'h5c4b3a29; end
3: begin rf_waddr<=5'd13; rf_wdata<=32'h90f8e7d6; end
4: begin rf_waddr<=5'd14; rf_wdata<=32'hcaa0470f; end
5: begin rf_waddr<=5'd15; rf_wdata<=32'h2e7f5dcc; end
6: begin rf_waddr<=5'd16; rf_wdata<=32'h28093d1b; end
7: begin rf_waddr<=5'd17; rf_wdata<=32'hd8c6a1f4; end

//0: begin rf_waddr<=5'd10; rf_wdata<=32'h33221100; end // 
//: begin rf_waddr<=5'd11; rf_wdata<=32'h77665544; end // 
//2: begin rf_waddr<=5'd12; rf_wdata<=32'hbbaa9988; end // 
//3: begin rf_waddr<=5'd13; rf_wdata<=32'hffeeddcc; end // 
//4: begin rf_waddr<=5'd14; rf_wdata<=32'h03020100; end // 
//5: begin rf_waddr<=5'd15; rf_wdata<=32'h07060504; end // 
//6: begin rf_waddr<=5'd16; rf_wdata<=32'h0b0a0908; end // 
//7: begin rf_waddr<=5'd17; rf_wdata<=32'h0f0e0d0c; end // 

                    default: rf_we<=1'b0;
                endcase
                if (boot_idx==7) boot_busy<=0; else boot_idx<=boot_idx+1;
                pc <= pc; // stall while preload runs
            end
            // AES FSM
            else if (aes_busy) begin
                case (aes_state)
                    4'd0: begin key_buf[31:0]   <= rs1_val; data_buf[31:0]   <= rs2_val; aes_state<=4'd1; end
                    4'd1: begin key_buf[63:32]  <= rs1_val; data_buf[63:32]  <= rs2_val; aes_state<=4'd2; end
                    4'd2: begin key_buf[95:64]  <= rs1_val; data_buf[95:64]  <= rs2_val; aes_state<=4'd3; end
                    4'd3: begin key_buf[127:96] <= rs1_val; data_buf[127:96] <= rs2_val; aes_state<=4'd4; end
                    4'd4: begin aes_res <= aes_comb_out; aes_state<=4'd8; end
                    4'd8: begin rf_we<=1'b1; rf_waddr<=aes_rd_base+0; rf_wdata<=aes_res[31:0];   aes_state<=4'd9;  end
                    4'd9: begin rf_we<=1'b1; rf_waddr<=aes_rd_base+1; rf_wdata<=aes_res[63:32];  aes_state<=4'd10; end
                   4'd10: begin rf_we<=1'b1; rf_waddr<=aes_rd_base+2; rf_wdata<=aes_res[95:64];  aes_state<=4'd11; end
                   4'd11: begin rf_we<=1'b1; rf_waddr<=aes_rd_base+3; rf_wdata<=aes_res[127:96]; aes_state<=4'd15; end
                 default: begin aes_busy<=1'b0; aes_state<=4'd0; end
                endcase
                pc <= pc; // stall
            end
            // Normal path
            else begin
                pc <= pc_next_norm;

                if (reg_write) begin
                    rf_we<=1'b1; rf_waddr<=rd;
                    if (mem_to_reg) rf_wdata<=dmem_rdata;
                    else if (opcode==7'b0110111) rf_wdata<=imm_u;  // LUI
                    else if (jump_jal || jump_jalr) rf_wdata<=pc + 32'd4;
                    else rf_wdata<=alu_y;
                end

                if (is_aes) begin
                    aes_busy<=1'b1; aes_state<=4'd0;
                    aes_rs1_base<=rs1_i; aes_rs2_base<=rs2_i; aes_rd_base<=rd;
                    aes_mode_dec<=aes_dec;
                end
            end
        end
    end
endmodule
