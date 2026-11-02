// Exact 8-connected components with a bounded number of provisional labels.
// One pixel/clock, raster order; arbitrary valid gaps are supported.
// Labels are NOT recycled within a frame. Overflow rejects the whole frame.
// Two identical synchronous line RAMs provide upper / upper-right reads.
// Flat equivalence table: every merge rewrites all aliases in one clock.
// Statistics stay with provisional labels until a bounded EOF reduction.
module h4d_region_select #(
    parameter WIDTH=1280, HEIGHT=720, MAX_LABELS=32, LABEL_BITS=6,
    parameter MIN_AREA=256
)(
    input wire clk,rst_n,mask_valid,mask,sof,eof,
    input wire [10:0] x,y,
    input wire [31:0] frame_id,
    input wire [15:0] cfg_id,
    input wire [1:0] target_id,
    output reg result_strobe,target_valid,
    output reg [1:0] reason, // 0 accepted, 1 empty, 2 small, 3 label overflow
    output reg [31:0] result_frame_id,
    output reg [15:0] result_cfg_id,
    output reg [1:0] result_target_id,
    output reg [19:0] area,
    output reg [10:0] xmin,xmax,ymin,ymax,cx,cy,
    output reg [LABEL_BITS-1:0] labels_used,components,
    output wire busy
);
    reg [LABEL_BITS-1:0] line_u[0:WIDTH-1],line_r[0:WIDTH-1];
    reg [LABEL_BITS-1:0] up,right_up,upper_left,left_label;
    reg sv,sm,ss,se;
    reg [10:0] sx,sy;
    reg [31:0] sf;
    reg [15:0] sc;
    reg [1:0] st;
    reg in_frame;
    wire take=mask_valid && (in_frame || sof);
    reg [LABEL_BITS-1:0] canon[0:MAX_LABELS];
    reg [19:0] count[0:MAX_LABELS];
    reg [10:0] lo_x[0:MAX_LABELS],hi_x[0:MAX_LABELS];
    reg [10:0] lo_y[0:MAX_LABELS],hi_y[0:MAX_LABELS];
    reg [LABEL_BITS-1:0] allocated,index;
    reg overflow;
    localparam SCAN=0,FOLD=1,PICK=2,PUBLISH=3;
    reg [1:0] phase;
    assign busy=(phase!=SCAN);
    reg [31:0] held_frame;
    reg [15:0] held_cfg;
    reg [1:0] held_target;
    reg [LABEL_BITS-1:0] best,ncomponents;
    reg [LABEL_BITS-1:0] a,b,c,d,chosen;
    reg fresh;
    integer i;
    always @* begin
        a=0;b=0;c=0;d=0;chosen=0;fresh=0;
        if(!ss) begin
            if(sx!=0) a=canon[left_label];
            if(sy!=0)begin
                if(sx!=0)b=canon[upper_left];
                c=canon[up];
                if(sx!=WIDTH-1)d=canon[right_up];
            end
        end
        if(sm && !(overflow && !ss))begin
            chosen=a;
            if(b!=0 && (chosen==0 || b<chosen))chosen=b;
            if(c!=0 && (chosen==0 || c<chosen))chosen=c;
            if(d!=0 && (chosen==0 || d<chosen))chosen=d;
            if(chosen==0)begin
                fresh=1;
                if(ss)chosen=1;
                else if(allocated<MAX_LABELS)chosen=allocated+1'b1;
            end
        end
    end
    // Explicit duplicate RAMs: each copy has one synchronous read and one write.
    // Read data for row zero is deliberately ignored, so no RAM reset is needed.
    always @(posedge clk)begin
        if(rst_n && take)begin
            up<=line_u[x];
            right_up<=line_r[(x==WIDTH-1)?x:x+1'b1];
        end
        if(rst_n && sv && (phase==SCAN || ss))begin
            line_u[sx]<=chosen;
            line_r[sx]<=chosen;
        end
    end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            sv<=0;sm<=0;ss<=0;se<=0;sx<=0;sy<=0;sf<=0;sc<=0;st<=0;in_frame<=0;
        end else begin
            sv<=take;
            if(take)begin
                sm<=mask;ss<=sof;se<=eof;sx<=x;sy<=y;sf<=frame_id;sc<=cfg_id;st<=target_id;
                in_frame<=!eof;
            end
        end
    end
    // Separate the root lookup/merge path from the statistics update path.
    reg pv,ps,pe,pfresh;
    reg [LABEL_BITS-1:0] plabel;
    reg [10:0] px,py;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            pv<=0;ps<=0;pe<=0;pfresh<=0;plabel<=0;px<=0;py<=0;
        end else begin
            pv<=sv && (phase==SCAN || ss);
            if(sv && (phase==SCAN || ss))begin
                ps<=ss;pe<=se;pfresh<=fresh;plabel<=chosen;px<=sx;py<=sy;
            end
        end
    end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            allocated<=0;overflow<=0;left_label<=0;upper_left<=0;
            held_frame<=0;held_cfg<=0;held_target<=0;
            for(i=0;i<=MAX_LABELS;i=i+1)canon[i]<=0;
        end else if(sv && (phase==SCAN || ss))begin
            upper_left<=up;left_label<=chosen;
            if(ss)begin
                allocated<=0;overflow<=0;held_frame<=sf;held_cfg<=sc;held_target<=st;
                for(i=0;i<=MAX_LABELS;i=i+1)canon[i]<=0;
            end
            if(sm && !(overflow && !ss))begin
                if(chosen==0)overflow<=1;
                else if(fresh)begin allocated<=chosen;canon[chosen]<=chosen;end
                else if((a!=0 && a!=chosen)||(b!=0 && b!=chosen)||(c!=0 && c!=chosen)||(d!=0 && d!=chosen))begin
                    for(i=1;i<=MAX_LABELS;i=i+1)begin
                        if(canon[i]!=0 && (canon[i]==a || canon[i]==b || canon[i]==c || canon[i]==d))
                            canon[i]<=chosen;
                    end
                end
            end
        end
    end
    wire [LABEL_BITS-1:0] fold_root=canon[index];
    wire better=(count[index]>count[best]) ||
        (count[index]==count[best] &&
          ((lo_y[index]<lo_y[best]) || (lo_y[index]==lo_y[best] && lo_x[index]<lo_x[best])));
    integer j;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            phase<=SCAN;index<=1;best<=0;ncomponents<=0;
            result_strobe<=0;target_valid<=0;reason<=0;result_frame_id<=0;result_cfg_id<=0;result_target_id<=0;
            area<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;cx<=0;cy<=0;labels_used<=0;components<=0;
            for(j=0;j<=MAX_LABELS;j=j+1)begin
                count[j]<=0;lo_x[j]<=0;hi_x[j]<=0;lo_y[j]<=0;hi_y[j]<=0;
            end
        end else begin
            result_strobe<=0;
            // SOF interrupts an unfinished old frame, including EOF reduction.
            if(sv && ss)phase<=SCAN;
            else if(pv)begin
                if(ps)begin
                    phase<=SCAN;best<=0;ncomponents<=0;
                    for(j=0;j<=MAX_LABELS;j=j+1)begin
                        count[j]<=0;lo_x[j]<=0;hi_x[j]<=0;lo_y[j]<=0;hi_y[j]<=0;
                    end
                end
                if(plabel!=0)begin
                    if(pfresh)begin
                        count[plabel]<=1;lo_x[plabel]<=px;hi_x[plabel]<=px;lo_y[plabel]<=py;hi_y[plabel]<=py;
                    end else begin
                        count[plabel]<=count[plabel]+1'b1;
                        if(px<lo_x[plabel])lo_x[plabel]<=px;
                        if(px>hi_x[plabel])hi_x[plabel]<=px;
                        if(py<lo_y[plabel])lo_y[plabel]<=py;
                        if(py>hi_y[plabel])hi_y[plabel]<=py;
                    end
                end
                if(pe)begin phase<=FOLD;index<=1;best<=0;ncomponents<=0;end
            end else if(phase==FOLD)begin
                if(index<=allocated && fold_root!=index && count[index]!=0 && !overflow)begin
                    count[fold_root]<=count[fold_root]+count[index];count[index]<=0;
                    if(lo_x[index]<lo_x[fold_root])lo_x[fold_root]<=lo_x[index];
                    if(hi_x[index]>hi_x[fold_root])hi_x[fold_root]<=hi_x[index];
                    if(lo_y[index]<lo_y[fold_root])lo_y[fold_root]<=lo_y[index];
                    if(hi_y[index]>hi_y[fold_root])hi_y[fold_root]<=hi_y[index];
                end
                if(index==MAX_LABELS)begin phase<=PICK;index<=1;end
                else index<=index+1'b1;
            end else if(phase==PICK)begin
                if(index<=allocated && count[index]!=0 && !overflow)begin
                    ncomponents<=ncomponents+1'b1;
                    if(best==0 || better)best<=index;
                end
                if(index==MAX_LABELS)phase<=PUBLISH;
                else index<=index+1'b1;
            end else if(phase==PUBLISH)begin
                result_strobe<=1;phase<=SCAN;
                result_frame_id<=held_frame;result_cfg_id<=held_cfg;result_target_id<=held_target;
                labels_used<=allocated;components<=overflow?0:ncomponents;
                target_valid<=0;area<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;cx<=0;cy<=0;
                if(overflow)reason<=3;
                else if(best==0)reason<=1;
                else if(count[best]<MIN_AREA)reason<=2;
                else begin
                    target_valid<=1;reason<=0;area<=count[best];
                    xmin<=lo_x[best];xmax<=hi_x[best];ymin<=lo_y[best];ymax<=hi_y[best];
                    cx<=({1'b0,lo_x[best]}+{1'b0,hi_x[best]})>>1;
                    cy<=({1'b0,lo_y[best]}+{1'b0,hi_y[best]})>>1;
                end
            end
        end
    end
endmodule
