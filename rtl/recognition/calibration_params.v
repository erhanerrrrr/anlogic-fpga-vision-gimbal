// Pure combinational C9 validity and threshold generation.
module calibration_params(
    input wire sample_ok,
    input wire [8:0] sample_count,
    input wire [7:0] mean_r,mean_g,mean_b,min_r,min_g,min_b,max_r,max_g,max_b,
    output wire valid,
    output reg [2:0] reason,
    output wire [1:0] color,
    output wire [7:0] min_main,diff_1,diff_2
);
    reg [1:0] dominant;
    reg [7:0] main_value,other_1,other_2;
    wire signed [9:0] d1=$signed({2'b0,main_value})-$signed({2'b0,other_1});
    wire signed [9:0] d2=$signed({2'b0,main_value})-$signed({2'b0,other_2});
    wire [7:0] generated_main,generated_d1,generated_d2;
    saturate_sub32 m($signed({2'b0,main_value}),generated_main);
    saturate_sub32 a(d1,generated_d1);
    saturate_sub32 b(d2,generated_d2);
    always @* begin
        if(mean_r>=mean_g && mean_r>=mean_b) begin dominant=0;main_value=mean_r;other_1=mean_g;other_2=mean_b;end
        else if(mean_g>=mean_b) begin dominant=1;main_value=mean_g;other_1=mean_r;other_2=mean_b;end
        else begin dominant=2;main_value=mean_b;other_1=mean_r;other_2=mean_g;end
        reason=0;
        if(!sample_ok || sample_count!=256) reason=1;
        else if(min_r>mean_r || mean_r>max_r || min_g>mean_g || mean_g>max_g || min_b>mean_b || mean_b>max_b) reason=2;
        else if(main_value<80 || main_value>224) reason=3;
        else if(({1'b0,max_r}-{1'b0,min_r})>32 || ({1'b0,max_g}-{1'b0,min_g})>32 || ({1'b0,max_b}-{1'b0,min_b})>32) reason=4;
        else if(d1<40 || d2<40) reason=5;
    end
    assign valid=reason==0;
    assign color=valid ? dominant : 2'b0;
    assign min_main=valid ? generated_main : 8'b0;
    assign diff_1=valid ? generated_d1 : 8'b0;
    assign diff_2=valid ? generated_d2 : 8'b0;
endmodule
