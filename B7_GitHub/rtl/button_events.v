`timescale 1ns/1ps

// Independent mode/calibrate/track keys (bits 0/1/2).
// Raw pins first pass through two registers. A state change requires N
// consecutive samples of the synchronized level. Press emits one pulse;
// release rearms the key, and a held key never repeats.
module button_events #(
    parameter integer DEBOUNCE_CYCLES=750000,
    parameter integer ACTIVE_LOW=1
) (
    input wire clk, rst_n,
    input wire [2:0] buttons_async,
    output reg [2:0] pressed,
    output reg [2:0] press_event
);
    localparam integer COUNT_BITS=(DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);
    localparam [COUNT_BITS-1:0] LAST_COUNT=DEBOUNCE_CYCLES-1;
    reg [2:0] sync_first, sync_second;
    reg [COUNT_BITS-1:0] stable_count[0:2];
    integer key;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_first <= 3'd0;
            sync_second <= 3'd0;
        end else begin
            sync_first <= ACTIVE_LOW ? ~buttons_async : buttons_async;
            sync_second <= sync_first;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pressed <= 3'd0;
            press_event <= 3'd0;
            for (key=0; key<3; key=key+1) stable_count[key] <= 0;
        end else begin
            press_event <= 3'd0;
            for (key=0; key<3; key=key+1) begin
                if (sync_second[key] == pressed[key]) stable_count[key] <= 0;
                else if (stable_count[key] == LAST_COUNT) begin
                    stable_count[key] <= 0;
                    pressed[key] <= sync_second[key];
                    press_event[key] <= sync_second[key];
                end else stable_count[key] <= stable_count[key]+1'b1;
            end
        end
    end
endmodule
