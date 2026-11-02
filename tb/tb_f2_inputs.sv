`timescale 1ns/1ps
module tb_f2_inputs;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg [3:0] keys=15,sw=0;reg enabled=0;
 wire [3:0] pressed,sv;wire toggle,pr,tr;wire [1:0] page;
 f2_inputs #(.CLK_HZ(1000000),.DEBOUNCE_US(3),.LONG_US(100)) dut(
 .clk(clk),.rst_n(rst),.key_n(keys),.sw(sw),.enabled(enabled),.pressed(pressed),.sw_value(sv),
 .toggle_enable(toggle),.page(page),.pan_reverse(pr),.tilt_reverse(tr));
 integer toggles=0;
 always @(posedge clk)if(!rst)enabled<=0;else if(toggle)begin enabled<=!enabled;toggles<=toggles+1;end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task press4(input integer n);begin keys[3]=0;cycles(n);keys[3]=1;cycles(12);end endtask
 initial begin
   cycles(5);rst=1;cycles(12);
   press4(25);if(page!==1 || enabled)$fatal(1,"short key page/off");
   press4(150);if(page!==1 || enabled || toggles!=0)$fatal(1,"permission off long press");
   press4(25);if(page!==2 || enabled)$fatal(1,"clean page");
   press4(25);if(page!==0 || enabled)$fatal(1,"page wrap");
   press4(25);if(page!==1 || enabled)$fatal(1,"page repeat");
   // Raising permission under a held key is not a fresh arming gesture.
   keys[3]=0;cycles(20);sw=5;cycles(150);
   if(enabled)$fatal(1,"held key bypassed permission");
   keys=15;cycles(12);press4(150);
   if(!enabled || pr!==1 || tr!==0 || toggles!=1)$fatal(1,"arm or direction capture");
   sw=9;cycles(20);if(pr!==1 || tr!==0)$fatal(1,"live direction changed");
   // A stopping press cannot re-arm while held, even after the long threshold.
   press4(150);if(enabled || toggles!=2)$fatal(1,"stop then unintended rearm");
   press4(150);if(!enabled || pr!==0 || tr!==1)$fatal(1,"new arm directions");
   sw=8;cycles(30);if(enabled || toggles!=4)$fatal(1,"permission revoke must stop once");
   sw=9;cycles(140);if(enabled)$fatal(1,"permission autoarmed");
   // Short pulse shorter than debounce does not count.
   keys[0]=0;cycles(1);keys[0]=1;cycles(10);
   if(pressed[0])$fatal(1,"debounce");
   $display("PASS F2 controls: fresh permitted long press, stop hold, forced stop once, direction lock, page, debounce");$finish;
 end
endmodule
