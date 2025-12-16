`timescale 1ns/1ps

module tb;
    reg clk = 0;
    reg reset_n = 0;

    wire halted;
    wire [31:0] imem_addr, imem_instr, dmem_addr, dmem_wdata, dmem_rdata;
    wire dmem_we, dmem_re;

    cpu U_CPU(
        .clk(clk), .reset_n(reset_n),
        .imem_addr(imem_addr), .imem_instr(imem_instr),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata), .dmem_we(dmem_we), .dmem_re(dmem_re),
        .halted(halted)
    );

    imem U_IMEM(.addr(imem_addr), .instr(imem_instr));

    // ⭐ FIX: match DMEM port names
    dmem U_DMEM(
        .clk(clk),
        .mem_write(dmem_we),
        .mem_read(dmem_re),
        .addr(dmem_addr),
        .wd(dmem_wdata),
        .rd(dmem_rdata)
    );

    always #5 clk = ~clk;

    integer i, ok, nonzero, a;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0,tb);

        #20 reset_n = 1;
        wait (halted);
        #5;

        $display("\n================== CPU HALTED ==================\n");

        // ---- ALU Registers ----
        $display("--- ALU Demonstration Registers ---");
        $display("x1  (ADDI)           = %h", U_CPU.u_rf.regs[1]);
        $display("x2  (ADDI)           = %h", U_CPU.u_rf.regs[2]);
        $display("x3  (ADD)            = %h", U_CPU.u_rf.regs[3]);
        $display("x4  (XOR)            = %h", U_CPU.u_rf.regs[4]);
        $display("x5  (OR)             = %h", U_CPU.u_rf.regs[5]);
        $display("x6  (SLLI)           = %h", U_CPU.u_rf.regs[6]);
        $display("x7  (SRLI)           = %h", U_CPU.u_rf.regs[7]);
        $display("x8  (ANDI)           = %h", U_CPU.u_rf.regs[8]);

        // ---- AES Registers ----
        $display("\n--- AES Plaintext Registers (x10-x13) ---");
        for (i=10;i<=13;i=i+1) $display("x%0d (PT)  = %h", i, U_CPU.u_rf.regs[i]);

        $display("\n--- AES Key Registers (x14-x17) ---");
        for (i=14;i<=17;i=i+1) $display("x%0d (KEY) = %h", i, U_CPU.u_rf.regs[i]);

        $display("\n--- AES Encrypted (Ciphertext) x18-x21 ---");
        for (i=18;i<=21;i=i+1) $display("x%0d (CT)  = %h", i, U_CPU.u_rf.regs[i]);

        $display("\n--- AES Decrypted (Recovered PT) x22-x25 ---");
        for (i=22;i<=25;i=i+1) $display("x%0d (DEC) = %h", i, U_CPU.u_rf.regs[i]);

        // ---- DMEM Dump ----
        $display("\n--- Data Memory Layout ---");
        $display("0x00-0x0F : PLAINTEXT");
        $display("0x10-0x1F : KEY");
        $display("0x20-0x2F : CIPHERTEXT");
        $display("0x30-0x3F : DECRYPTED PLAINTEXT\n");

        for (i=0;i<64;i=i+4)
            $display("0x%02h : %02h %02h %02h %02h", i,
                U_DMEM.mem[i], U_DMEM.mem[i+1], U_DMEM.mem[i+2], U_DMEM.mem[i+3]);

        // PASS test
        ok = 1; nonzero = 0;
        for (a=0; a<16; a=a+1) begin
            if (U_DMEM.mem[a] !== U_DMEM.mem[48+a]) ok = 0;
            if (U_DMEM.mem[a] !== 8'h00) nonzero = 1;
        end

        if (ok && nonzero)
            $display("\nAES CHECK PASS - decrypted matches plaintext\n");
        else
            $display("\nAES CHECK FAIL\n");

        #10 $finish;
    end
endmodule
