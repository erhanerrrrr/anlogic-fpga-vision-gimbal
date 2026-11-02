`timescale 1ns/1ps
module tb_target_text_font;
    reg [7:0] ch;
    reg [3:0] row;
    wire [15:0] bits;
    reg [15:0] expected [0:4095];
    integer i;
    target_text_font dut(ch,row,bits);
    initial begin
        $readmemh("font_expected.mem",expected);
        for(i=0;i<4096;i=i+1) begin
            ch=i/16; row=i%16; #1;
            if(bits!==expected[i]) $fatal(1,"Font mismatch char=%d row=%d",ch,row);
        end
        $display("PASS FONT: 4096 rows checked");
        $finish;
    end
endmodule
