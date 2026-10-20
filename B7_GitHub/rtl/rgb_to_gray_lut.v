// B2b: same exact B7 weights/rounding, expressed as shifts/adds to avoid DSPs.
// Y=floor((77R+150G+29B+128)/256). Max sum=65408; all operands 16-bit unsigned.
module rgb_to_gray_lut(
    input wire clk,rst_n,in_valid,
    input wire [23:0] in_rgb,
    output reg out_valid,
    output reg [23:0] out_rgb
);
    wire [15:0] r={8'd0,in_rgb[23:16]},g={8'd0,in_rgb[15:8]},b={8'd0,in_rgb[7:0]};
    wire [15:0] rw=((r<<6)+(r<<3))+((r<<2)+r);
    wire [15:0] gw=((g<<7)+(g<<4))+((g<<2)+(g<<1));
    wire [15:0] bw=((b<<4)+(b<<3))+((b<<2)+b);
    wire [15:0] sum=(rw+gw)+(bw+16'd128);
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin out_valid<=0;out_rgb<=0;end
        else begin out_valid<=in_valid;out_rgb<=in_valid?{3{sum[15:8]}}:24'd0;end
    end
endmodule
