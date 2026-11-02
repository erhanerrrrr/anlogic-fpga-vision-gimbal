// Time is the existing 66.666667 MHz DDR clock: nominal 15 ns/tick.
// Measure at the first active pixel handed to HDMI TX, not a later analysis result.
// Round ticks*3/20000 to tenths of a millisecond using a small serial divider.
module f_latency_meter #(parameter PIXEL_HZ=75000000,MAX_TICKS=16666667)(
 input clk,rst_n,display_sof,source_ok,input [31:0] source_id,capture_tick,now_tick,
 input pause,clear,
 output reg publish,output reg [11:0] current_tenths,min_tenths,max_tenths,
 output reg [15:0] samples,repeats,invalid,
 output wire [1:0] status,output reg [31:0] displayed_id
);
 reg seen,meta_ok,have_stats;reg [31:0] last_id;
 reg [$clog2(PIXEL_HZ/4+1)-1:0] age;
 reg busy;reg [5:0] bit_count;reg [31:0] quotient;reg [15:0] remainder;
 wire [31:0] elapsed=now_tick-capture_tick;
 wire [16:0] shifted={remainder,quotient[31]};
 wire take=shifted>=20000;
 wire [16:0] next_rem=take?shifted-17'd20000:shifted;
 wire [31:0] next_quot={quotient[30:0],take};
 assign status=!seen?0:age>=PIXEL_HZ/4?2:!meta_ok?3:1;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   seen<=0;meta_ok<=0;have_stats<=0;last_id<=0;age<=PIXEL_HZ/4;busy<=0;bit_count<=0;quotient<=0;remainder<=0;
   publish<=0;current_tenths<=0;min_tenths<=0;max_tenths<=0;samples<=0;repeats<=0;invalid<=0;displayed_id<=0;
 end else begin
   publish<=0;
   if(age<PIXEL_HZ/4)age<=age+1'b1;
   if(display_sof)begin
     displayed_id<=source_id;meta_ok<=source_ok && elapsed<MAX_TICKS;
     if(source_ok && (!seen || source_id!=last_id))begin seen<=1;last_id<=source_id;age<=0;end
     if(!pause)begin
       if(source_ok && elapsed<MAX_TICKS && !busy)begin
         quotient<=(elapsed<<1)+elapsed+32'd10000;remainder<=0;bit_count<=0;busy<=1;
         if(seen && source_id==last_id && repeats!=65535)repeats<=repeats+1'b1;
       end else if(invalid!=65535)invalid<=invalid+1'b1;
     end
   end
   if(busy)begin
     remainder<=next_rem[15:0];quotient<=next_quot;bit_count<=bit_count+1'b1;
     if(bit_count==31)begin
       busy<=0;
       if(!pause)begin
         publish<=1;current_tenths<=next_quot[11:0];have_stats<=1;
         if(!have_stats || next_quot<min_tenths)min_tenths<=next_quot[11:0];
         if(!have_stats || next_quot>max_tenths)max_tenths<=next_quot[11:0];
         if(samples!=65535)samples<=samples+1'b1;
       end
     end
   end
   if(clear)begin busy<=0;publish<=0;have_stats<=0;current_tenths<=0;min_tenths<=0;max_tenths<=0;samples<=0;repeats<=0;invalid<=0;end
 end
endmodule
