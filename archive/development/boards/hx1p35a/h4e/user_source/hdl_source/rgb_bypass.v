module rgb_bypass (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_valid,
    input  wire [23:0] in_rgb,

    output reg         out_valid,
    output reg  [23:0] out_rgb
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_rgb   <= 24'd0;
        end
        else begin
            out_valid <= in_valid;

            if (in_valid)
                out_rgb <= in_rgb;
            else
                out_rgb <= 24'd0;
        end
    end

endmodule