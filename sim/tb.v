`timescale 1ns / 1ps

module tb;
    reg clk = 0;
    reg [15:0] sw = 16'd0;
    reg [4:0]  pb = 5'b00001; // pb[0]=1 causes reset_n=0 initially

    wire [15:0] led;
    wire [3:0]  digit;
    wire [7:0]  Seven_Seg;

    // Instantiate Top Module
    top_edge_artix7 U_TOP (
        .clk(clk),
        .sw(sw),
        .pb(pb),
        .led(led),
        .digit(digit),
        .Seven_Seg(Seven_Seg)
    );

    // 50 MHz clock generation (20ns period)
    always #10 clk = ~clk;

    integer i, ok, nonzero, a;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);

        // Release reset after 40 ns
        #40 pb[0] = 1'b0;

        // Wait until CPU executes EBREAK instruction (led[0] becomes 1)
        wait (led[0] == 1'b1);
        #20;

        $display("\n==================================================");
        $display("          RISC-V + AES HARDWARE EXECUTION");
        $display("==================================================\n");

        // ALU Registers Verification
        $display("--- ALU Results ---");
        $display("x1  (ADDI) = 0x%08x", U_TOP.U_CPU.u_rf.regs[1]);
        $display("x2  (ADDI) = 0x%08x", U_TOP.U_CPU.u_rf.regs[2]);
        $display("x3  (ADD)  = 0x%08x (Expected: 0x00000763)", U_TOP.U_CPU.u_rf.regs[3]);
        $display("x4  (SUB)  = 0x%08x", U_TOP.U_CPU.u_rf.regs[4]);
        $display("x5  (XOR)  = 0x%08x", U_TOP.U_CPU.u_rf.regs[5]);
        $display("x6  (OR)   = 0x%08x", U_TOP.U_CPU.u_rf.regs[6]);
        $display("x7  (AND)  = 0x%08x", U_TOP.U_CPU.u_rf.regs[7]);

        // AES Plaintext
        $display("\n--- AES Plaintext Registers (x10-x13) ---");
        for (i = 10; i <= 13; i = i + 1)
            $display("x%02d (PT)  = 0x%08x", i, U_TOP.U_CPU.u_rf.regs[i]);

        // AES Key
        $display("\n--- AES Key Registers (x14-x17) ---");
        for (i = 14; i <= 17; i = i + 1)
            $display("x%02d (KEY) = 0x%08x", i, U_TOP.U_CPU.u_rf.regs[i]);

        // AES Ciphertext
        $display("\n--- AES Ciphertext Registers (x18-x21) ---");
        for (i = 18; i <= 21; i = i + 1)
            $display("x%02d (CT)  = 0x%08x", i, U_TOP.U_CPU.u_rf.regs[i]);

        // AES Decrypted Text
        $display("\n--- AES Decrypted Registers (x22-x25) ---");
        for (i = 22; i <= 25; i = i + 1)
            $display("x%02d (DEC) = 0x%08x", i, U_TOP.U_CPU.u_rf.regs[i]);

        // Data Memory Dump
        $display("\n--- Data Memory Layout (DMEM) ---");
        $display("Addr 0x00..0x0F : Plaintext");
        $display("Addr 0x10..0x1F : Key");
        $display("Addr 0x20..0x2F : Ciphertext");
        $display("Addr 0x30..0x3F : Decrypted Plaintext\n");

        for (i = 0; i < 64; i = i + 4) begin
            $display("0x%02h : %02h %02h %02h %02h", i,
                U_TOP.U_DMEM.mem[i],
                U_TOP.U_DMEM.mem[i+1],
                U_TOP.U_DMEM.mem[i+2],
                U_TOP.U_DMEM.mem[i+3]);
        end

        // Correctness Check: compare Plaintext (0x00..0x0F) with Decrypted Text (0x30..0x3F)
        ok = 1; nonzero = 0;
        for (a = 0; a < 16; a = a + 1) begin
            if (U_TOP.U_DMEM.mem[a] !== U_TOP.U_DMEM.mem[48 + a])
                ok = 0;
            if (U_TOP.U_DMEM.mem[a] !== 8'h00)
                nonzero = 1;
        end

        if (ok && nonzero) begin
            $display("\n[RESULT] >>> AES CHECK PASS: Decrypted text matches original Plaintext! <<<\n");
        end else begin
            $display("\n[RESULT] >>> AES CHECK FAIL! <<<\n");
        end

        #50 $finish;
    end
endmodule