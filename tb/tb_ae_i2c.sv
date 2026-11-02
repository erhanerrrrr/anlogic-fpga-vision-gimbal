`timescale 1ns/1ps
module tb_ae_i2c;
 reg clk=0;always #5 clk=~clk;reg rst=0,request=0,ack=1;
 reg [15:0] exp=1990,gain=80;wire scl,configured,done,error;
 tri1 sda;
 uicfgcs500_720p #(.CLK_DIV(3)) dut(.I_clk(clk),.I_rst_n(rst),.I_ae_req(request),.I_ae(exp),.I_ag(gain),
 .O_cam_scl(scl),.IO_cam_sda(sda),.O_cfg_done(configured),.O_ae_cfg_done(done),.O_bus_error(error));
 // Slave acknowledges only the master's ACK state. Actual I2C RTL is used.
 assign sda=(ack && dut.u_i2c.IIC_S==3)?1'b0:1'bz;
 reg prev_req=0;integer writes=0,j;reg [23:0] written[0:140];
 always @(posedge clk)begin
  prev_req<=dut.iic_req;
  if(dut.iic_req && !prev_req)begin
   if(dut.wr_data[7:0]!=8'h6c)$fatal(1,"sensor address");
   written[writes]={dut.wr_data[15:8],dut.wr_data[23:16],dut.wr_data[31:24]};writes=writes+1;
  end
 end
 initial begin
  repeat(10)@(negedge clk);rst=1;
  wait(configured);repeat(5)@(negedge clk);
  if(writes!=117 || error || !done)$fatal(1,"initialization writes=%d err=%b",writes,error);
  if(written[112]!=24'h3e080f || written[113]!=24'h3e0920 || written[116]!=24'h3e030b)$fatal(1,"init gains or manual AEC control");
  exp=400;gain=16;request=1;@(negedge clk);request=0;
  wait(!done);wait(done);repeat(10)@(negedge clk);
  if(writes!=122 || error)$fatal(1,"AE sequence incomplete");
  if(written[117]!=24'h3e0000 || written[118]!=24'h3e0119 || written[119]!=24'h3e0200 || written[120]!=24'h3e0803 || written[121]!=24'h3e0920)$fatal(1,"AE register write data");
  ack=0;exp=1000;request=1;@(negedge clk);request=0;
  wait(error);ack=1;repeat(1000)@(negedge clk);if(!error)$fatal(1,"NACK not retained");
  $display("PASS SC500 real I2C FSM initialization and exposure/gain register order, baseline matching, ACK and latched NACK");$finish;
 end
 initial begin #30000000;$fatal(1,"I2C timeout");end
endmodule
