// Frame-end serial arithmetic. No pixel-rate multiplier/divider and no effect
// on the existing CCL control packet. New input cancels an unfinished result.
module f2x_shape_metrics_reference #(parameter WIDTH=1280)(
 input clk,rst_n,input_strobe,
 input [31:0] input_id,input [19:0] input_area,
 input [1023:0] input_extrema,
 output reg done,valid,output reg [31:0] result_id,
 output reg [1:0] object_class
);
 localparam IDLE=0,PREP=1,MUL=2,DIV_INIT=3,DIVIDE=4,BOX_DONE=5,
            OCT_PREP=6,OCT_BOX=7,CUT_PREP=8,CUT_SUB=9,FINISH=10;
 reg [3:0] state,return_state,direction;
 reg [5:0] count;
 reg [1023:0] ext;
 reg [63:0] cuts;
 reg [1:0] cut_index;
 reg [19:0] area;
 reg [31:0] held_id,min_box,max_box,octagon2;
 reg best_short,descriptor_ok;
 reg [15:0] axis_w,axis_h;
 reg [31:0] mul_a,mul_acc,product,numerator,quotient;
 reg [15:0] mul_b;
 reg [7:0] remainder;
 wire [31:0] mul_sum=mul_acc+(mul_b[0]?mul_a:32'd0);
 reg [7:0] norm2;
 reg [3:0] pad;
 always @* begin
   case(direction)
    0:begin norm2=1;pad=1;end
    1,15:begin norm2=65;pad=8;end
    2,14:begin norm2=17;pad=4;end
    3,13:begin norm2=73;pad=9;end
    4,12:begin norm2=5;pad=2;end
    5,11:begin norm2=89;pad=9;end
    6,10:begin norm2=25;pad=5;end
    7,9:begin norm2=113;pad=11;end
    default:begin norm2=2;pad=1;end
   endcase
 end
 wire [15:0] du=ext[31:16]-ext[15:0]+pad;
 wire [15:0] dv=ext[63:48]-ext[47:32]+pad;
 reg current_short;
 wire [8:0] trial={remainder,numerator[31]};
 wire [47:0] a100={28'd0,area}*48'd100;
 wire [47:0] a200={28'd0,area}*48'd200;
 wire card=a100>={16'd0,min_box}*48'd84 &&
           {16'd0,max_box}*48'd100>={16'd0,min_box}*48'd145 && best_short;
 wire ball=a100>={16'd0,min_box}*48'd70 && a200>={16'd0,octagon2}*48'd90 &&
           {2'd0,axis_w}*18'd4>={2'd0,axis_h}*18'd3 &&
           {2'd0,axis_h}*18'd4>={2'd0,axis_w}*18'd3;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   state<=IDLE;return_state<=0;direction<=0;count<=0;ext<=0;cuts<=0;cut_index<=0;
   area<=0;held_id<=0;min_box<=0;max_box<=0;octagon2<=0;best_short<=0;descriptor_ok<=0;
   axis_w<=0;axis_h<=0;mul_a<=0;mul_b<=0;mul_acc<=0;product<=0;
   numerator<=0;quotient<=0;remainder<=0;current_short<=0;
   done<=0;valid<=0;result_id<=0;object_class<=0;
 end else begin
   done<=0;
   if(input_strobe)begin
     state<=PREP;direction<=0;ext<=input_extrema;area<=input_area;held_id<=input_id;
     min_box<=32'hffffffff;max_box<=0;best_short<=0;descriptor_ok<=1;
     axis_w<=input_extrema[31:16]-input_extrema[15:0]+16'd1;
     axis_h<=input_extrema[63:48]-input_extrema[47:32]+16'd1;
     // Pixel-square support octagon: four corner triangles outside the
     // diagonal support lines. v has a fixed translation that cancels here.
     cuts[15:0]<=input_extrema[527:512]-input_extrema[15:0]-input_extrema[47:32];
     cuts[31:16]<=input_extrema[31:16]+input_extrema[63:48]-input_extrema[543:528];
     cuts[47:32]<=input_extrema[559:544]+input_extrema[31:16]-input_extrema[47:32]-(WIDTH-1);
     cuts[63:48]<=(WIDTH-1)-input_extrema[15:0]+input_extrema[63:48]-input_extrema[575:560];
   end else case(state)
     PREP:begin
       mul_a<={16'd0,du};mul_b<=dv;mul_acc<=0;count<=0;return_state<=DIV_INIT;state<=MUL;
       current_short<=du>={8'd0,pad,4'd0} && dv>={8'd0,pad,4'd0};
       if(ext[31:16]<ext[15:0] || ext[63:48]<ext[47:32])descriptor_ok<=0;
     end
     MUL:begin
       mul_acc<=mul_sum;mul_a<=mul_a<<1;mul_b<=mul_b>>1;count<=count+1'b1;
       if(count==15)begin product<=mul_sum;state<=return_state;end
     end
     DIV_INIT:begin numerator<=product;quotient<=0;remainder<=0;count<=0;state<=DIVIDE;end
     DIVIDE:begin
       numerator<=numerator<<1;count<=count+1'b1;
       if(trial>={1'b0,norm2})begin remainder<=trial-norm2;quotient<={quotient[30:0],1'b1};end
       else begin remainder<=trial[7:0];quotient<={quotient[30:0],1'b0};end
       if(count==31)state<=BOX_DONE;
     end
     BOX_DONE:begin
       if(quotient<min_box)begin min_box<=quotient;best_short<=current_short;end
       if(quotient>max_box)max_box<=quotient;
       if(quotient==0)descriptor_ok<=0;
       ext<=ext>>64;direction<=direction+1'b1;state<=(direction==15)?OCT_PREP:PREP;
     end
     OCT_PREP:begin mul_a<={16'd0,axis_w};mul_b<=axis_h;mul_acc<=0;count<=0;return_state<=OCT_BOX;state<=MUL;end
     OCT_BOX:begin octagon2<=product<<1;cut_index<=0;state<=CUT_PREP;end
     CUT_PREP:begin mul_a<={16'd0,cuts[15:0]};mul_b<=cuts[15:0];mul_acc<=0;count<=0;return_state<=CUT_SUB;state<=MUL;end
     CUT_SUB:begin
       octagon2<=octagon2-product;if(product>=octagon2)descriptor_ok<=0;
       cuts<=cuts>>16;cut_index<=cut_index+1'b1;state<=(cut_index==3)?FINISH:CUT_PREP;
     end
     FINISH:begin
       done<=1;valid<=descriptor_ok && area!=0;result_id<=held_id;
       object_class<=(!descriptor_ok || area==0)?0:(card?1:(ball?2:3));state<=IDLE;
     end
   endcase
 end
endmodule
