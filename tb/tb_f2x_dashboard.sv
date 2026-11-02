`timescale 1ns/1ps
module tb_f2x_dashboard;
 reg clk=0;always #5 clk=~clk;reg rst=0,sof=0,lat=0,clear=0,pub=0;
 reg [10:0] x=0,y=0;reg [11:0] now=343;
 wire [511:0] line;wire draw;wire [23:0] pixel;
 f_system_dashboard dut(.clk(clk),.rst_n(rst),.sof(sof),.x(x),.y(y),.latency_page(lat),
 .ae_status({2'd0,4'd2,8'd112,8'd110,12'd3,16'd1990,16'd80,16'd7}),.state(3'd0),
 .status(2'd1),.scale(2'd0),.paused(1'b0),.clear(clear),.publish(pub),
 .current_tenths(now),.min_tenths(12'd343),.max_tenths(12'd508),.samples(16'd1875),.repeats(16'd35),.invalid(16'd0),
 .capture_fps(16'd60),.display_fps(16'd61),.frame_id(32'h12345678),.textline(line),.draw(draw),.pixel(pixel));
 task refresh;begin sof=1;@(negedge clk);sof=0;repeat(200)@(negedge clk);end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;refresh();y=64;#1;
  if(line[511-:104]!="EXPOSURE 16.6")$fatal(1,"AE decimal/header alignment %s",line);
  y=0;#1;if(line[511-:104]!="F3A SENSOR AE")$fatal(1,"AE title alignment %s",line);
  lat=1;refresh();y=64;#1;if(line[511-:72]!="NOW 034.3")$fatal(1,"latency decimal %s",line);
  y=0;#1;if(line[511-:88]!="F3A LATENCY")$fatal(1,"latency title alignment %s",line);
  // Invalid uninitialized history must never leak into the graph.
  x=128;y=600;#1;if(pixel!==24'h101820)$fatal(1,"uninitialized history visible");
  pub=1;@(negedge clk);pub=0;x=1136;#1;if(pixel!==24'h30c8e8)$fatal(1,"newest graph sample not at right edge");
  x=128;#1;if(pixel!==24'h101820)$fatal(1,"old samples visible");
  clear=1;@(negedge clk);clear=0;x=1136;#1;if(pixel!==24'h101820)$fatal(1,"clear did not mask history");
  $display("PASS F2X shared decimal dashboard, left aligned titles, AE and latency values, history reset validity and right-aligned graph");$finish;
 end
endmodule
