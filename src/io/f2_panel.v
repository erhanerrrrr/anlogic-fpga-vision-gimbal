// Board wiring: O_dig drives RED; O_sel drives GREEN.
// Active-low drive retained. MOTION is 8 red lamps moving, 4 red lamps still.
module f2_panel #(
 parameter CLK_HZ=100000000, FRESH_MS=250,DEMO_MODE=0,
 parameter SEG_LOW=1,SEL_LOW=1,DUAL_LOW=1
)(
 input motion_mode,input [2:0] motion_status,input [14:0] motion_area,
 input clk,rst_n,input dual_mode,page,enabled,input [2:0] state,
 input result_strobe,source_ok,target_valid,input [31:0] source_id,
 input [10:0] cx,cy,input [11:0] pan_us,tilt_us,
 input cal_event,cal_ok,
 output reg [3:0] led,output reg [7:0] dig,sel,
 output buzzer_n,output source_live,target_live,output reg result_new
);
 localparam DIV=CLK_HZ/1000000;
 reg [$clog2(DIV+1)-1:0] divider;
 wire us_tick=divider==DIV-1;
 reg [9:0] sub_ms;
 wire ms_tick=us_tick && sub_ms==999;
 reg [9:0] heartbeat_ms;
 wire slow=heartbeat_ms>=500;
 wire fast=heartbeat_ms[7];
 reg [15:0] age_ms;
 reg seen,have_target;
 reg [31:0] last_id;
 reg [10:0] target_x,target_y;
 assign source_live=seen && age_ms<FRESH_MS;
 assign target_live=source_live && have_target;
 wire new_result=result_strobe && source_ok && (!seen || source_id!=last_id);
 reg previous_live,previous_target;
 wire observe=DEMO_MODE && motion_mode;
 reg was_observe,was_present;
 wire present=source_live && motion_area!=0 && (motion_status==3 || motion_status==4);
 wire loss_event=(previous_live && !source_live)||(previous_target && !target_live);
 // 80ms tone, 80ms gap, optional second tone. 2kHz, no continuously retriggered alarm.
 reg [8:0] sound_ms;
 reg [7:0] tone_us;
 reg tone;
 wire sound_on=(sound_ms>0 && sound_ms<=80)||(sound_ms>160);
 assign buzzer_n=!(sound_on && tone);
 // Decimal conversion is iterative; no combinational division in the 100MHz path.
 reg [11:0] bin_a,bin_b;
 reg [15:0] bcd_a,bcd_b,adjust_a,adjust_b;
 reg [4:0] convert;
 reg [31:0] digits,scan_digits;
 reg blank_coords;
 integer j;
 always @*begin
   adjust_a=bcd_a;adjust_b=bcd_b;
   for(j=0;j<4;j=j+1)begin
     if(bcd_a[j*4+:4]>=5)adjust_a[j*4+:4]=bcd_a[j*4+:4]+4'd3;
     if(bcd_b[j*4+:4]>=5)adjust_b[j*4+:4]=bcd_b[j*4+:4]+4'd3;
   end
 end
 function [7:0] segments;
 input [3:0] n;
 begin case(n)
   0:segments=8'h3f;1:segments=8'h06;2:segments=8'h5b;3:segments=8'h4f;
   4:segments=8'h66;5:segments=8'h6d;6:segments=8'h7d;7:segments=8'h07;
   8:segments=8'h7f;9:segments=8'h6f;default:segments=8'h40;
 endcase end endfunction
 function [3:0] bar;
 input [10:0] coord;input [10:0] center;
 reg [10:0] magnitude;
 begin
   magnitude=coord>center?coord-center:center-coord;
   if(magnitude<=12)bar=4'b0001;
   else if(magnitude<=48)bar=4'b0001;
   else if(magnitude<=96)bar=4'b0011;
   else if(magnitude<=192)bar=4'b0111;
   else bar=4'b1111;
 end endfunction
 reg [7:0] green_on,red_on;
 wire x_negative=target_x<628,y_negative=target_y<348;
 always @*begin
   green_on=0;red_on=0;
   if(observe)begin
     if(present)begin red_on=motion_status==3?8'hff:8'h0f;end
     else green_on=(motion_status==0 || motion_status>=5)?(slow?8'hff:0):8'h01;
   end else if(target_live)begin
     if(x_negative)green_on[3:0]=bar(target_x,640);else red_on[3:0]=bar(target_x,640);
     if(y_negative)green_on[7:4]=bar(target_y,360);else red_on[7:4]=bar(target_y,360);
   end else begin green_on=slow?8'h11:0;red_on=0;end
 end
 reg [2:0] scan_index;
 reg [1:0] scan_step;
 reg active_dual;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   was_observe<=0;was_present<=0;divider<=0;sub_ms<=0;heartbeat_ms<=0;age_ms<=FRESH_MS;seen<=0;have_target<=0;
   last_id<=0;target_x<=0;target_y<=0;result_new<=0;led<=0;
   previous_live<=0;previous_target<=0;sound_ms<=0;tone_us<=0;tone<=0;
   bin_a<=0;bin_b<=0;bcd_a<=0;bcd_b<=0;convert<=0;digits<=32'h15001500;
   scan_digits<=32'h15001500;blank_coords<=0;scan_index<=7;scan_step<=0;active_dual<=0;
   dig<=SEG_LOW?8'hff:0;sel<=SEL_LOW?8'hff:0;
 end else begin
   was_observe<=observe;was_present<=present;
   result_new<=new_result;previous_live<=source_live;previous_target<=target_live;
   if(us_tick)begin
     divider<=0;sub_ms<=sub_ms==999?0:sub_ms+1'b1;
     if(tone_us==249)begin tone_us<=0;tone<=!tone;end else tone_us<=tone_us+1'b1;
   end else divider<=divider+1'b1;
   if(ms_tick)begin
     heartbeat_ms<=heartbeat_ms==999?0:heartbeat_ms+1'b1;
     if(age_ms<FRESH_MS)age_ms<=age_ms+1'b1;
     if(sound_ms!=0)sound_ms<=sound_ms-1'b1;
     bin_a<=observe?(motion_area>4095?12'd4095:motion_area[11:0]):(page?{1'b0,target_x}:pan_us);bin_b<=observe?{9'd0,motion_status}:(page?{1'b0,target_y}:tilt_us);
     blank_coords<=!observe && page && !target_live;bcd_a<=0;bcd_b<=0;convert<=12;
   end else if(convert!=0)begin
     bcd_a<={adjust_a[14:0],bin_a[11]};bin_a<={bin_a[10:0],1'b0};
     bcd_b<={adjust_b[14:0],bin_b[11]};bin_b<={bin_b[10:0],1'b0};convert<=convert-1'b1;
     if(convert==1)digits<=blank_coords?32'haaaaaaaa:{adjust_a[14:0],bin_a[11],adjust_b[14:0],bin_b[11]};
   end
   if(new_result)begin
     seen<=1;last_id<=source_id;age_ms<=0;have_target<=target_valid;
     target_x<=cx;target_y<=cy;
   end
   if(loss_event && seen && !observe)sound_ms<=240;
   if(observe && was_observe && present && !was_present)sound_ms<=80;
   if(cal_event)sound_ms<=cal_ok?80:240;
   led[0]<=slow;led[1]<=source_live;led[2]<=observe?present:target_live;
   led[3]<=!enabled?0:state==2?1:state==1?slow:fast;
   // Every 1ms: all off, update segments, then enable one digit, on separate
   // 1us ticks. Mode switches also go through an all-off interval.
   if(ms_tick)begin
     dig<=active_dual?(DUAL_LOW?8'hff:0):(SEG_LOW?8'hff:0);
     sel<=active_dual?(DUAL_LOW?8'hff:0):(SEL_LOW?8'hff:0);
     scan_step<=1;active_dual<=dual_mode;scan_index<=scan_index+1'b1;
     if(scan_index==7)scan_digits<=digits;
   end else if(us_tick && scan_step==1)begin
     if(active_dual)begin
       dig<=DUAL_LOW?~red_on:red_on;sel<=DUAL_LOW?~green_on:green_on;
       scan_step<=0;
     end else begin
       dig<=SEG_LOW?~segments(scan_digits[(7-scan_index)*4+:4]):segments(scan_digits[(7-scan_index)*4+:4]);
       scan_step<=2;
     end
   end else if(us_tick && scan_step==2)begin
     sel<=SEL_LOW?~(8'b1<<scan_index):(8'b1<<scan_index);scan_step<=0;
   end
 end
endmodule
