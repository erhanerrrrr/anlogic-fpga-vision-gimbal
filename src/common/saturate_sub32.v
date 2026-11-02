// Signed input minus calibration margin, saturated to an unsigned byte.
module saturate_sub32(input wire signed [9:0] value,output wire [7:0] result);
    wire signed [10:0] shifted=$signed({value[9],value})-11'sd32;
    assign result=shifted<0 ? 8'd0 : (shifted>255 ? 8'd255 : shifted[7:0]);
endmodule
