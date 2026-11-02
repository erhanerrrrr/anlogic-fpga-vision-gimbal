// SC500CS V1.8 pp22-24: exposure first, gain second; N+2 application delay.
// Runs in the camera configuration (24 MHz) domain. Requests occur after CSI SOF.
// Six NEW displayed frames after bus completion guard the sensor+DDR feedback lag.
module f_sensor_ae #(
 parameter INTEGRATED=0,CLK_HZ=24000000,SETTLE_FRAMES=6,EXP_MIN=12,EXP_MAX=1990,
 parameter GAIN_MIN=16,GAIN_MAX=80
)(
 input clk,rst_n,frame_start,cfg_done,ae_done,bus_error,
 input sample,input [7:0] mean,input [11:0] clipped,near_clip,
 input key_mode,key_target,key_hold,input inhibit,output locked,
 output reg request,output reg [15:0] exposure,gain_index,
 output reg [1:0] mode,output reg [7:0] target,
 output wire [3:0] status,output reg [7:0] measured,
 output reg [11:0] highlights,output reg [15:0] updates,
 output reg fault,output wire live
);
 localparam WATCHDOG=CLK_HZ/2,TRANSACTION_TIMEOUT=CLK_HZ/10;
 reg [$clog2(WATCHDOG+1)-1:0] age;
 reg [$clog2(TRANSACTION_TIMEOUT+1)-1:0] bus_age;
 reg [1:0] bus_state;
 reg [3:0] settle;
 reg pending;reg [15:0] next_exp,next_gain;
 reg [1:0] previous_direction;
 reg [11:0] near_highlights;
 reg inhibit_q;
 wire forced_hold=INTEGRATED && inhibit;
 assign locked=forced_hold && inhibit_q && cfg_done && !fault && !bus_error && live && bus_state==0 && settle==0 && !pending;
 wire bright=(mean>target+8'd12) || clipped>64;
 wire dark=mean+9'd12<target && near_clip<=64;
 wire severe=mean>target+8'd48 || clipped>256 || mean+9'd48<target;
 wire [15:0] step_calc=severe?(exposure>>2):(exposure>>4);
 wire [15:0] exp_step=step_calc<2?16'd2:step_calc;
 wire [15:0] gain_step=severe?16'd8:16'd2;
 assign live=age<WATCHDOG;
 // 0 startup, 1 adjust, 2 stable, 3 dark limit, 4 bright limit,
 // 5 fixed baseline, 6 held, 7 no video, 8 I2C fault, 9 settling, 10 highlight hold.
 assign status=(fault || bus_error)?8:!cfg_done?0:!live?7:
   forced_hold?(locked?6:9):mode==1?5:mode==2?6:(pending || bus_state!=0 || settle!=0)?9:
   (measured+9'd12<target && highlights<=64 && near_highlights>64)?10:
   (measured+9'd12<target && near_highlights<=64 && exposure==EXP_MAX && gain_index==GAIN_MAX)?3:
   ((measured>target+8'd12 || highlights>64) && exposure==EXP_MIN && gain_index==GAIN_MIN)?4:
   (measured+9'd12>=target && measured<=target+8'd12 && highlights<=64)?2:1;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   inhibit_q<=0;exposure<=EXP_MAX;gain_index<=GAIN_MAX;request<=0;mode<=0;target<=112;
   measured<=0;highlights<=0;near_highlights<=0;updates<=0;fault<=0;age<=WATCHDOG;bus_age<=0;
   bus_state<=0;settle<=SETTLE_FRAMES;pending<=0;next_exp<=EXP_MAX;next_gain<=GAIN_MAX;previous_direction<=0;
 end else begin
   request<=0;inhibit_q<=forced_hold;
   if(age<WATCHDOG)age<=age+1'b1;
   if(bus_error)begin fault<=1;pending<=0;end
   if(sample)begin age<=0;measured<=mean;highlights<=clipped;near_highlights<=near_clip;end
   if(bus_state!=0)begin
     if(bus_age<TRANSACTION_TIMEOUT)bus_age<=bus_age+1'b1;
     else begin fault<=1;pending<=0;end
     if(bus_state==1 && !ae_done)bus_state<=2;
     if(bus_state==2 && ae_done)begin
       bus_state<=0;bus_age<=0;settle<=SETTLE_FRAMES;previous_direction<=0;
       if(!fault && !bus_error && updates!=65535)updates<=updates+1'b1;
     end
   end else if(!fault && !bus_error && cfg_done)begin
     if(frame_start && ae_done && !forced_hold && !key_mode && !key_hold && !key_target)begin
       if(mode==1 && (exposure!=EXP_MAX || gain_index!=GAIN_MAX))begin
         exposure<=EXP_MAX;gain_index<=GAIN_MAX;request<=1;bus_state<=1;bus_age<=0;pending<=0;
       end else if(mode==0 && pending && live)begin
         exposure<=next_exp;gain_index<=next_gain;request<=1;bus_state<=1;bus_age<=0;pending<=0;
       end
     end
     if(sample && mode==0 && !pending && !forced_hold)begin
       if(settle!=0)begin settle<=settle-1'b1;previous_direction<=0;end
       else begin
         previous_direction<=bright?2'd1:dark?2'd2:2'd0;
         next_exp<=exposure;next_gain<=gain_index;
         if(bright && previous_direction==1)begin
           if(gain_index>GAIN_MIN)begin
             next_gain<=gain_index<GAIN_MIN+gain_step?GAIN_MIN:gain_index-gain_step;pending<=1;
           end else if(exposure>EXP_MIN)begin
             next_exp<=exposure<EXP_MIN+exp_step?EXP_MIN:exposure-exp_step;pending<=1;
           end
         end else if(dark && previous_direction==2)begin
           if(exposure<EXP_MAX)begin
             next_exp<=exposure+exp_step>EXP_MAX?EXP_MAX:exposure+exp_step;pending<=1;
           end else if(gain_index<GAIN_MAX)begin
             next_gain<=gain_index+gain_step>GAIN_MAX?GAIN_MAX:gain_index+gain_step;pending<=1;
           end
         end
       end
     end
   end
   if(forced_hold)begin
     pending<=0;previous_direction<=0;
     if(!inhibit_q)settle<=SETTLE_FRAMES;
     else if(sample && bus_state==0 && settle!=0)settle<=settle-1'b1;
   end else if(inhibit_q)begin settle<=SETTLE_FRAMES;previous_direction<=0;end
   // Mode changes never alter an in-flight register transaction.
   if(key_mode)begin mode<=mode==1?0:1;pending<=0;settle<=SETTLE_FRAMES;previous_direction<=0;end
   if(key_target)begin
     if(INTEGRATED)begin
       if(mode==1)begin mode<=0;target<=112;end
       else if(target==112)begin mode<=0;target<=96;end
       else if(target==96)begin mode<=0;target<=128;end
       else begin mode<=1;target<=112;end
     end else target<=target==96?112:target==112?128:96;pending<=0;settle<=SETTLE_FRAMES;previous_direction<=0;end
   if(key_hold)begin mode<=mode==2?0:2;pending<=0;settle<=SETTLE_FRAMES;previous_direction<=0;end
 end
endmodule
