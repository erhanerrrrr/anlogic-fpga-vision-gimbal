// larger steps for far targets, preserving near-center settling behavior.
// Samples are NEW source results, never display refreshes. No position sensor
// is implied; command_us is a requested electrical pulse width.
module f_axis_stable #(
 parameter CENTER_BAND=12, RELEASE_BAND=24, CONFIRM_SAMPLES=3,
 parameter UPDATE_FRAMES=5, NEAR_BAND=64,
 parameter FAST_BAND=96, FAST_FRAMES=3, FAR_BAND=192, FAR_FRAMES=2,
 parameter FAR_STEP_US=4, SPRINT_BAND=320, SPRINT_STEP_US=6,
 parameter MIN_US=1450, MAX_US=1550, STEP_US=2, DIRECTION=1
)(
 input clk,rst_n,clear,recenter,frame_tick,sample_valid,
 input signed [11:0] sample_error,
 output reg [11:0] command_us,
 output reg center_locked
);
 localparam COUNT_BITS=(CONFIRM_SAMPLES>1)?$clog2(CONFIRM_SAMPLES+1):1;
 localparam WAIT_BITS=(UPDATE_FRAMES>1)?$clog2(UPDATE_FRAMES):1;
 reg [COUNT_BITS-1:0] confirmation;
 // Count elapsed frames so approaching the center immediately restores the
 // slower interval, even if the preceding command used a faster interval.
 reg [WAIT_BITS-1:0] elapsed_frames;
 reg pending,candidate_negative,last_negative,have_direction;
 reg pending_negative,have_observation,previous_negative;
 reg [11:0] previous_magnitude;
 reg [1:0] pending_step;
 reg [WAIT_BITS-1:0] pending_wait;
 wire [11:0] magnitude=sample_error[11]?-sample_error:sample_error;
 // Adjacent fresh observations provide a conservative approach guard. It
 // caps only the enlarged far steps; it is not a measured velocity or delay.
 // Store the decision with the pending sample, including edge-coincident data.
 wire approaching=have_observation && previous_negative==sample_error[11] && previous_magnitude>magnitude;
 wire [11:0] closing=approaching?previous_magnitude-magnitude:12'd0;
 wire [15:0] braking_distance={1'b0,closing,3'b0}+FAR_BAND;
 wire brake_sample=approaching && {4'b0,magnitude}<=braking_distance;
 wire same_candidate=confirmation!=0 && candidate_negative==sample_error[11];
 wire confirmed_now=(CONFIRM_SAMPLES<=1) ||
                    (same_candidate && confirmation>=CONFIRM_SAMPLES-1);
 // Select the newest observation even when it arrives exactly on a PWM edge.
 // Deferring every coincident sample would starve a phase-aligned source.
 wire sample_allowed=magnitude>CENTER_BAND &&
                     (!center_locked || (magnitude>RELEASE_BAND && confirmed_now));
 wire decision_valid=sample_valid?sample_allowed:(pending && !center_locked);
 // Decode each fresh observation before the late source-valid selection.
 // Pending observations retain the step and wait selected at their arrival.
 wire [1:0] sample_step=magnitude>SPRINT_BAND && !brake_sample?2'd3:
                        magnitude>FAR_BAND && !brake_sample?2'd2:
                        magnitude<=NEAR_BAND?2'd0:2'd1;
 wire [WAIT_BITS-1:0] sample_wait=magnitude>FAR_BAND?FAR_FRAMES-1:
                                 magnitude>FAST_BAND?FAST_FRAMES-1:UPDATE_FRAMES-1;
 wire decision_negative=sample_valid?sample_error[11]:pending_negative;
 wire [1:0] decision_step=sample_valid?sample_step:pending_step;
 wire direction_confirmed=sample_valid?confirmed_now:(confirmation>=CONFIRM_SAMPLES);
 wire [WAIT_BITS-1:0] required_wait=sample_valid?sample_wait:pending_wait;
 wire commit=frame_tick && elapsed_frames>=required_wait && decision_valid &&
             (!have_direction || decision_negative==last_negative || direction_confirmed);
 // Calculate constant-size, saturated moves in parallel. Selecting one after
 // the observation decoder avoids a serial mux/abs/step/add/clamp path at
 // 100MHz. No extra clock or PWM-period latency is introduced.
 function [12:0] bounded_move;
   input [11:0] value;
   input signed [13:0] delta;
   reg signed [13:0] proposed;
   reg [11:0] bounded;
   begin
     proposed=$signed({2'b0,value})+delta;
     if(proposed<MIN_US)bounded=MIN_US;
     else if(proposed>MAX_US)bounded=MAX_US;
     else bounded=proposed[11:0];
     bounded_move={bounded!=value,bounded};
   end
 endfunction
 wire [12:0] plus_one=bounded_move(command_us,14'sd1);
 wire [12:0] plus_base=bounded_move(command_us,STEP_US);
 wire [12:0] plus_far=bounded_move(command_us,FAR_STEP_US);
 wire [12:0] plus_sprint=bounded_move(command_us,SPRINT_STEP_US);
 wire [12:0] minus_one=bounded_move(command_us,-14'sd1);
 wire [12:0] minus_base=bounded_move(command_us,-STEP_US);
 wire [12:0] minus_far=bounded_move(command_us,-FAR_STEP_US);
 wire [12:0] minus_sprint=bounded_move(command_us,-SPRINT_STEP_US);
 reg [12:0] correction;
 always @*begin
   case({decision_negative^(DIRECTION<0),decision_step})
     3'd0:correction=plus_one;
     3'd1:correction=plus_base;
     3'd2:correction=plus_far;
     3'd3:correction=plus_sprint;
     3'd4:correction=minus_one;
     3'd5:correction=minus_base;
     3'd6:correction=minus_far;
     default:correction=minus_sprint;
   endcase
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   command_us<=1500;center_locked<=1;confirmation<=0;elapsed_frames<=UPDATE_FRAMES-1;
   pending<=0;pending_negative<=0;pending_step<=0;pending_wait<=0;
   candidate_negative<=0;last_negative<=0;have_direction<=0;
   have_observation<=0;previous_magnitude<=0;previous_negative<=0;
 end else if(clear || recenter)begin
   if(recenter)command_us<=1500;
   center_locked<=1;confirmation<=0;elapsed_frames<=UPDATE_FRAMES-1;pending<=0;
   pending_negative<=0;pending_step<=0;pending_wait<=0;
   candidate_negative<=0;last_negative<=0;have_direction<=0;
   have_observation<=0;previous_magnitude<=0;previous_negative<=0;
 end else begin
   if(frame_tick)begin
     if(elapsed_frames<UPDATE_FRAMES-1)elapsed_frames<=elapsed_frames+1'b1;
     // Consume only the latest sample from this PWM interval. Waiting samples
     // cannot cause a later command without new data after the wait interval.
     pending<=0;
     if(commit)begin
       command_us<=correction[11:0];
       if(correction[12])begin
         elapsed_frames<=0;
         last_negative<=decision_negative;have_direction<=1;
       end
     end
   end
   // A current sample wins over a boundary decision; central/opposite input
   // cannot be followed by a stale correction on that same clock edge.
   if(sample_valid)begin
     pending<=0;
     previous_magnitude<=magnitude;previous_negative<=sample_error[11];have_observation<=1;
     pending_step<=sample_step;pending_wait<=sample_wait;pending_negative<=sample_error[11];
     if(magnitude<=CENTER_BAND)begin
       center_locked<=1;confirmation<=0;
     end else if(center_locked && magnitude<=RELEASE_BAND)begin
       confirmation<=0;
     end else begin
       candidate_negative<=sample_error[11];
       if(!same_candidate)confirmation<=1;
       else if(confirmation<CONFIRM_SAMPLES)confirmation<=confirmation+1'b1;
       if(!center_locked || confirmed_now)begin
         center_locked<=0;pending<=1;
       end
     end
   end
   // A sample used on this edge must not become a second pending correction.
   if(commit)pending<=0;
 end
endmodule
