`timescale 1ns/1ps
module tb_f2n_hold;
 reg clk=0;always #5 clk=~clk;reg rst=0,toggle=0,hold_req=0,strobe=0;reg [31:0] fid=0;
 wire [11:0] pan,tilt;wire [2:0] state;wire enabled,pwm;
 f_control #(.CLK_HZ(1000000),.HOLD_ENABLE(1),.PAN_MIN_US(1300),.PAN_MAX_US(1700),.TILT_MIN_US(1400),.TILT_MAX_US(1600)) dut(
 .clk(clk),.rst_n(rst),.toggle_enable(toggle),.recenter(1'b0),.hold_request(hold_req),.result_strobe(strobe),.source_ok(1'b1),
 .target_valid(1'b1),.source_id(fid),.cfg_id(16'd1),.cx(11'd1100),.cy(11'd600),.pan_us(pan),.tilt_us(tilt),.state(state),.enabled(enabled),.pan_pwm(pwm));
 integer n,held_pan,held_tilt,pulses=0;always @(posedge pwm)pulses=pulses+1;
 task sample;begin @(negedge clk);fid=fid+1;strobe=1;@(negedge clk);strobe=0;repeat(19998)@(negedge clk);end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;toggle=1;@(negedge clk);toggle=0;
  for(n=0;n<30;n=n+1)sample();if(pan<=1500)$fatal(1,"not tracking before hold");
  hold_req=1;repeat(3)@(negedge clk);held_pan=pan;held_tilt=tilt;pulses=0;
  for(n=0;n<20;n=n+1)begin sample();if(pan!=held_pan || tilt!=held_tilt || state!=5)$fatal(1,"hold changes command");end
  if(pulses<19 || !enabled)$fatal(1,"hold must retain PWM torque");
  hold_req=0;for(n=0;n<20;n=n+1)sample();if(pan<=held_pan)$fatal(1,"resume failed");
  hold_req=1;toggle=1;@(negedge clk);toggle=0;repeat(4)@(negedge clk);if(enabled || pwm)$fatal(1,"stop overrides hold");
  $display("PASS F2N observation/calibration hold: commands frozen, PWM continues, source observations continue, resume reacquires, stop priority");$finish;
 end
endmodule
