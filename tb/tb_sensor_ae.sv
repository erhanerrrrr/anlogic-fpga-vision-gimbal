`timescale 1ns/1ps
module tb_sensor_ae;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,frame=0,cfg=0,done=1,err=0,sample=0,km=0,kt=0,kh=0;
 reg [7:0] mean=112;reg [11:0] clip=0,near_clip=0;
 wire req;wire [15:0] exp,ag,updates;wire [1:0] mode;wire [7:0] target,measured;
 wire [3:0] status;wire [11:0] highlights;wire fault,live;
 f_sensor_ae #(.CLK_HZ(20000)) dut(.clk(clk),.rst_n(rst),.frame_start(frame),.cfg_done(cfg),.ae_done(done),.bus_error(err),
 .sample(sample),.mean(mean),.clipped(clip),.near_clip(near_clip),.key_mode(km),.key_target(kt),.key_hold(kh),
 .request(req),.exposure(exp),.gain_index(ag),.mode(mode),.target(target),.status(status),.measured(measured),.highlights(highlights),.updates(updates),.fault(fault),.live(live));
 integer busy_left=0,requests=0,n,illum,model,hold_requests,lag[0:3],q=0;reg frame_d=0;
 reg [15:0] previous_exp=1990,previous_ag=80;
 always @(posedge clk)begin
   frame_d<=frame;
   if(rst && req)begin
     if(!frame_d || !done || !cfg || err)$fatal(1,"request not on legal camera boundary");
     if(exp<12 || exp>1990 || ag<16 || ag>80)$fatal(1,"bounds");
     requests=requests+1;busy_left=4;done<=0;
   end else if(busy_left>0)begin busy_left=busy_left-1;if(busy_left==0)done<=1;end
   if(rst && !req && !done && (exp!=previous_exp || ag!=previous_ag))$fatal(1,"transaction payload changed");
   previous_exp<=exp;previous_ag<=ag;
 end
 task frame_sample(input integer m,input integer c);
 begin
   @(negedge clk);frame=1;@(negedge clk);frame=0;
   repeat(12)@(negedge clk);mean=m;clip=c;sample=1;@(negedge clk);sample=0;
   repeat(5)@(negedge clk);
 end endtask
 task model_frame(input integer light);
 integer gq;
 begin
   if(ag<48)gq=32+ag-16;else if(ag<80)gq=64+2*(ag-48);else gq=128;
   model=(light*exp*gq)/(1990*32);if(model>255)model=255;
   lag[q]=model;q=(q+1)%4;
   frame_sample(lag[q],lag[q]>=248?400:0);
 end endtask
 initial begin
   for(n=0;n<4;n=n+1)lag[n]=255;
   repeat(4)@(negedge clk);rst=1;
   repeat(10)frame_sample(240,400);if(requests!=0)$fatal(1,"configured too soon");cfg=1;
   repeat(160)model_frame(100);
   if(measured<100 || measured>124 || status!=2 || ag>=80)$fatal(1,"bright convergence m=%d exp=%d gain=%d status=%d",measured,exp,ag,status);
   hold_requests=requests;repeat(20)model_frame(100);if(requests!=hold_requests)$fatal(1,"steady image hunts");
   repeat(260)model_frame(500);
   if(measured<100 || measured>124 || ag!=16 || exp>=1990)$fatal(1,"exposure priority bright");
   repeat(360)model_frame(30);
   if(measured<100 || measured>124 || exp!=1990 || ag<=16)$fatal(1,"exposure priority dark m=%d exp=%d gain=%d",measured,exp,ag);
   // Small mean variation in deadband must not change settings.
   hold_requests=requests;repeat(30)begin frame_sample(104,0);frame_sample(121,0);end
   if(requests!=hold_requests)$fatal(1,"deadband");
   @(negedge clk);kh=1;@(negedge clk);kh=0;hold_requests=requests;
   repeat(30)frame_sample(250,1000);if(requests!=hold_requests || mode!=2)$fatal(1,"hold");
   @(negedge clk);km=1;@(negedge clk);km=0;repeat(15)frame_sample(250,1000);
   if(exp!=1990 || ag!=80 || mode!=1)$fatal(1,"fixed reference");
   @(negedge clk);km=1;@(negedge clk);km=0;
   repeat(12)frame_sample(60,500);if(ag>=80)$fatal(1,"highlight guard on dark colored scene");
   // Pure red can never reach target mean without clipping. Protect its peak
   // rather than oscillate between a dark-mean increase and a clipping decrease.
   near_clip=2048;repeat(12)frame_sample(59,0);hold_requests=requests;
   repeat(30)frame_sample(59,0);
   if(requests!=hold_requests || status!=10)$fatal(1,"colored highlight hold hunts");
   repeat(11000)@(negedge clk);if(live || status!=7)$fatal(1,"stale detection");
   hold_requests=requests;repeat(10)begin frame=1;@(negedge clk);frame=0;@(negedge clk);end
   if(requests!=hold_requests)$fatal(1,"stale command issued");
   err=1;repeat(3)@(negedge clk);err=0;repeat(20)frame_sample(250,1000);
   if(!fault || status!=8 || requests!=hold_requests)$fatal(1,"I2C error not latched");
   $display("PASS sensor AE closed loop, exposure/gain priority, settling, deadband, highlight guard, hold/fixed, stale and I2C fault");$finish;
 end
 initial begin #30000000;$fatal(1,"timeout");end
endmodule
