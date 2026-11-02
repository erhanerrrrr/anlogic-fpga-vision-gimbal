`timescale 1ns/1ps
module tb_f2n_uart;
 reg clk=0;always #5 clk=~clk;reg rst=0,send=0;reg [71:0] result=0;reg [63:0] info=0;wire tx;wire [15:0] dropped;
 f_uart_telemetry #(.CLK_HZ(1000000),.BAUD(100000)) dut(.clk(clk),.rst_n(rst),.event_strobe(send),.result(result),.info(info),
 .source_live(1'b1),.target_live(1'b1),.enabled(1'b1),.state(3'd2),.pan(12'd1512),.tilt(12'd1490),.tx(tx),.dropped(dropped));
 integer f,i,j,k,log,n=0;reg [7:0] b;reg [7:0] bytes[0:39];reg [15:0] crc;
 initial begin
  log=$fopen("sim/uart_packets.hex","w");
  forever begin
   @(negedge tx);repeat(15)@(posedge clk);
   for(j=0;j<8;j=j+1)begin b[j]=tx;repeat(10)@(posedge clk);end
   if(tx!==1)$fatal(1,"UART stop bit");
   bytes[n%40]=b;$fdisplay(log,"%02x",b);n=n+1;
   if(n%40==0)begin
    if(bytes[0]!=8'ha5 || bytes[1]!=8'h5a || bytes[2]!=1 || bytes[3]!=40)$fatal(1,"framing");
    crc=16'hffff;
    for(i=2;i<38;i=i+1)begin
     for(k=7;k>=0;k=k-1)begin
      if(crc[15]^bytes[i][k])crc=(crc<<1)^16'h1021;else crc=crc<<1;
     end
    end
    if({bytes[39],bytes[38]}!=crc)$fatal(1,"CRC");
    if({bytes[17],bytes[16]}!=640 || {bytes[19],bytes[18]}!=360 || {bytes[21],bytes[20]}!=1512)$fatal(1,"payload endian/coherence");
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  result={1'b1,1'b1,32'd123,16'd9,11'd640,11'd360};info={3'd6,2'd1,3'd0,3'd3,15'd77,32'd999,6'd0};
  send=1;@(negedge clk);send=0;
  repeat(50)@(negedge clk);result[69:38]=124;send=1;@(negedge clk);send=0;
  wait(n==40);repeat(20)@(negedge clk);
  if(dropped!=1)$fatal(1,"busy should drop without backpressure");
  send=1;@(negedge clk);send=0;repeat(20)@(negedge clk);if(!tx)$fatal(1,"duplicate replayed");
  result[69:38]=125;send=1;@(negedge clk);send=0;wait(n==80);
  // No new source still produces a heartbeat after one second.
  wait(n==120);repeat(20)@(negedge clk);$fclose(log);
  $display("PASS F2N UART 8N1 bit timing, 3 packets, little-endian payload, independent CRC, busy drop, duplicate suppression, no-source heartbeat");$finish;
 end
 initial begin repeat(1200000)@(negedge clk);$fatal(1,"timeout");end
endmodule
