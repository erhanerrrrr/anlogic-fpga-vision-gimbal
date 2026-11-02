`timescale 1ns/1ps

// Same-clock adapter: accumulate the REQUESTED mode, not the mode of the
// current frame. Multiple presses before SOF must each advance the request.
module button_mode_request #(
    parameter integer DEBOUNCE_CYCLES=750000,
    parameter integer ACTIVE_LOW=1
) (
    input wire clk, rst_n,
    input wire [2:0] buttons_async,
    output wire [2:0] pressed, press_event,
    output reg [1:0] requested_mode,
    output wire mode_req_valid,
    output wire [2:0] mode_req
);
    button_events #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.ACTIVE_LOW(ACTIVE_LOW)) keys (
        .clk(clk),.rst_n(rst_n),.buttons_async(buttons_async),
        .pressed(pressed),.press_event(press_event)
    );
    wire [1:0] next_mode=requested_mode+2'd1;
    assign mode_req_valid=press_event[0];
    assign mode_req={1'b0,next_mode};
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) requested_mode <= 2'd0;
        else if (mode_req_valid) requested_mode <= next_mode;
    end
endmodule
