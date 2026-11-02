// proportional far approach with independent axis gains and limits.
module f_control #(
 parameter CLK_HZ=50000000, TIMEOUT_US=250000,HOLD_ENABLE=0,
 parameter CENTER_X=640,CENTER_Y=360,DEADBAND=12,
 parameter MIN_US=1450,MAX_US=1550,STEP_US=2,
 parameter PAN_SIGN=1,TILT_SIGN=1,
 parameter RELEASE_BAND=24,CONFIRM_SAMPLES=3,UPDATE_FRAMES=5,NEAR_BAND=64,
 parameter FAST_BAND=96,FAST_FRAMES=3,FAR_BAND=192,FAR_FRAMES=2,
 parameter PAN_PROP_DIV=32,TILT_PROP_DIV=40,PAN_MAX_STEP=12,TILT_MAX_STEP=8,
 parameter PAN_MIN_US=MIN_US,PAN_MAX_US=MAX_US,
 parameter TILT_MIN_US=MIN_US,TILT_MAX_US=MAX_US
)(
 input clk,rst_n,toggle_enable,recenter,hold_request,
 input result_strobe,source_ok,target_valid,
 input [31:0] source_id,input [10:0] cx,cy,input [15:0] cfg_id,
 output reg pan_pwm,tilt_pwm,output wire [11:0] pan_us,tilt_us,
 output reg [2:0] state,output reg enabled,
 output reg signed [11:0] error_x,error_y,output wire [19:0] diagnostics
);
 localparam DIV=CLK_HZ/1000000;
 reg [$clog2(DIV+1)-1:0] divider;
 wire us_tick=divider==DIV-1;
 reg [14:0] phase;
 reg [18:0] age;
 reg seen;
 reg [31:0] last_id;
 reg [15:0] last_cfg;
 reg [1:0] acquired;
 reg [11:0] active_pan,active_tilt;
 wire frame_tick=us_tick && phase==19999;
 wire new_result=result_strobe && source_ok && (!seen || source_id!=last_id);
 wire cfg_change=new_result && cfg_id!=last_cfg;
 wire paused=HOLD_ENABLE && hold_request;
 wire clear_axes=paused || !enabled || toggle_enable || recenter || age>=TIMEOUT_US ||
                 (new_result && (!target_valid || cfg_change));
 wire control_sample=new_result && target_valid && enabled && acquired>=2 && !clear_axes;
 wire signed [11:0] sample_x=$signed({1'b0,cx})-CENTER_X;
 wire signed [11:0] sample_y=$signed({1'b0,cy})-CENTER_Y;
 reg [9:0] sub_ms;
 reg [15:0] now_ms;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin sub_ms<=0;now_ms<=0;end
 else if(us_tick)begin
   if(sub_ms==999)begin sub_ms<=0;now_ms<=now_ms+1'b1;end
   else sub_ms<=sub_ms+1'b1;
 end
 wire pan_locked,tilt_locked;
 wire [7:0] pan_interval,tilt_interval;
 wire [3:0] pan_step,tilt_step;
 wire [1:0] pan_brake,tilt_brake;
 assign diagnostics={pan_interval,pan_step,tilt_step,pan_brake,tilt_brake};
 f_axis_predictive #(.CENTER_BAND(DEADBAND),.RELEASE_BAND(RELEASE_BAND),.CONFIRM_SAMPLES(CONFIRM_SAMPLES),
 .UPDATE_FRAMES(UPDATE_FRAMES),.NEAR_BAND(NEAR_BAND),.FAST_BAND(FAST_BAND),.FAST_FRAMES(FAST_FRAMES),
 .FAR_BAND(FAR_BAND),.FAR_FRAMES(FAR_FRAMES),.PROP_DIVISOR(PAN_PROP_DIV),.MAX_STEP_US(PAN_MAX_STEP),
 .MIN_US(PAN_MIN_US),.MAX_US(PAN_MAX_US),.STEP_US(STEP_US),.DIRECTION(PAN_SIGN))
 pan_axis(.clk(clk),.rst_n(rst_n),.clear(clear_axes),.recenter(recenter),.frame_tick(frame_tick),
 .sample_valid(control_sample),.sample_error(sample_x),.now_ms(now_ms),.command_us(pan_us),.center_locked(pan_locked),
 .interval_ms(pan_interval),.last_step_us(pan_step),.brake_mode(pan_brake));
 f_axis_predictive #(.CENTER_BAND(DEADBAND),.RELEASE_BAND(RELEASE_BAND),.CONFIRM_SAMPLES(CONFIRM_SAMPLES),
 .UPDATE_FRAMES(UPDATE_FRAMES),.NEAR_BAND(NEAR_BAND),.FAST_BAND(FAST_BAND),.FAST_FRAMES(FAST_FRAMES),
 .FAR_BAND(FAR_BAND),.FAR_FRAMES(FAR_FRAMES),.PROP_DIVISOR(TILT_PROP_DIV),.MAX_STEP_US(TILT_MAX_STEP),
 .MIN_US(TILT_MIN_US),.MAX_US(TILT_MAX_US),.STEP_US(STEP_US),.DIRECTION(TILT_SIGN))
 tilt_axis(.clk(clk),.rst_n(rst_n),.clear(clear_axes),.recenter(recenter),.frame_tick(frame_tick),
 .sample_valid(control_sample),.sample_error(sample_y),.now_ms(now_ms),.command_us(tilt_us),.center_locked(tilt_locked),
 .interval_ms(tilt_interval),.last_step_us(tilt_step),.brake_mode(tilt_brake));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   divider<=0;phase<=0;age<=TIMEOUT_US;seen<=0;last_id<=0;last_cfg<=0;
   acquired<=0;error_x<=0;error_y<=0;
   active_pan<=1500;active_tilt<=1500;pan_pwm<=0;tilt_pwm<=0;state<=0;enabled<=0;
 end else begin
   if(us_tick)divider<=0;else divider<=divider+1'b1;
   if(us_tick)begin
     phase<=phase==19999?0:phase+1'b1;
     if(age<TIMEOUT_US)age<=age+1'b1;
     if(age>=TIMEOUT_US && enabled)begin state<=4;acquired<=0;end
     if(phase==19999)begin
       // Preserve the established command-to-PWM one-period pipeline.
       active_pan<=pan_us;active_tilt<=tilt_us;pan_pwm<=enabled;tilt_pwm<=enabled;
     end else begin
       if(phase+1'b1>=active_pan)pan_pwm<=0;
       if(phase+1'b1>=active_tilt)tilt_pwm<=0;
     end
   end
   if(new_result)begin
     seen<=1;last_id<=source_id;last_cfg<=cfg_id;age<=0;
     if(enabled)begin
       if(!target_valid)begin state<=3;acquired<=0;end
       else begin
         error_x<=sample_x;error_y<=sample_y;
         if(cfg_change || age>=TIMEOUT_US)begin acquired<=1;state<=1;end
         else if(acquired<2)begin acquired<=acquired+1'b1;state<=1;end
         else state<=2;
       end
     end
   end
   if(enabled && paused)begin state<=5;acquired<=0;end
   if(recenter)begin acquired<=0;state<=enabled?1:0;end
   if(toggle_enable)begin
     enabled<=!enabled;state<=enabled?0:1;acquired<=0;
     if(enabled)begin pan_pwm<=0;tilt_pwm<=0;end
   end
   if(!enabled)begin pan_pwm<=0;tilt_pwm<=0;end
 end
endmodule
