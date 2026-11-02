// TX-only experimental logger. Never backpressures video or servo control.
// 40-byte little-endian packets, CRC16-CCITT over bytes 2..37.
module f_uart_telemetry #(parameter CLK_HZ=100000000,BAUD=115200)(
 input clk,rst_n,event_strobe,input [71:0] result,input [63:0] info,
 input source_live,target_live,enabled,input [2:0] state,input [11:0] pan,tilt,
 output reg tx,output reg [15:0] dropped
);
 localparam BIT_CYCLES=(CLK_HZ+BAUD/2)/BAUD,MS_CYCLES=CLK_HZ/1000;
 reg [$clog2(MS_CYCLES)-1:0] ms_div;reg [31:0] ms;
 reg [15:0] sequence_id;reg [31:0] last_id;reg seen;
 reg [71:0] last_result;reg [63:0] last_info;
 reg [9:0] heartbeat;
 wire ms_tick=ms_div==MS_CYCLES-1;
 wire fresh=event_strobe && (!seen || result[69:38]!=last_id);
 wire heartbeat_due=ms_tick && heartbeat==999;
 reg busy;reg [287:0] payload;reg [15:0] crc;
 reg [5:0] byte_index;reg [3:0] bit_index;
 reg [$clog2(BIT_CYCLES)-1:0] bit_timer;
 reg [9:0] shift;
 wire [71:0] chosen=fresh?result:last_result;
 wire [63:0] chosen_info=fresh?info:last_info;
 function [15:0] crc_byte;
 input [15:0] c;input [7:0] b;reg [15:0] v;integer i;
 begin v=c^{b,8'd0};for(i=0;i<8;i=i+1)v=v[15]?(v<<1)^16'h1021:v<<1;crc_byte=v;end
 endfunction
 function [15:0] le16;input [15:0] v;begin le16={v[7:0],v[15:8]};end endfunction
 function [31:0] le32;input [31:0] v;begin le32={v[7:0],v[15:8],v[23:16],v[31:24]};end endfunction
 reg [7:0] next_byte;
 always @*begin
  if(byte_index==0)next_byte=8'h5a;
  else if(byte_index<37)next_byte=payload[287-(byte_index-1)*8-:8];
  else if(byte_index==37)next_byte=crc[7:0];
  else next_byte=crc[15:8];
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  ms_div<=0;ms<=0;sequence_id<=0;last_id<=0;seen<=0;last_result<=0;last_info<=0;heartbeat<=0;
  busy<=0;payload<=0;crc<=16'hffff;byte_index<=0;bit_index<=0;bit_timer<=0;shift<=10'h3ff;tx<=1;dropped<=0;
 end else begin
  if(ms_tick)begin ms_div<=0;ms<=ms+1'b1;heartbeat<=heartbeat==999?0:heartbeat+1'b1;end
  else ms_div<=ms_div+1'b1;
  if(fresh)begin seen<=1;last_id<=result[69:38];last_result<=result;last_info<=info;end
  if(fresh || heartbeat_due)begin
   if(busy)begin if(dropped!=65535)dropped<=dropped+1'b1;end
   else begin
    payload<={8'd1,8'd40,le16(sequence_id),le32(ms),le32(chosen[69:38]),le16(chosen[37:22]),
      le16({5'd0,chosen[21:11]}),le16({5'd0,chosen[10:0]}),le16({4'd0,pan}),le16({4'd0,tilt}),
      {2'b0,fresh,chosen[71],chosen[70],enabled,source_live,target_live},
      {5'd0,state},{5'd0,chosen_info[63:61]},{6'd0,chosen_info[60:59]},
      {5'd0,chosen_info[58:56]},{5'd0,chosen_info[55:53]},le16({1'b0,chosen_info[52:38]}),
      le32(chosen_info[37:6]),le16(dropped)};
    sequence_id<=sequence_id+1'b1;busy<=1;byte_index<=0;bit_index<=0;bit_timer<=BIT_CYCLES-1;
    shift<={1'b1,8'ha5,1'b0};tx<=0;crc<=16'hffff;
   end
  end
  if(busy)begin
   if(bit_timer!=0)bit_timer<=bit_timer-1'b1;
   else begin
    bit_timer<=BIT_CYCLES-1;
    if(bit_index==9)begin
     if(byte_index==39)begin busy<=0;tx<=1;end
     else begin
      byte_index<=byte_index+1'b1;bit_index<=0;shift<={1'b1,next_byte,1'b0};tx<=0;
      if(byte_index>=1 && byte_index<=36)crc<=crc_byte(crc,next_byte);
     end
    end else begin bit_index<=bit_index+1'b1;shift<={1'b1,shift[9:1]};tx<=shift[1];end
   end
  end
 end
endmodule
