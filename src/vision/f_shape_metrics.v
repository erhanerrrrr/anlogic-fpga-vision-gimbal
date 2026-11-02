// reuse the frame-end serial multiplier for classification comparisons.
// Exactly the same integer inequalities, with common factors cancelled.
// No effect on the CCL control packet; a new input cancels unfinished work.
module f_shape_metrics #(parameter WIDTH=1280,STABLE_INPUT=0)(
 input clk,rst_n,input_strobe,
 input [31:0] input_id,input [19:0] input_area,
 input [1023:0] input_extrema,
 output reg done,valid,output reg [31:0] result_id,
 output reg [1:0] object_class
);
 localparam IDLE=0,PREP=1,MUL=2,DIV_INIT=3,DIVIDE=4,BOX_DONE=5,
            OCT_PREP=6,OCT_BOX=7,CUT_PREP=8,CUT_SUB=9,FINISH=10,
            TEST_PREP=11,TEST_LEFT=12,TEST_RIGHT=13;
 reg [3:0] state,return_state,direction;
 reg [5:0] count;
 reg [1023:0] ext;
 reg [63:0] cuts;
 reg [1:0] cut_index;
 reg [19:0] area;
 reg [31:0] held_id,min_box,max_box,octagon2;
 reg best_short,descriptor_ok;
 reg [15:0] axis_w,axis_h;
 reg [39:0] mul_a,mul_acc,product;
 reg [31:0] numerator,quotient;
 reg [15:0] mul_b;
 reg [7:0] remainder;
 wire [39:0] mul_sum=mul_acc+(mul_b[0]?mul_a:40'd0);
 reg [1:0] test_index;
 reg [3:0] tests_pass;
 reg [39:0] test_lhs;
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
 // The CCL publishes an atomic descriptor and holds it until its next strobe.
 // Integrated use reads that existing register; standalone use snapshots input.
 wire [63:0] projection=STABLE_INPUT?input_extrema[direction*64+:64]:ext[63:0];
 wire [15:0] du=projection[31:16]-projection[15:0]+pad;
 wire [15:0] dv=projection[63:48]-projection[47:32]+pad;
 reg current_short;
 wire [8:0] trial={remainder,numerator[31]};
 wire [17:0] axis_w3={1'b0,axis_w,1'b0}+{2'b0,axis_w};
 wire [17:0] axis_h3={1'b0,axis_h,1'b0}+{2'b0,axis_h};
 wire card=tests_pass[0] && tests_pass[1] && best_short;
 wire ball=tests_pass[2] && tests_pass[3] &&
           {axis_w,2'b0}>=axis_h3 && {axis_h,2'b0}>=axis_w3;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   state<=IDLE;return_state<=0;direction<=0;count<=0;if(!STABLE_INPUT)ext<=0;cuts<=0;cut_index<=0;
   area<=0;held_id<=0;min_box<=0;max_box<=0;octagon2<=0;best_short<=0;descriptor_ok<=0;
   axis_w<=0;axis_h<=0;mul_a<=0;mul_b<=0;mul_acc<=0;product<=0;
   numerator<=0;quotient<=0;remainder<=0;current_short<=0;
   test_index<=0;tests_pass<=0;test_lhs<=0;
   done<=0;valid<=0;result_id<=0;object_class<=0;
 end else begin
   done<=0;
   if(input_strobe)begin
     state<=PREP;direction<=0;if(!STABLE_INPUT)ext<=input_extrema;area<=input_area;held_id<=input_id;
     test_index<=0;tests_pass<=0;test_lhs<=0;
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
       if(projection[31:16]<projection[15:0] || projection[63:48]<projection[47:32])descriptor_ok<=0;
     end
     MUL:begin
       mul_acc<=mul_sum;mul_a<=mul_a<<1;mul_b<=mul_b>>1;count<=count+1'b1;
       if(count==15)begin product<=mul_sum;state<=return_state;end
     end
     DIV_INIT:begin numerator<=product[31:0];quotient<=0;remainder<=0;count<=0;state<=DIVIDE;end
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
       if(!STABLE_INPUT)ext<=ext>>64;direction<=direction+1'b1;state<=(direction==15)?OCT_PREP:PREP;
     end
     OCT_PREP:begin mul_a<={16'd0,axis_w};mul_b<=axis_h;mul_acc<=0;count<=0;return_state<=OCT_BOX;state<=MUL;end
     OCT_BOX:begin octagon2<=product[31:0]<<1;cut_index<=0;state<=CUT_PREP;end
     CUT_PREP:begin mul_a<={16'd0,cuts[15:0]};mul_b<=cuts[15:0];mul_acc<=0;count<=0;return_state<=CUT_SUB;state<=MUL;end
     CUT_SUB:begin
       octagon2<=octagon2-product[31:0];if(product[31:0]>=octagon2)descriptor_ok<=0;
       cuts<=cuts>>16;cut_index<=cut_index+1'b1;state<=(cut_index==3)?TEST_PREP:CUT_PREP;
     end
     TEST_PREP:begin
       // area*25 >= min*21; max*20 >= min*29;
       // area*10 >= min*7; area*20 >= octagon2*9.
       mul_a<=test_index==1?{8'd0,max_box}:{20'd0,area};
       case(test_index)
         0:mul_b<=25;1:mul_b<=20;2:mul_b<=10;3:mul_b<=20;
       endcase
       mul_acc<=0;count<=0;return_state<=TEST_LEFT;state<=MUL;
     end
     TEST_LEFT:begin
       test_lhs<=product;
       mul_a<=test_index==3?{8'd0,octagon2}:{8'd0,min_box};
       case(test_index)
         0:mul_b<=21;1:mul_b<=29;2:mul_b<=7;3:mul_b<=9;
       endcase
       mul_acc<=0;count<=0;return_state<=TEST_RIGHT;state<=MUL;
     end
     TEST_RIGHT:begin
       tests_pass[test_index]<=test_lhs>=product;
       test_index<=test_index+1'b1;
       state<=test_index==3?FINISH:TEST_PREP;
     end
     FINISH:begin
       done<=1;valid<=descriptor_ok && area!=0;result_id<=held_id;
       object_class<=(!descriptor_ok || area==0)?0:(card?1:(ball?2:3));state<=IDLE;
     end
   endcase
 end
endmodule
