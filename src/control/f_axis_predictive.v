// proportional far approach, measured observation interval, center hold.
// All arithmetic is bounded/multicycle; no floating point, divider IP or DSP.
// Snapshot at PWM boundary; commit 96 clocks later, before the NEXT PWM pulse.
module f_axis_predictive #(
 parameter CENTER_BAND=12,RELEASE_BAND=24,CONFIRM_SAMPLES=3,
 parameter UPDATE_FRAMES=5,NEAR_BAND=64,FAST_BAND=96,FAST_FRAMES=3,
 parameter FAR_BAND=192,FAR_FRAMES=2,PROP_DIVISOR=32,MAX_STEP_US=12,
 parameter MIN_US=1450,MAX_US=1550,STEP_US=2,DIRECTION=1
)(
 input clk,rst_n,clear,recenter,frame_tick,sample_valid,
 input signed [11:0] sample_error,input [15:0] now_ms,
 output reg [11:0] command_us,output reg center_locked,
 output reg [7:0] interval_ms,output reg [3:0] last_step_us,
 output reg [1:0] brake_mode
);
 localparam CB=$clog2(CONFIRM_SAMPLES+1),WB=$clog2(UPDATE_FRAMES+1);
 reg [CB-1:0] confirmation;
 reg candidate_negative,have_direction,last_negative;
 reg [WB-1:0] elapsed;
 reg pending;reg signed [11:0] pending_error;reg [15:0] pending_time;
 wire [11:0] magnitude=sample_error[11]?-sample_error:sample_error;
 wire same_candidate=confirmation!=0 && candidate_negative==sample_error[11];
 wire confirmed=(CONFIRM_SAMPLES<=1)||(same_candidate && confirmation>=CONFIRM_SAMPLES-1);
 wire allowed=magnitude>CENTER_BAND && (!center_locked || (magnitude>RELEASE_BAND && confirmed));
 wire signed [11:0] selected_error=sample_valid?sample_error:pending_error;
 wire [11:0] selected_magnitude=selected_error[11]?-selected_error:selected_error;
 wire [15:0] selected_time=sample_valid?now_ms:pending_time;
 wire selected_allowed=sample_valid?allowed:(pending && !center_locked);
 wire selected_confirmed=sample_valid?confirmed:confirmation>=CONFIRM_SAMPLES;
 wire [WB-1:0] required_wait=selected_magnitude>FAR_BAND?FAR_FRAMES-1:
                                          selected_magnitude>FAST_BAND?FAST_FRAMES-1:UPDATE_FRAMES-1;
 reg history_valid;reg signed [11:0] previous_error;reg [15:0] previous_time;
 reg signed [22:0] velocity_q10;
 reg [3:0] ramp_step;reg [15:0] last_command_time;

 localparam IDLE=0,PREP=1,DIVIDE=2,FILTER=3,MUL_INIT=4,MULTIPLY=5,
            REMAIN=6,DECODE=7,RAMP=8,ADD=9,CLAMP=10,DELTA=11,READY=12;
 reg [3:0] phase;
 reg [6:0] deadline;
 reg job_permit,job_negative,job_history,job_center;
 reg [11:0] job_magnitude;
 reg signed [12:0] job_delta;
 reg [15:0] job_gap;
 reg [7:0] dt,denominator;
 reg [21:0] dividend,quotient;
 reg [8:0] remainder;
 reg [4:0] div_left;
 wire [8:0] trial={remainder[7:0],dividend[21]};
 wire [12:0] delta_abs=job_delta[12]?-job_delta:job_delta;
 wire signed [22:0] raw_velocity=job_delta[12]?-$signed({1'b0,quotient}):$signed({1'b0,quotient});
 wire signed [23:0] velocity_sum=$signed({velocity_q10[22],velocity_q10})+$signed({raw_velocity[22],raw_velocity});
 wire [22:0] closing=job_negative?(velocity_q10[22]?23'd0:velocity_q10):
                                       (velocity_q10[22]?-velocity_q10:23'd0);
 reg [22:0] closing_saved;
 reg [34:0] product,multiplicand;
 reg [10:0] multiplier;
 reg [3:0] mul_left;
 reg [21:0] remaining_q10;
 reg [3:0] decoded_step,chosen_step;
 reg [1:0] decoded_mode;
 reg signed [13:0] proposed;
 reg [11:0] bounded;
 reg [3:0] actual_delta;
 wire [15:0] since_command=now_ms-last_command_time;
 wire [4:0] ramp_limit=(!have_direction || since_command>200 || job_negative!=last_negative)?5'd4:{1'b0,ramp_step}+5'd2;
 reg [3:0] proportional_step;integer n;
 always @*begin
   proportional_step=0;
   for(n=1;n<=MAX_STEP_US;n=n+1)
     if(remaining_q10[21:10]>=PROP_DIVISOR*n)proportional_step=n;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   command_us<=1500;center_locked<=1;confirmation<=0;candidate_negative<=0;
   have_direction<=0;last_negative<=0;elapsed<=UPDATE_FRAMES-1;
   pending<=0;pending_error<=0;pending_time<=0;
   history_valid<=0;previous_error<=0;previous_time<=0;velocity_q10<=0;
   ramp_step<=0;last_command_time<=0;interval_ms<=0;last_step_us<=0;brake_mode<=0;
   phase<=IDLE;deadline<=0;job_permit<=0;job_negative<=0;job_history<=0;job_center<=0;
   job_magnitude<=0;job_delta<=0;job_gap<=0;dt<=1;denominator<=1;
   dividend<=0;quotient<=0;remainder<=0;div_left<=0;
   closing_saved<=0;product<=0;multiplicand<=0;multiplier<=0;mul_left<=0;
   remaining_q10<=0;decoded_step<=0;chosen_step<=0;decoded_mode<=0;
   proposed<=1500;bounded<=1500;actual_delta<=0;
 end else if(clear || recenter)begin
   if(recenter)command_us<=1500;
   center_locked<=1;confirmation<=0;candidate_negative<=0;have_direction<=0;last_negative<=0;
   elapsed<=UPDATE_FRAMES-1;pending<=0;history_valid<=0;velocity_q10<=0;
   ramp_step<=0;last_command_time<=now_ms;phase<=IDLE;deadline<=0;job_permit<=0;
   interval_ms<=0;last_step_us<=0;brake_mode<=0;
 end else begin
   if(deadline!=0)deadline<=deadline-1'b1;
   if(sample_valid)begin
     pending<=1;pending_error<=sample_error;pending_time<=now_ms;
     if(magnitude<=CENTER_BAND)begin center_locked<=1;confirmation<=0;end
     else if(center_locked && magnitude<=RELEASE_BAND)confirmation<=0;
     else begin
       candidate_negative<=sample_error[11];
       if(!same_candidate)confirmation<=1;
       else if(confirmation<CONFIRM_SAMPLES)confirmation<=confirmation+1'b1;
       if(!center_locked || confirmed)center_locked<=0;
     end
     // An urgent newer center/opposite observation cancels an in-flight move.
     // Same-side post-boundary samples belong to the next boundary snapshot.
     if(deadline!=0 && (magnitude<=CENTER_BAND || sample_error[11]!=job_negative))job_permit<=0;
   end
   if(frame_tick)begin
     if(elapsed<UPDATE_FRAMES-1)elapsed<=elapsed+1'b1;
     pending<=0;
     if(sample_valid || pending)begin
       deadline<=96;phase<=PREP;
       job_permit<=selected_allowed && elapsed>=required_wait &&
                   (!have_direction || selected_error[11]==last_negative || selected_confirmed);
       job_negative<=selected_error[11];job_magnitude<=selected_magnitude;
       job_center<=!selected_allowed;job_history<=history_valid;
       job_delta<=$signed({selected_error[11],selected_error})-$signed({previous_error[11],previous_error});
       job_gap<=selected_time-previous_time;
       previous_error<=selected_error;previous_time<=selected_time;history_valid<=1;
     end
   end else case(phase)
     PREP:begin
       dt<=!job_history?8'd20:job_gap==0?8'd1:job_gap>250?8'd250:job_gap[7:0];
       denominator<=!job_history?8'd20:job_gap==0?8'd1:job_gap>250?8'd250:job_gap[7:0];
       dividend<=job_history?{delta_abs[11:0],10'b0}:22'd0;
       quotient<=0;remainder<=0;div_left<=22;phase<=DIVIDE;
     end
     DIVIDE:begin
       dividend<={dividend[20:0],1'b0};div_left<=div_left-1'b1;
       if(trial>={1'b0,denominator})begin remainder<=trial-denominator;quotient<={quotient[20:0],1'b1};end
       else begin remainder<=trial;quotient<={quotient[20:0],1'b0};end
       if(div_left==1)phase<=FILTER;
     end
     FILTER:begin velocity_q10<=job_history?(velocity_sum>>>1):23'sd0;phase<=MUL_INIT;end
     MUL_INIT:begin
       closing_saved<=closing;product<=0;multiplicand<={12'b0,closing};
       multiplier<=dt>20?11'd240+(({3'b0,dt}-11'd20)<<2):11'd240;
       mul_left<=11;phase<=MULTIPLY;
     end
     MULTIPLY:begin
       if(multiplier[0])product<=product+multiplicand;
       multiplicand<=multiplicand<<1;multiplier<=multiplier>>1;mul_left<=mul_left-1'b1;
       if(mul_left==1)phase<=REMAIN;
     end
     REMAIN:begin
       remaining_q10<=product>={13'b0,job_magnitude,10'b0}?22'd0:{job_magnitude,10'b0}-product[21:0];
       phase<=DECODE;
     end
     DECODE:begin
       decoded_step<=job_magnitude>FAR_BAND?proportional_step:job_magnitude<=NEAR_BAND?4'd1:STEP_US;
       decoded_mode<=job_center?2'd3:(product!=0?2'd1:2'd0);
       if(!job_center && closing_saved!=0 && remaining_q10<=(RELEASE_BAND<<10))begin decoded_step<=0;decoded_mode<=2;end
       phase<=RAMP;
     end
     RAMP:begin
       chosen_step<=job_magnitude>FAR_BAND && decoded_step>ramp_limit?ramp_limit[3:0]:decoded_step;
       phase<=ADD;
     end
     ADD:begin
       proposed<=$signed({2'b0,command_us})+((job_negative^(DIRECTION<0))?-$signed({10'b0,chosen_step}):$signed({10'b0,chosen_step}));
       phase<=CLAMP;
     end
     CLAMP:begin bounded<=proposed<MIN_US?MIN_US:proposed>MAX_US?MAX_US:proposed[11:0];phase<=DELTA;end
     DELTA:begin actual_delta<=bounded>command_us?bounded-command_us:command_us-bounded;phase<=READY;end
     default:begin end
   endcase
   if(deadline==1)begin
     phase<=IDLE;interval_ms<=job_history?dt:0;brake_mode<=decoded_mode;
     if(phase==READY && job_permit &&
        !(sample_valid && (magnitude<=CENTER_BAND || sample_error[11]!=job_negative)))begin
       command_us<=bounded;
       if(actual_delta!=0)begin
         elapsed<=0;last_negative<=job_negative;have_direction<=1;
         ramp_step<=chosen_step;last_command_time<=now_ms;last_step_us<=actual_delta;
       end
     end
   end
 end
endmodule
