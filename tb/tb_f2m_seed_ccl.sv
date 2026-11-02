`timescale 1ns/1ps
module tb_f2m_seed_ccl;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,m=0,seed=0,sof=0,eof=0;reg [10:0] x=0,y=0;reg [31:0] fid=0;reg [1:0] color=0;
 wire send,valid;wire [19:0] area;wire [10:0] x0,x1,y0,y1;wire [2:0] reason;
 f_shape_regions #(.WIDTH(64),.HEIGHT(48),.MIN_AREA(16),.SEED_CHECK(1)) dut(.clk(clk),.rst_n(rst),
 .mask_valid(v),.mask(m),.seed(seed),.sof(sof),.eof(eof),.x(x),.y(y),.frame_id(fid),.cfg_id(16'd1),.target_id(color),
 .result_strobe(send),.target_valid(valid),.reason(reason),.area(area),.xmin(x0),.xmax(x1),.ymin(y0),.ymax(y1));
 reg [1:0] data[0:184319];integer f,xx,yy,fp,n,ec,ev,ea,ex0,ex1,ey0,ey1,received=0;
 always @(negedge clk)if(send)begin
  received=received+1;
  if(valid!=ev || area!=ea || x0!=ex0 || x1!=ex1 || y0!=ey0 || y1!=ey1)
   $fatal(1,"CCL case%0d got V%0d area%0d box%0d/%0d/%0d/%0d expected V%0d area%0d box%0d/%0d/%0d/%0d R%0d",f,valid,area,x0,x1,y0,y1,ev,ea,ex0,ex1,ey0,ey1,reason);
 end
 initial begin
  $readmemh("tb/f2m_ccl_masks.hex",data);fp=$fopen("tb/f2m_ccl_expected.txt","r");
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<60;f=f+1)begin
   n=$fscanf(fp,"%d %d %d %d %d %d %d\n",ec,ev,ea,ex0,ex1,ey0,ey1);if(n!=7)$fatal(1,"fixture");
   color=ec;fid=f+1;
   for(yy=0;yy<48;yy=yy+1)begin
    for(xx=0;xx<64;xx=xx+1)begin
     @(negedge clk);v=1;x=xx;y=yy;sof=xx==0&&yy==0;eof=xx==63&&yy==47;
     {seed,m}=data[f*3072+yy*64+xx];
    end
    @(negedge clk);v=0;sof=0;eof=0;repeat(2047)@(negedge clk);
   end
   if(received!=f+1)$fatal(1,"missing CCL result");
  end
  $display("PASS F2M seeded CCL 60 independent flood-fill fixtures: random merges/compaction, 0/15/16 seeds, late seeds, largest qualified component, RED bypass");$finish;
 end
endmodule
