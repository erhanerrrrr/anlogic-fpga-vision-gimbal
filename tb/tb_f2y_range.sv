`timescale 1ns/1ps
// Board-limit integration test. One clock is one controller microsecond;
// tb_pwm100 independently checks the real 100MHz divider and PWM period.
module tb_f2y_range;
 localparam PAN_LO=1000,PAN_HI=2000,TILT_LO=1200,TILT_HI=1800;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,en=0,rc=0,rs=0,tv=1;
 reg [31:0] id=0;reg [10:0] x=640,y=360;
 wire pp,tp,enabled;wire [11:0] pan,tilt;wire [2:0] state;
 f_control #(.CLK_HZ(1000000),.PAN_MIN_US(PAN_LO),.PAN_MAX_US(PAN_HI),
 .TILT_MIN_US(TILT_LO),.TILT_MAX_US(TILT_HI)) dut(
 .clk(clk),.rst_n(rst),.toggle_enable(en),.recenter(rc),.result_strobe(rs),
 .source_ok(1'b1),.target_valid(tv),.source_id(id),.cfg_id(16'd1),.cx(x),.cy(y),
 .pan_pwm(pp),.tilt_pwm(tp),.pan_us(pan),.tilt_us(tilt),.state(state),.enabled(enabled));
 integer cycles=0,pr=-1,tr=-1,pr_prev=-1,tr_prev=-1,pw=0,tw=0,pulses=0;
 integer expected_p=1500,expected_t=1500,i,oldp,oldt;
 reg lastp=0,lastt=0;
 always @(posedge clk)begin
   cycles=cycles+1;
   if(dut.frame_tick)begin expected_p=pan;expected_t=tilt;end
   #1;
   if(rst && (pan<PAN_LO || pan>PAN_HI || tilt<TILT_LO || tilt>TILT_HI))$fatal(1,"board bounds escaped");
   if(pp&&!lastp)begin
     if(pr_prev>=0 && cycles-pr_prev!=20000)$fatal(1,"PAN period");
     pr=cycles;pr_prev=cycles;
   end
   if(tp&&!lastt)begin
     if(tr_prev>=0 && cycles-tr_prev!=20000)$fatal(1,"TILT period");
     tr=cycles;tr_prev=cycles;
   end
   if(!pp&&lastp&&enabled)begin pw=cycles-pr;if(pw!=expected_p)$fatal(1,"PAN width %0d expected %0d",pw,expected_p);pulses=pulses+1;end
   if(!tp&&lastt&&enabled)begin tw=cycles-tr;if(tw!=expected_t)$fatal(1,"TILT width");end
   if(!enabled)begin pr_prev=-1;tr_prev=-1;end
   lastp=pp;lastt=tp;
 end
 task wait_us(input integer n);repeat(n)@(negedge clk);endtask
 task toggle;begin @(negedge clk);en=1;@(negedge clk);en=0;end endtask
 task result(input integer xx,yy,valid_target);begin
   @(negedge clk);id=id+1;x=xx;y=yy;tv=valid_target;rs=1;
   @(negedge clk);rs=0;wait_us(19998);
 end endtask
 task at_limits(input integer p,t);begin
   wait_us(50000);
   if(pan!=p || tilt!=t || pw!=p || tw!=t)$fatal(1,"board endpoints %0d/%0d pulses %0d/%0d expected %0d/%0d",pan,tilt,pw,tw,p,t);
 end endtask
 initial begin
   wait_us(5);rst=1;wait_us(30000);
   if(enabled||pp||tp||pan!=1500||tilt!=1500)$fatal(1,"initial OFF/center");
   toggle();
   // PAN upper and TILT lower are different physical limits.
   for(i=0;i<240;i=i+1)result(1200,0,1);
   at_limits(PAN_HI,TILT_LO);
   for(i=0;i<20;i=i+1)result(1200,0,1);
   at_limits(PAN_HI,TILT_LO);
   // Loss retains both endpoint pulse widths, as does stop/re-enable.
   for(i=0;i<16;i=i+1)result(1200,0,0);
   if(state!=3 || pan!=PAN_HI || tilt!=TILT_LO)$fatal(1,"endpoint loss hold");
   toggle();wait_us(20);if(enabled||pp||tp||state!=0)$fatal(1,"endpoint stop");
   toggle();wait_us(45000);
   if(pan!=PAN_HI || tilt!=TILT_LO)$fatal(1,"endpoint restart recentered");
   // No hidden accumulated command at saturation: reversal responds promptly.
   for(i=0;i<12;i=i+1)result(0,700,1);
   if(pan>=PAN_HI || tilt<=TILT_LO)$fatal(1,"reverse stuck at saturation");
   for(i=0;i<440;i=i+1)result(0,700,1);
   at_limits(PAN_LO,TILT_HI);
   wait_us(300000);
   if(state!=4 || pan!=PAN_LO || tilt!=TILT_HI)$fatal(1,"endpoint timeout hold");
   // A short reverse motion away from the second endpoint proves recovery.
   for(i=0;i<12;i=i+1)result(1200,0,1);
   if(pan<=PAN_LO || tilt>=TILT_HI)$fatal(1,"opposite endpoint stuck");
   // Axis independence remains intact across the wider range.
   @(negedge clk);rc=1;@(negedge clk);rc=0;
   for(i=0;i<40;i=i+1)result(1200,360,1);
   if(pan<=1500 || tilt!=1500)$fatal(1,"PAN changed TILT");
   oldp=pan;for(i=0;i<40;i=i+1)result(640,700,1);
   if(pan!=oldp || tilt<=1500)$fatal(1,"TILT changed PAN");
   toggle();wait_us(10);if(enabled||pp||tp)$fatal(1,"final stop");
   $display("PASS F2Y board range: PAN 1000..2000, TILT 1200..1800; actual endpoint widths, 20ms PWM, saturation/reverse, per-axis isolation, loss/timeout and stop/restart; PAN pulses=%0d",pulses);$finish;
 end
endmodule
