`timescale 1ns/1ps
// One shared 20-step double-dabble converter for five fields. No division,
// multiplier, RAM or parallel bank of decimal converters. 100 cycles total.
module osd_decimal_fields(
    input wire clk,rst_n,flush,start,
    input wire [10:0] cx,cy,
    input wire [19:0] area,
    input wire [7:0] slots,
    input wire [11:0] components,
    output reg done,
    output reg [15:0] x_bcd,y_bcd,
    output reg [27:0] area_bcd,
    output reg [11:0] slots_bcd,
    output reg [15:0] components_bcd
);
    reg busy;
    reg [2:0] field;
    reg [4:0] step;
    reg [19:0] binary;
    reg [27:0] bcd;
    reg [10:0] saved_y;
    reg [19:0] saved_area;
    reg [7:0] saved_slots;
    reg [11:0] saved_components;
    reg [27:0] adjusted;
    integer n;
    always @* begin
        adjusted=bcd;
        for(n=0;n<7;n=n+1)
            if(bcd[n*4+:4]>=5) adjusted[n*4+:4]=bcd[n*4+:4]+4'd3;
    end
    wire [27:0] shifted={adjusted[26:0],binary[19]};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy<=0;done<=0;field<=0;step<=0;binary<=0;bcd<=0;
            saved_y<=0;saved_area<=0;saved_slots<=0;saved_components<=0;
            x_bcd<=0;y_bcd<=0;area_bcd<=0;slots_bcd<=0;components_bcd<=0;
        end else if(flush) begin
            busy<=0;done<=0;field<=0;step<=0;binary<=0;bcd<=0;
            saved_y<=0;saved_area<=0;saved_slots<=0;saved_components<=0;
            x_bcd<=0;y_bcd<=0;area_bcd<=0;slots_bcd<=0;components_bcd<=0;
        end else if(start) begin
            busy<=1;done<=0;field<=0;step<=0;bcd<=0;binary<={9'd0,cx};
            saved_y<=cy;saved_area<=area;saved_slots<=slots;saved_components<=components;
            x_bcd<=0;y_bcd<=0;area_bcd<=0;slots_bcd<=0;components_bcd<=0;
        end else if(busy) begin
            binary<={binary[18:0],1'b0};bcd<=shifted;
            if(step==19) begin
                step<=0;bcd<=0;field<=field+1'b1;
                case(field)
                    0:begin x_bcd<=shifted[15:0];binary<={9'd0,saved_y};end
                    1:begin y_bcd<=shifted[15:0];binary<=saved_area;end
                    2:begin area_bcd<=shifted;binary<={12'd0,saved_slots};end
                    3:begin slots_bcd<=shifted[11:0];binary<={8'd0,saved_components};end
                    4:begin components_bcd<=shifted[15:0];busy<=0;done<=1;end
                endcase
            end else step<=step+1'b1;
        end
    end
endmodule
