// two-level GREEN/BLUE masks from the same causal 2x2 RGB mean.
// Strong pixels confirm color; weak pixels can only survive as part of a
// connected component with >=16 strong pixels after majority filtering.
// No frame history. One register stage, matching RED's original classifier.
module f_seed_color_mask #(parameter WIDTH=1280)(
 input clk,rst_n,valid,input [10:0] x,y,input [23:0] rgb,input [1:0] color,
 input [7:0] min_main,diff1,diff2,output strong_mask,weak_mask
);
 reg [23:0] line[0:WIDTH-1];reg [23:0] above;
 always @(posedge clk)if(rst_n && valid)begin above<=line[x];line[x]<=rgb;end
 reg qvalid;reg [10:0] qx,qy;reg [1:0] qc;
 reg [23:0] current,left,above_left;reg [7:0] qm,qd1,qd2;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  qvalid<=0;qx<=0;qy<=0;qc<=0;current<=0;left<=0;above_left<=0;qm<=0;qd1<=0;qd2<=0;
 end else begin
  qvalid<=valid;qx<=x;qy<=y;qc<=color;current<=rgb;qm<=min_main;qd1<=diff1;qd2<=diff2;
  if(qvalid)begin left<=current;above_left<=above;end
 end
 wire [9:0] sr={2'b0,current[23:16]}+{2'b0,left[23:16]}+{2'b0,above[23:16]}+{2'b0,above_left[23:16]};
 wire [9:0] sg={2'b0,current[15:8]}+{2'b0,left[15:8]}+{2'b0,above[15:8]}+{2'b0,above_left[15:8]};
 wire [9:0] sb={2'b0,current[7:0]}+{2'b0,left[7:0]}+{2'b0,above[7:0]}+{2'b0,above_left[7:0]};
 wire [7:0] r=sr[9:2],g=sg[9:2],b=sb[9:2];
 wire [7:0] m=qc==1?g:b,o2=qc==1?b:g;
 wire signed [8:0] d1=$signed({1'b0,m})-$signed({1'b0,r});
 wire signed [8:0] d2=$signed({1'b0,m})-$signed({1'b0,o2});
 wire [8:0] round4={1'b0,m}+9'd3,round8={1'b0,m}+9'd7;
 wire [7:0] strong_rel=qc==1?{1'b0,round4[8:2]}:{2'b0,round8[8:3]};
 wire [7:0] weak_rel={2'b0,round8[8:3]};
 wire [7:0] weak_main=qm[7:1]<16?8'd16:{1'b0,qm[7:1]};
 wire [7:0] weak_d1=qd1[7:1]<6?8'd6:{1'b0,qd1[7:1]};
 wire [7:0] weak_d2=qd2[7:1]<6?8'd6:{1'b0,qd2[7:1]};
 wire good=qvalid && qx!=0 && qy!=0 && (qc==1 || qc==2);
 assign strong_mask=good && m>=qm && d1>=$signed({1'b0,qd1}) && d2>=$signed({1'b0,qd2}) &&
                    d1>=$signed({1'b0,strong_rel}) && d2>=$signed({1'b0,strong_rel});
 assign weak_mask=good && m>=weak_main && d1>=$signed({1'b0,weak_d1}) && d2>=$signed({1'b0,weak_d2}) &&
                  d1>=$signed({1'b0,weak_rel}) && d2>=$signed({1'b0,weak_rel});
endmodule
