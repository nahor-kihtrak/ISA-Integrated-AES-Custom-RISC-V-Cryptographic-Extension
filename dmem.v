
// dmem.v - Simple byte-addressed memory (1KB)
module dmem(
    input         clk,
    input         mem_write,
    input         mem_read,
    input  [31:0] addr,
    input  [31:0] wd,
    output [31:0] rd
);
    reg [7:0] mem[0:1023];
    integer i;
    initial begin
        for (i=0;i<1024;i=i+1) mem[i]=8'b0;
    end
    wire [31:0] a = {20'b0, addr[11:2], 2'b00};
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
