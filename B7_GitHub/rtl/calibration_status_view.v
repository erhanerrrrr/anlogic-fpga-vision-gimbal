`timescale 1ns/1ps
// Observer only. All C fields/events must be coherent in clk domain.
// Packet [50:0]: known,phase[2:0],result[1:0],reason[2:0],cfg[15:0],color[1:0],main,d1,d2.
// phase: 0 IDLE,1 WAIT SAMPLE,2 CALC,3 PENDING,4 APPLIED,5 FAILED,6 UNKNOWN.
// result: 0 NONE,1 OK (calculation only),2 FAIL. Not mechanical tracking state.
module calibration_status_view(
    input wire clk,rst_n,c_status_valid,
    input wire sample_req,sample_done,calibration_done,calibration_ok,cfg_applied,pending_valid,busy,
    input wire [2:0] calibration_reason,
    input wire [15:0] active_cfg_id,
    input wire [1:0] active_color,
    input wire [7:0] active_main,active_diff_1,active_diff_2,
    output reg [50:0] status_packet
);
    reg [2:0] phase,reason;
    reg [1:0] result;
    always @* begin
        phase=status_packet[49:47];result=status_packet[46:45];reason=status_packet[44:42];
        if(!status_packet[50])begin phase=0;result=0;reason=0;end
        if(sample_req)begin phase=1;result=0;reason=0;end
        else if(busy && (phase==0 || phase==4 || phase==5))begin phase=1;result=0;reason=0;end
        if(sample_done)phase=2;
        if(pending_valid)phase=3;
        if(calibration_done)begin
            phase=calibration_ok ? 3'd3 : 3'd5;
            result=calibration_ok ? 2'd1 : 2'd2;reason=calibration_reason;
        end
        if(cfg_applied)phase=4;
    end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)status_packet<={1'b0,3'd6,47'd0};
        else if(!c_status_valid)status_packet<={1'b0,3'd6,47'd0};
        else status_packet<={1'b1,phase,result,reason,active_cfg_id,active_color,active_main,active_diff_1,active_diff_2};
    end
endmodule
