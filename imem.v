// imem.v — Clean version
module imem(
    input  [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem[0:255];
    integer i;

    initial begin
        // Init all to NOP
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h00000013;

        // ---------------- ALU TEST ----------------
        //mem[0] = 32'h09600093;   // addi x1,x0,150
        //mem[1] = 32'h15e00113;   // addi x2,x0,350 
        mem[0] = 32'h3e700093;   // addi x1,x0,999
        mem[1] = 32'h30900113;   // addi x2,x0,777
        //mem[0] = 32'h11c00093; // addi x1,x0,284
        //mem[1] = 32'h2bc00113; // addi x2,x0,700
        mem[2] = 32'h07310113; // addi x2,x2,0x73
        mem[3] = 32'h002081b3; // add x3,x1,x2
        mem[4] = 32'h40208233; // sub x4,x1,x2
        mem[5] = 32'h0020c2b3; // xor x5,x1,x2
        mem[6] = 32'h0020e333; // or  x6,x1,x2
        mem[7] = 32'h002073b3; // and x7,x1,x2

        // ---------------- AES ENCRYPT & DECRYPT ----------------
        // Boot preload (cpu.v) finishes in 8 cycles → AES must begin here
        mem[8]  = 32'h00a7090b; // AES-ENC x18,x14,x10
        mem[9]  = 32'h03270b0b; // AES-DEC x22,x14,x18

        // ---------------- STORE PT to DMEM ----------------
        mem[10] = 32'h00a02023;
        mem[11] = 32'h00b02223;
        mem[12] = 32'h00c02423;
        mem[13] = 32'h00d02623;

        // ---------------- STORE KEY to DMEM ----------------
        mem[14] = 32'h00e02823;
        mem[15] = 32'h00f02a23;
        mem[16] = 32'h01002c23;
        mem[17] = 32'h01102e23;

        // ---------------- STORE CT to DMEM ----------------
        mem[18] = 32'h03202023;
        mem[19] = 32'h03302223;
        mem[20] = 32'h03402423;
        mem[21] = 32'h03502623;

        // ---------------- STORE DEC to DMEM ----------------
        mem[22] = 32'h03602823;
        mem[23] = 32'h03702a23;
        mem[24] = 32'h03802c23;
        mem[25] = 32'h03902e23;

        // ---------------- HALT ----------------
        mem[26] = 32'h00100073; // ebreak
    end

    assign instr = mem[addr[9:2]];
endmodule
