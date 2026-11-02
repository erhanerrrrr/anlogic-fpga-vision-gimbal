// C1: one registered pixel classifier. Parameters are elaboration-time presets.
module color_classifier #(
    parameter [7:0] MIN_MAIN = 8'd80,
    parameter [7:0] MIN_DIFF_1 = 8'd40,
    parameter [7:0] MIN_DIFF_2 = 8'd40
)(
    input wire clk,
    input wire rst_n,
    input wire pixel_valid,
    input wire [23:0] rgb,
    input wire [1:0] active_color, // 0=R, 1=G, 2=B; 3 invalid
    output reg mask_valid,
    output reg mask
);
    reg [7:0] main_channel, other_1, other_2;
    wire signed [8:0] difference_1;
    wire signed [8:0] difference_2;
    assign difference_1 = $signed({1'b0, main_channel}) - $signed({1'b0, other_1});
    assign difference_2 = $signed({1'b0, main_channel}) - $signed({1'b0, other_2});
    always @* begin
        main_channel = 0;
        other_1 = 0;
        other_2 = 0;
        case (active_color)
            2'd0: begin main_channel=rgb[23:16]; other_1=rgb[15:8]; other_2=rgb[7:0]; end
            2'd1: begin main_channel=rgb[15:8]; other_1=rgb[23:16]; other_2=rgb[7:0]; end
            2'd2: begin main_channel=rgb[7:0]; other_1=rgb[23:16]; other_2=rgb[15:8]; end
            default: begin main_channel=0; other_1=0; other_2=0; end
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask_valid <= 1'b0;
            mask <= 1'b0;
        end else begin
            mask_valid <= pixel_valid;
            mask <= pixel_valid && (active_color != 2'd3) &&
                    (main_channel >= MIN_MAIN) &&
                    (difference_1 >= $signed({1'b0, MIN_DIFF_1})) &&
                    (difference_2 >= $signed({1'b0, MIN_DIFF_2}));
        end
    end
endmodule
