
// regfile.v - 32 x 32-bit register file, 2 read, 1 write. x0 hardwired to 0.
module regfile(
    input             clk,
    input             we,
    input      [4:0]  rs1,
    input      [4:0]  rs2,
    input      [4:0]  rd,
    input      [31:0] wd,
    output     [31:0] rd1,
    output     [31:0] rd2
);
    reg [31:0] regs[0:31];
    integer j;
    initial begin
        for (j=0;j<32;j=j+1) regs[j] = 32'b0;
    end

    assign rd1 = (rs1==5'd0) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2==5'd0) ? 32'b0 : regs[rs2];

    always @(posedge clk) begin
        if (we && rd!=5'd0) regs[rd] <= wd;
    end

    // synthesis translate_off
    task dump_all_named;
        begin
            $display("x0  (zero) = 0x%08x", regs[0]);
            $display("x1  (ra)   = 0x%08x", regs[1]);
            $display("x2  (sp)   = 0x%08x", regs[2]);
            $display("x3  (gp)   = 0x%08x", regs[3]);
            $display("x4  (tp)   = 0x%08x", regs[4]);
            $display("x5  (t0)   = 0x%08x", regs[5]);
            $display("x6  (t1)   = 0x%08x", regs[6]);
            $display("x7  (t2)   = 0x%08x", regs[7]);
            $display("x8  (s0)   = 0x%08x", regs[8]);
            $display("x9  (s1)   = 0x%08x", regs[9]);
            $display("x10 (a0)   = 0x%08x", regs[10]);
            $display("x11 (a1)   = 0x%08x", regs[11]);
            $display("x12 (a2)   = 0x%08x", regs[12]);
            $display("x13 (a3)   = 0x%08x", regs[13]);
            $display("x14 (a4)   = 0x%08x", regs[14]);
            $display("x15 (a5)   = 0x%08x", regs[15]);
            $display("x16 (a6)   = 0x%08x", regs[16]);
            $display("x17 (a7)   = 0x%08x", regs[17]);
            $display("x18 (s2)   = 0x%08x", regs[18]);
            $display("x19 (s3)   = 0x%08x", regs[19]);
            $display("x20 (s4)   = 0x%08x", regs[20]);
            $display("x21 (s5)   = 0x%08x", regs[21]);
            $display("x22 (s6)   = 0x%08x", regs[22]);
            $display("x23 (s7)   = 0x%08x", regs[23]);
            $display("x24 (s8)   = 0x%08x", regs[24]);
            $display("x25 (s9)   = 0x%08x", regs[25]);
            $display("x26 (s10)  = 0x%08x", regs[26]);
            $display("x27 (s11)  = 0x%08x", regs[27]);
            $display("x28 (t3)   = 0x%08x", regs[28]);
            $display("x29 (t4)   = 0x%08x", regs[29]);
            $display("x30 (t5)   = 0x%08x", regs[30]);
            $display("x31 (t6)   = 0x%08x", regs[31]);
        end
    endtask
    // synthesis translate_on
endmodule
