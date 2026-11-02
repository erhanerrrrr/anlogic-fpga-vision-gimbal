// Source event crosses by toggle. Output pulse widths are 10us at 100MHz.
// These are internal pipeline markers, not exposure/optical latency probes.
module f2_markers #(parameter PULSE_CYCLES=1000)(
 input source_clk,clk,rst_n,source_sof,result_new,
 output reg source_mark,result_mark
);
 reg source_toggle;
 (* async_reg="true" *) reg meta,safe;
 reg last;
 reg [$clog2(PULSE_CYCLES+1)-1:0] source_left,result_left;
 always @(posedge source_clk or negedge rst_n)
 if(!rst_n)source_toggle<=0;else if(source_sof)source_toggle<=!source_toggle;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin meta<=0;safe<=0;last<=0;source_left<=0;result_left<=0;source_mark<=0;result_mark<=0;end
 else begin
   meta<=source_toggle;safe<=meta;last<=safe;
   if(safe!=last)source_left<=PULSE_CYCLES;else if(source_left!=0)source_left<=source_left-1'b1;
   if(result_new)result_left<=PULSE_CYCLES;else if(result_left!=0)result_left<=result_left-1'b1;
   source_mark<=source_left!=0;result_mark<=result_left!=0;
 end
endmodule
