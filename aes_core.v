
// aes_core.v - AES single round (encrypt/decrypt) combinational
module aes_core(input [127:0] data_in, input [127:0] key, input enc_dec, output [127:0] data_out);
    wire [127:0] sb, sr, mc, ark_e;
    wire [127:0] ib, isr, imc, ark_d;

    subbytes    U_SB(.in(data_in), .out(sb));
    shiftrows   U_SR(.in(sb),      .out(sr));
    mixcolumns  U_MC(.in(sr),      .out(mc));
    assign ark_e = mc ^ key;

    assign ark_d = data_in ^ key;
    inv_mixcolumns U_IMC(.in(ark_d), .out(imc));
    inv_shiftrows  U_ISR(.in(imc),   .out(isr));
    inv_subbytes   U_ISB(.in(isr),   .out(ib));

    assign data_out = (enc_dec==1'b0) ? ark_e : ib;
endmodule

module subbytes(input [127:0] in, output [127:0] out);
    wire [7:0] i[0:15]; wire [7:0] o[0:15];
    genvar k;
    generate for (k=0;k<16;k=k+1) begin: G
        assign i[k] = in[8*k +: 8];
        sbox SB(.in(i[k]), .out(o[k]));
        assign out[8*k +: 8] = o[k];
    end endgenerate
endmodule

module inv_subbytes(input [127:0] in, output [127:0] out);
    wire [7:0] i[0:15]; wire [7:0] o[0:15];
    genvar k;
    generate for (k=0;k<16;k=k+1) begin: G
        assign i[k] = in[8*k +: 8];
        inv_sbox SB(.in(i[k]), .out(o[k]));
        assign out[8*k +: 8] = o[k];
    end endgenerate
endmodule

module shiftrows(input [127:0] in, output [127:0] out);
    // simple byte-reverse per 4
    assign out = { in[127:120], in[119:112], in[111:104], in[103:96],
                   in[95:88],   in[87:80],   in[79:72],   in[71:64],
                   in[63:56],   in[55:48],   in[47:40],   in[39:32],
                   in[31:24],   in[23:16],   in[15:8],    in[7:0] };
endmodule

module inv_shiftrows(input [127:0] in, output [127:0] out);
    assign out = { in[127:120], in[119:112], in[111:104], in[103:96],
                   in[95:88],   in[87:80],   in[79:72],   in[71:64],
                   in[63:56],   in[55:48],   in[47:40],   in[39:32],
                   in[31:24],   in[23:16],   in[15:8],    in[7:0] };
endmodule

module mixcolumns(input [127:0] in, output [127:0] out);
    function [7:0] xtime2; input [7:0] a; begin xtime2 = {a[6:0],1'b0} ^ (8'h1b & {8{a[7]}}); end endfunction
    function [7:0] xtime3; input [7:0] a; begin xtime3 = xtime2(a) ^ a; end endfunction
    genvar c;
    generate for (c=0;c<4;c=c+1) begin: COL
        wire [7:0] s0=in[8*(c*4+0)+:8], s1=in[8*(c*4+1)+:8], s2=in[8*(c*4+2)+:8], s3=in[8*(c*4+3)+:8];
        assign out[8*(c*4+0)+:8] = xtime2(s0) ^ xtime3(s1) ^ s2 ^ s3;
        assign out[8*(c*4+1)+:8] = s0 ^ xtime2(s1) ^ xtime3(s2) ^ s3;
        assign out[8*(c*4+2)+:8] = s0 ^ s1 ^ xtime2(s2) ^ xtime3(s3);
        assign out[8*(c*4+3)+:8] = xtime3(s0) ^ s1 ^ s2 ^ xtime2(s3);
    end endgenerate
endmodule

module inv_mixcolumns(input [127:0] in, output [127:0] out);
    function [7:0] xtime; input [7:0] a; begin xtime={a[6:0],1'b0} ^ (8'h1b & {8{a[7]}}); end endfunction
    function [7:0] mul2; input [7:0] a; begin mul2=xtime(a); end endfunction
    function [7:0] mul4; input [7:0] a; begin mul4=mul2(mul2(a)); end endfunction
    function [7:0] mul8; input [7:0] a; begin mul8=mul2(mul4(a)); end endfunction
    function [7:0] mul9; input [7:0] a; begin mul9=mul8(a)^a; end endfunction
    function [7:0] mul11; input [7:0] a; begin mul11=mul8(a)^mul2(a)^a; end endfunction
    function [7:0] mul13; input [7:0] a; begin mul13=mul8(a)^mul4(a)^a; end endfunction
    function [7:0] mul14; input [7:0] a; begin mul14=mul8(a)^mul4(a)^mul2(a); end endfunction
    genvar c;
    generate for (c=0;c<4;c=c+1) begin: COL
        wire [7:0] s0=in[8*(c*4+0)+:8], s1=in[8*(c*4+1)+:8], s2=in[8*(c*4+2)+:8], s3=in[8*(c*4+3)+:8];
        assign out[8*(c*4+0)+:8] = mul14(s0) ^ mul11(s1) ^ mul13(s2) ^ mul9(s3);
        assign out[8*(c*4+1)+:8] = mul9(s0)  ^ mul14(s1) ^ mul11(s2) ^ mul13(s3);
        assign out[8*(c*4+2)+:8] = mul13(s0) ^ mul9(s1)  ^ mul14(s2) ^ mul11(s3);
        assign out[8*(c*4+3)+:8] = mul11(s0) ^ mul13(s1) ^ mul9(s2)  ^ mul14(s3);
    end endgenerate
endmodule

`include "sbox_tables.vh"
