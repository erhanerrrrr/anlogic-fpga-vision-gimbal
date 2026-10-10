// Frame-result diagnostics only. No pixel-path buffering or target gating.
// 12 shift-add cycles for W*H, then 27 restoring-division cycles for floor(100*A/B).
// A new input restarts an in-flight calculation; normal board input is once/refresh.
module h4c_fill_metrics #(
    parameter [11:0] WIDTH=12'd1280,HEIGHT=12'd720
)(
    input wire clk,rst_n,input_strobe,
    input wire [31:0] input_frame_id,
    input wire [19:0] input_count,
    input wire [10:0] input_xmin,input_xmax,input_ymin,input_ymax,
    output reg result_strobe,result_valid,
    output reg [31:0] result_frame_id,
    output reg [11:0] box_width,box_height,
    output reg [23:0] box_area,
    output reg [6:0] fill_percent,
    output wire busy
);
    localparam IDLE=2'd0,MULT=2'd1,PREP=2'd2,DIVIDE=2'd3;
    reg [1:0] state;
    reg [31:0] work_frame;
    reg [19:0] work_count;
    reg [11:0] work_width,work_height,mult_b;
    reg [23:0] product,mult_a;
    reg [5:0] steps;
    reg [26:0] numerator;
    reg [27:0] remainder;
    reg [6:0] quotient;
    wire [11:0] in_width={1'b0,input_xmax}-{1'b0,input_xmin}+12'd1;
    wire [11:0] in_height={1'b0,input_ymax}-{1'b0,input_ymin}+12'd1;
    wire input_geometry_ok=input_xmax>=input_xmin && input_ymax>=input_ymin &&
        {1'b0,input_xmax}<WIDTH && {1'b0,input_ymax}<HEIGHT;
    wire [27:0] trial={remainder[26:0],numerator[26]};
    wire [27:0] denominator={4'b0,product};
    wire take_bit=trial>=denominator;
    assign busy=state!=IDLE;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state<=IDLE;result_strobe<=0;result_valid<=0;result_frame_id<=0;
            box_width<=0;box_height<=0;box_area<=0;fill_percent<=0;
            work_frame<=0;work_count<=0;work_width<=0;work_height<=0;
            product<=0;mult_a<=0;mult_b<=0;steps<=0;numerator<=0;remainder<=0;quotient<=0;
        end else begin
            result_strobe<=0;
            if(input_strobe)begin
                work_frame<=input_frame_id;work_count<=input_count;
                work_width<=in_width;work_height<=in_height;
                product<=0;mult_a<={12'd0,in_width};mult_b<=in_height;steps<=12;
                numerator<=0;remainder<=0;quotient<=0;
                if(input_count==0 || !input_geometry_ok)begin
                    state<=IDLE;result_strobe<=1;result_valid<=0;result_frame_id<=input_frame_id;
                    box_width<=0;box_height<=0;box_area<=0;fill_percent<=0;
                end else state<=MULT;
            end else case(state)
                MULT:begin
                    if(mult_b[0])product<=product+mult_a;
                    mult_a<=mult_a<<1;mult_b<=mult_b>>1;steps<=steps-1'b1;
                    if(steps==1)state<=PREP;
                end
                PREP:begin
                    if(product==0 || {4'd0,work_count}>product)begin
                        state<=IDLE;result_strobe<=1;result_valid<=0;result_frame_id<=work_frame;
                        box_width<=0;box_height<=0;box_area<=0;fill_percent<=0;
                    end else begin
                        numerator<={1'b0,work_count,6'd0}+{2'b0,work_count,5'd0}+{5'b0,work_count,2'd0};
                        remainder<=0;quotient<=0;steps<=27;state<=DIVIDE;
                    end
                end
                DIVIDE:begin
                    remainder<=take_bit ? trial-denominator : trial;
                    numerator<=numerator<<1;quotient<={quotient[5:0],take_bit};steps<=steps-1'b1;
                    if(steps==1)begin
                        state<=IDLE;result_strobe<=1;result_valid<=1;result_frame_id<=work_frame;
                        box_width<=work_width;box_height<=work_height;box_area<=product;
                        fill_percent<={quotient[5:0],take_bit};
                    end
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
