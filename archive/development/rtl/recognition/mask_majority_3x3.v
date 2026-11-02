// Full W*H mask stream, 5-of-9 majority, final outer border forced to zero.
// Two alternating row RAMs; synchronous read-before-write, no RAM reset.
// Supported legal input: WIDTH/HEIGHT >= 3, raster order, no in-line gaps.
module mask_majority_3x3 #(
    parameter WIDTH=1280,HEIGHT=720,X_WIDTH=11,Y_WIDTH=11,FRAME_WIDTH=32,CFG_WIDTH=16
)(
    input wire clk,rst_n,mask_valid,mask,
    input wire [X_WIDTH-1:0] x,
    input wire [Y_WIDTH-1:0] y,
    input wire sof,eof,
    input wire [FRAME_WIDTH-1:0] source_frame_id,
    input wire [CFG_WIDTH-1:0] cfg_id,
    input wire [1:0] target_id,
    output reg out_valid,out_mask,
    output reg [X_WIDTH-1:0] out_x,
    output reg [Y_WIDTH-1:0] out_y,
    output reg out_sof,out_eol,out_eof,
    output reg [FRAME_WIDTH-1:0] out_frame_id,
    output reg [CFG_WIDTH-1:0] out_cfg_id,
    output reg [1:0] out_target_id
);
    reg row0[0:WIDTH-1],row1[0:WIDTH-1];
    reg rd0,rd1;
    reg in_frame;
    wire accept_pixel=mask_valid && (in_frame || sof);
    // Do not reset these memories/read registers: unread history is qualified below.
    always @(posedge clk) begin
        if (rst_n && accept_pixel) begin
            rd0<=row0[x];rd1<=row1[x];
            if (y[0]) row1[x]<=mask; else row0[x]<=mask;
        end
    end
    reg s_valid,s_mask,s_eof;
    reg [X_WIDTH-1:0] sx;
    reg [Y_WIDTH-1:0] sy;
    reg [FRAME_WIDTH-1:0] sf;
    reg [CFG_WIDTH-1:0] sc;
    reg [1:0] st;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            in_frame<=0;s_valid<=0;s_mask<=0;s_eof<=0;sx<=0;sy<=0;sf<=0;sc<=0;st<=0;
        end else begin
            s_valid<=accept_pixel;
            if(accept_pixel) begin
                in_frame<=!eof;s_mask<=mask;s_eof<=eof;sx<=x;sy<=y;
                sf<=source_frame_id;sc<=cfg_id;st<=target_id;
            end
        end
    end
    wire top_value=(sy>=2) ? (sy[0]?rd1:rd0) : 1'b0;
    wire mid_value=(sy>=1) ? (sy[0]?rd0:rd1) : 1'b0;
    reg t1,t2,m1,m2,b1,b2;
    wire [3:0] total={3'b0,t2}+{3'b0,t1}+{3'b0,top_value}+
        {3'b0,m2}+{3'b0,m1}+{3'b0,mid_value}+
        {3'b0,b2}+{3'b0,b1}+{3'b0,s_mask};
    reg edge_pending,tail_pending;
    reg [Y_WIDTH-1:0] edge_y;
    reg [X_WIDTH:0] tail_index;
    reg [FRAME_WIDTH-1:0] pending_frame;
    reg [CFG_WIDTH-1:0] pending_cfg;
    reg [1:0] pending_target;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            t1<=0;t2<=0;m1<=0;m2<=0;b1<=0;b2<=0;
            edge_pending<=0;tail_pending<=0;edge_y<=0;tail_index<=0;
            pending_frame<=0;pending_cfg<=0;pending_target<=0;
            out_valid<=0;out_mask<=0;out_x<=0;out_y<=0;out_sof<=0;out_eol<=0;out_eof<=0;
            out_frame_id<=0;out_cfg_id<=0;out_target_id<=0;
        end else begin
            out_valid<=0;out_mask<=0;out_x<=0;out_y<=0;out_sof<=0;out_eol<=0;out_eof<=0;
            out_frame_id<=0;out_cfg_id<=0;out_target_id<=0;
            // Window state can advance while the previous frame's border is flushed.
            if(s_valid) begin
                t1<=top_value;m1<=mid_value;b1<=s_mask;
                t2<=(sx==0)?1'b0:t1;m2<=(sx==0)?1'b0:m1;b2<=(sx==0)?1'b0:b1;
            end
            if(tail_pending) begin
                out_valid<=1;out_mask<=0;
                out_x<=(tail_index==0)?WIDTH-1:tail_index-1'b1;
                out_y<=(tail_index==0)?HEIGHT-2:HEIGHT-1;
                out_eol<=(tail_index==0 || tail_index==WIDTH);
                out_eof<=(tail_index==WIDTH);
                out_frame_id<=pending_frame;out_cfg_id<=pending_cfg;out_target_id<=pending_target;
                if(tail_index==WIDTH) begin tail_pending<=0;tail_index<=0;end
                else tail_index<=tail_index+1'b1;
            end else if(edge_pending) begin
                out_valid<=1;out_x<=WIDTH-1;out_y<=edge_y;out_eol<=1;
                out_frame_id<=pending_frame;out_cfg_id<=pending_cfg;out_target_id<=pending_target;
                edge_pending<=0;
            end else if(s_valid && sy>=1 && sx>=1) begin
                out_valid<=1;out_x<=sx-1'b1;out_y<=sy-1'b1;
                out_sof<=(sx==1 && sy==1);
                out_mask<=(sy>=2 && sx>=2) && (total>=5);
                out_frame_id<=sf;out_cfg_id<=sc;out_target_id<=st;
            end
            if(s_valid && sy>=1 && sx==WIDTH-1) begin
                pending_frame<=sf;pending_cfg<=sc;pending_target<=st;
                if(s_eof) begin tail_pending<=1;tail_index<=0;end
                else begin edge_pending<=1;edge_y<=sy-1'b1;end
            end
        end
    end
endmodule
