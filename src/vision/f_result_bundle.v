// Publish geometry, classification and status as one completed result.
// The display never samples the CCL's transient busy signal.
module f_result_bundle #(parameter WIDTH=1280,HEIGHT=720,STABLE_EXTREMA=0)(
 input clk,rst_n,input_strobe,input_valid,input_source_ok,
 input [2:0] input_reason,input [31:0] input_id,
 input [15:0] input_cfg,input [1:0] input_color,
 input [1023:0] input_extrema,
 input [19:0] input_area,input [10:0] input_cx,input_cy,input_x0,input_x1,input_y0,input_y1,
 output reg publish,seen,result_valid,output reg [2:0] result_reason,
 output reg [31:0] result_id,output reg [15:0] result_cfg,
 output reg [1:0] result_color,object_class,
 output reg [19:0] result_area,output reg [10:0] cx,cy,x0,x1,y0,y1,
 output reg [6:0] fill
);
 reg waiting,held_valid,held_source_ok;
 reg [2:0] held_reason;
 reg [31:0] held_id;
 reg [15:0] held_cfg;
 reg [1:0] held_color;
 reg [19:0] held_area;
 reg [10:0] hcx,hcy,hx0,hx1,hy0,hy1;
 wire done,geometry_valid;
 wire shape_done,shape_valid;
 wire [31:0] shape_id;
 wire [1:0] shape_class;
 wire [6:0] metric_fill;
 reg geometry_ready,held_geometry_valid;
 reg [6:0] held_fill;
 f_shape_metrics #(.WIDTH(WIDTH),.STABLE_INPUT(STABLE_EXTREMA)) shape_metrics(.clk(clk),.rst_n(rst_n),.input_strobe(input_strobe),
 .input_id(input_id),.input_area(input_area),.input_extrema(input_extrema),
 .done(shape_done),.valid(shape_valid),.result_id(shape_id),.object_class(shape_class));
 wire [31:0] geometry_id;
 wire [11:0] width,height;
 h4c_fill_metrics #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) metrics(
 .clk(clk),.rst_n(rst_n),.input_strobe(input_strobe),.input_frame_id(input_id),.input_count(input_area),
 .input_xmin(input_x0),.input_xmax(input_x1),.input_ymin(input_y0),.input_ymax(input_y1),
 .result_strobe(done),.result_valid(geometry_valid),.result_frame_id(geometry_id),
 .box_width(width),.box_height(height),.fill_percent(metric_fill));
 wire valid_now=held_source_ok && held_valid && held_geometry_valid && shape_valid;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   geometry_ready<=0;held_geometry_valid<=0;held_fill<=0;fill<=0;waiting<=0;held_valid<=0;held_source_ok<=0;held_reason<=1;held_id<=0;held_cfg<=0;held_color<=0;held_area<=0;
   hcx<=0;hcy<=0;hx0<=0;hx1<=0;hy0<=0;hy1<=0;
   publish<=0;seen<=0;result_valid<=0;result_reason<=4;result_id<=0;result_cfg<=0;result_color<=0;object_class<=0;
   result_area<=0;cx<=0;cy<=0;x0<=0;x1<=0;y0<=0;y1<=0;
 end else begin
   publish<=0;
   if(waiting && done && geometry_id==held_id)begin
     geometry_ready<=1;held_geometry_valid<=geometry_valid;held_fill<=metric_fill;
   end
   if(input_strobe)begin
     geometry_ready<=0;waiting<=1;held_valid<=input_valid;held_source_ok<=input_source_ok;held_reason<=input_reason;
     held_id<=input_id;held_cfg<=input_cfg;held_color<=input_color;held_area<=input_area;
     hcx<=input_cx;hcy<=input_cy;hx0<=input_x0;hx1<=input_x1;hy0<=input_y0;hy1<=input_y1;
   end else if(waiting && geometry_ready && shape_done && shape_id==held_id)begin
     waiting<=0;publish<=1;seen<=1;fill<=valid_now?held_fill:0;
     result_id<=held_id;result_cfg<=held_cfg;result_color<=held_color;
     result_valid<=valid_now;
     result_reason<=!held_source_ok?3'd4:held_valid?((held_geometry_valid && shape_valid)?3'd0:3'd6):(held_reason==0?3'd6:held_reason);
     result_area<=valid_now?held_area:0;cx<=valid_now?hcx:0;cy<=valid_now?hcy:0;
     x0<=valid_now?hx0:0;x1<=valid_now?hx1:0;y0<=valid_now?hy0:0;y1<=valid_now?hy1:0;
     object_class<=valid_now?shape_class:2'd0;
   end
 end
endmodule
