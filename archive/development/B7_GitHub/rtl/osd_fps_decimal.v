`timescale 1ns/1ps
// B4e provisional A->B rate adapter: three unsigned centi-FPS measurements.
// One 16-step double-dabble converter is reused for all three fields.
// Outputs are five decimal BCD digits; the display inserts a dot before
// the final two digits (for example 6000 -> 060.00 FPS).
module osd_fps_decimal(
    input wire clk,rst_n,flush,start,
    input wire [15:0] source_fps_centi,display_fps_centi,result_fps_centi,
    output reg done,
    output reg [19:0] source_bcd,display_bcd,result_bcd
);
    reg busy;
    reg [1:0] field;
    reg [4:0] step;
    reg [15:0] binary;
    reg [19:0] bcd;
    reg [15:0] saved_display,saved_result;
    reg [19:0] adjusted;
    integer n;
    always @* begin
        adjusted=bcd;
        for(n=0;n<5;n=n+1)
            if(bcd[n*4+:4]>=5)
                adjusted[n*4+:4]=bcd[n*4+:4]+4'd3;
    end
    wire [19:0] shifted={adjusted[18:0],binary[15]};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            busy<=0;field<=0;step<=0;binary<=0;bcd<=0;
            saved_display<=0;saved_result<=0;
            done<=0;source_bcd<=0;display_bcd<=0;result_bcd<=0;
        end else if(flush)begin
            busy<=0;field<=0;step<=0;binary<=0;bcd<=0;
            saved_display<=0;saved_result<=0;
            done<=0;source_bcd<=0;display_bcd<=0;result_bcd<=0;
        end else if(start)begin
            busy<=1;field<=0;step<=0;
            binary<=source_fps_centi;bcd<=0;
            saved_display<=display_fps_centi;
            saved_result<=result_fps_centi;
            done<=0;
        end else if(busy)begin
            binary<={binary[14:0],1'b0};
            bcd<=shifted;
            if(step==5'd15)begin
                step<=0;bcd<=0;
                case(field)
                    0:begin
                        source_bcd<=shifted;
                        field<=1;binary<=saved_display;
                    end
                    1:begin
                        display_bcd<=shifted;
                        field<=2;binary<=saved_result;
                    end
                    default:begin
                        result_bcd<=shifted;
                        busy<=0;done<=1;
                    end
                endcase
            end else step<=step+1'b1;
        end
    end
endmodule
