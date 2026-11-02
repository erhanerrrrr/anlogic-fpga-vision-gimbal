`timescale 1ns/1ps
module tb_mode_switch;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,user=0,request=0,live=1;reg [1:0] page=0;
 reg [80:0] meta={16'd30,1'b1,32'd1,32'd0};
 f_vision #(.WIDTH(32),.HEIGHT(24)) dut(.clk(clk),.rst_n(rst),.diagnostics(20'd0),.vs(1'b0),.hs(1'b0),.de(de),.user(user),.rgb(24'hc02010),
 .source_meta(meta),.tick(32'd100),.view_page(page),.source_live(live),.mode_event(request),.color_event(1'b0),.cal_event(1'b0),.tracking_state(3'd0),.pan_us(12'd1500),.tilt_us(12'd1500));
 integer n,xx,yy;
 initial begin
   repeat(5)@(negedge clk);rst=1;
   for(n=0;n<10;n=n+1)begin
     page=n%3;live=n%3!=2;
     for(yy=0;yy<24;yy=yy+1)begin
       for(xx=0;xx<32;xx=xx+1)begin
         de=1;user=(xx==0 && yy==0);request=(xx==8 && yy==10);
         if(xx==8 && yy==10)page=(page+1)%3;
         @(negedge clk);
         if(dut.display_page!==2'(n%3))$fatal(1,"OSD page changed midframe");
         if(xx==8 && yy==1 && n>0 && dut.dv!==live)$fatal(1,"stale/live target gate n=%d valid=%b live=%b",n,dut.dv,live);
         if(dut.mode!==3'(n%8))$fatal(1,"mode changed within active frame / wrong wrap %d",dut.mode);
       end
       de=0;user=0;request=0;repeat(10)@(negedge clk);
     end
     // Frame-end classifier budget; 720p has much longer vertical blanking.
     repeat(1400)@(negedge clk);meta[63:32]=meta[63:32]+1;
   end
   // Source metadata remains live but processing stops producing complete
   // results. A bounded display lifetime must prevent an indefinitely old box.
   live=1;request=0;
   for(n=0;n<4;n=n+1)begin
     de=1;user=1;@(negedge clk);de=0;user=0;
     repeat(5)@(negedge clk);
     if(n<3 && !dut.dv)$fatal(1,"completed result expired prematurely");
     if(n==3 && (dut.dv || dut.dreason!=4 || dut.dclass!=0 || dut.darea!=0))$fatal(1,"incomplete frames left an indefinitely old display result");
     repeat(20)@(negedge clk);meta[63:32]=meta[63:32]+1;
   end
   $display("PASS mode switching: eight modes, frame-safe three pages, stale-source suppression, bounded result lifetime under incomplete frames");$finish;
 end
endmodule
