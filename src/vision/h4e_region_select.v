// Exact 8-connected run CCL with row-by-row label compaction.
// Single shared arithmetic engine; region tables and three run lists are RAMs.
// Completed regions are retained through a monotonic largest-region snapshot.
// Requires the previous row job to finish before the next input row completes.
module h4e_region_select #(
    parameter WIDTH=1280,HEIGHT=720,MAX_RUNS=64,MIN_AREA=256
)(
    input wire clk,rst_n,mask_valid,mask,sof,eof,
    input wire [10:0] x,y,
    input wire [31:0] frame_id,
    input wire [15:0] cfg_id,
    input wire [1:0] target_id,
    output reg result_strobe,target_valid,
    output reg [2:0] reason, // 0 accepted,1 empty,2 small,3 capacity,5 row deadline
    output reg [31:0] result_frame_id,
    output reg [15:0] result_cfg_id,
    output reg [1:0] result_target_id,
    output reg [19:0] area,
    output reg [10:0] xmin,xmax,ymin,ymax,cx,cy,
    output reg [7:0] labels_used, // peak working slots, recycled each row
    output reg [11:0] components, // full-frame count, saturates at FFF
    output wire busy
);
    localparam MAX_SLOTS=2*MAX_RUNS;
    localparam IDLE=0,C_READ=1,C_WAIT=2,P_READ=3,P_WAIT=4,
        ROOT_READ=5,ROOT_WAIT=6,ACC_READ=7,ACC_WAIT=8,
        MERGE_LOSE=9,MERGE_WIN=10,AFTER_OVERLAP=11,
        ADD_START=12,ADD_READ=13,ADD_WAIT=14,ADD_WRITE=15,RUN_WRITE=16,
        CP_READ=17,CP_WAIT=18,CP_MAP=19,CP_COPY=20,CP_RUN=21,ROW_DONE=22;
    reg [4:0] state;
    assign busy=(state!=IDLE);

    // Input run encoder. No full-frame mask storage, no backpressure.
    reg in_frame,run_open;
    reg [10:0] run_start;
    reg [6:0] run_count;
    reg [1:0] cap_bank;
    reg [2:0] cap_fault;
    reg row_event,row_last;
    reg [1:0] event_bank;
    reg [6:0] event_count;
    reg [10:0] event_y;
    wire take=mask_valid && (in_frame || sof);
    wire open_now=sof?1'b0:run_open;
    wire [6:0] count_now=sof?7'd0:run_count;
    wire close_run=take && ((open_now && !mask) || (mask && x==WIDTH-1));
    wire [10:0] close_start=open_now?run_start:x;
    wire [10:0] close_end=mask?x:x-1'b1;
    wire cap_we=close_run && count_now<MAX_RUNS && (cap_fault==0 || sof);
    wire [29:0] cap_data={8'd0,close_end,close_start};
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            in_frame<=0;run_open<=0;run_start<=0;run_count<=0;cap_bank<=0;cap_fault<=0;
            row_event<=0;row_last<=0;event_bank<=0;event_count<=0;event_y<=0;
        end else begin
            row_event<=0;
            if(take)begin
                in_frame<=!eof;
                if(sof)begin run_count<=0;run_open<=0;cap_bank<=0;cap_fault<=0;end
                if(mask && !open_now)begin run_start<=x;run_open<=1;end
                if(close_run)begin
                    run_open<=0;
                    if(count_now<MAX_RUNS)run_count<=count_now+1'b1;
                    else cap_fault<=3;
                end
                if(x==WIDTH-1)begin
                    row_event<=1;event_y<=y;event_bank<=cap_bank;row_last<=eof;
                    event_count<=count_now+((close_run && count_now<MAX_RUNS)?1'b1:1'b0);
                    cap_bank<=(cap_bank==2)?0:cap_bank+1'b1;
                    run_count<=0;run_open<=0;
                end
            end
        end
    end

    // One read and one write port on each run RAM. 8-bit label, 11-bit endpoints.
    reg [29:0] runs0[0:MAX_RUNS-1],runs1[0:MAX_RUNS-1],runs2[0:MAX_RUNS-1];
    reg [29:0] rq0,rq1,rq2;
    reg [1:0] cur_bank,prev_bank;
    reg [6:0] ci,pi,cur_count,prev_count;
    reg [10:0] row_y,cur_lo,cur_hi,prev_hi;
    reg final_row,compact_mode,table_bank;
    reg [7:0] cur_label,slots,prev_live,new_live,peak_slots,root_key,copy_id;
    reg [3:0] root_depth;
    reg [2:0] engine_fault;
    wire [2:0] fault=(cap_fault!=0)?cap_fault:engine_fault;
    wire [6:0] run_ra=(state==P_READ)?pi:ci;
    wire [1:0] run_rb=(state==P_READ || state==P_WAIT)?prev_bank:cur_bank;
    wire [29:0] run_q=(run_rb==0)?rq0:((run_rb==1)?rq1:rq2);
    wire eng_run_we=(state==RUN_WRITE || state==CP_RUN) && fault==0 && !sof;
    wire [29:0] eng_run_data={(state==CP_RUN)?copy_id:cur_label,cur_hi,cur_lo};
    always @(posedge clk)begin
        rq0<=runs0[run_ra];rq1<=runs1[run_ra];rq2<=runs2[run_ra];
        if(rst_n)begin
            if(cap_we && cap_bank==0)runs0[count_now]<=cap_data;
            else if(eng_run_we && cur_bank==0)runs0[ci]<=eng_run_data;
            if(cap_we && cap_bank==1)runs1[count_now]<=cap_data;
            else if(eng_run_we && cur_bank==1)runs1[ci]<=eng_run_data;
            if(cap_we && cap_bank==2)runs2[count_now]<=cap_data;
            else if(eng_run_we && cur_bank==2)runs2[ci]<=eng_run_data;
        end
    end

    // Record: {next-row ID[8],rank[4],parent[8],ymax,ymin,xmax,xmin,area[20]}.
    // Two banks alternate at row completion. Old slots need no clearing.
    reg [83:0] records[0:511];
    reg [83:0] rec_q,found_rec,loser_rec,merged_rec,add_rec,copy_rec;
    reg [7:0] found_id,loser_id,winner_id;
    reg add_new;
    reg [8:0] mem_ra,mem_wa;
    reg mem_we;
    reg [83:0] mem_wd;
    always @* begin
        mem_ra={table_bank,root_key};
        if(state==ACC_READ || state==ADD_READ)mem_ra={table_bank,cur_label};
        mem_we=0;mem_wa=0;mem_wd=0;
        case(state)
            MERGE_LOSE:begin mem_we=1;mem_wa={table_bank,loser_id};mem_wd=loser_rec;end
            MERGE_WIN:begin mem_we=1;mem_wa={table_bank,winner_id};mem_wd=merged_rec;end
            ADD_WRITE:begin mem_we=1;mem_wa={table_bank,cur_label};mem_wd=add_rec;end
            CP_MAP:begin mem_we=1;mem_wa={table_bank,found_id};mem_wd=found_rec;end
            CP_COPY:begin mem_we=1;mem_wa={!table_bank,copy_id};mem_wd=copy_rec;end
        endcase
        if(fault!=0 || sof)mem_we=0;
    end
    always @(posedge clk)begin
        rec_q<=records[mem_ra];
        if(rst_n && mem_we)records[mem_wa]<=mem_wd;
    end
    function [10:0] mn;
        input [10:0] a,b;begin mn=(a<b)?a:b;end
    endfunction
    function [10:0] mx;
        input [10:0] a,b;begin mx=(a>b)?a:b;end
    endfunction
    function [63:0] union_geometry;
        input [63:0] a,b;
        begin union_geometry={mx(a[63:53],b[63:53]),mn(a[52:42],b[52:42]),
            mx(a[41:31],b[41:31]),mn(a[30:20],b[30:20]),(a[19:0]+b[19:0])};end
    endfunction
    wire [19:0] run_area={9'd0,cur_hi}-{9'd0,cur_lo}+20'd1;
    wire [63:0] run_geometry={row_y,row_y,cur_hi,cur_lo,run_area};
    reg [63:0] best_geometry;
    reg [19:0] component_count;
    reg [31:0] held_frame;
    reg [15:0] held_cfg;
    reg [1:0] held_target;
    wire better=(add_rec[19:0]>best_geometry[19:0]) ||
        (add_rec[19:0]==best_geometry[19:0] &&
            (add_rec[52:42]<best_geometry[52:42] ||
              (add_rec[52:42]==best_geometry[52:42] && add_rec[30:20]<best_geometry[30:20])));
    task publish_error;
        input [2:0] why;
        begin
            result_strobe<=1;target_valid<=0;reason<=why;
            result_frame_id<=held_frame;result_cfg_id<=held_cfg;result_target_id<=held_target;
            area<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;cx<=0;cy<=0;
            labels_used<=peak_slots;components<=0;
        end
    endtask
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state<=IDLE;cur_bank<=0;prev_bank<=2;ci<=0;pi<=0;cur_count<=0;prev_count<=0;
            row_y<=0;cur_lo<=0;cur_hi<=0;prev_hi<=0;final_row<=0;compact_mode<=0;table_bank<=0;
            cur_label<=0;slots<=0;prev_live<=0;new_live<=0;peak_slots<=0;root_key<=0;copy_id<=0;root_depth<=0;
            engine_fault<=0;found_rec<=0;loser_rec<=0;merged_rec<=0;add_rec<=0;copy_rec<=0;
            found_id<=0;loser_id<=0;winner_id<=0;add_new<=0;best_geometry<=0;component_count<=0;
            held_frame<=0;held_cfg<=0;held_target<=0;
            result_strobe<=0;target_valid<=0;reason<=0;result_frame_id<=0;result_cfg_id<=0;result_target_id<=0;
            area<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;cx<=0;cy<=0;labels_used<=0;components<=0;
        end else begin
            result_strobe<=0;
            if(take && sof)begin
                state<=IDLE;prev_count<=0;prev_live<=0;table_bank<=0;prev_bank<=2;
                peak_slots<=0;engine_fault<=0;best_geometry<=0;component_count<=0;
                held_frame<=frame_id;held_cfg<=cfg_id;held_target<=target_id;
            end else if(row_event && (fault!=0 || state!=IDLE))begin
                state<=IDLE;
                if(fault==0)engine_fault<=5;
                if(row_last)publish_error((fault==0)?3'd5:fault);
            end else if(fault!=0)state<=IDLE;
            else case(state)
                IDLE:if(row_event)begin
                    cur_bank<=event_bank;cur_count<=event_count;row_y<=event_y;final_row<=row_last;
                    ci<=0;pi<=0;slots<=prev_live;new_live<=0;compact_mode<=0;
                    state<=(event_count==0)?ROW_DONE:C_READ;
                end
                C_READ:state<=C_WAIT;
                C_WAIT:begin
                    cur_lo<=run_q[10:0];cur_hi<=run_q[21:11];cur_label<=0;
                    state<=(pi>=prev_count)?ADD_START:P_READ;
                end
                P_READ:state<=P_WAIT;
                P_WAIT:begin
                    if({1'b0,run_q[21:11]}+12'd1 < {1'b0,cur_lo})begin
                        pi<=pi+1'b1;state<=(pi+1>=prev_count)?ADD_START:P_READ;
                    end else if({1'b0,run_q[10:0]} > {1'b0,cur_hi}+12'd1)state<=ADD_START;
                    else begin
                        prev_hi<=run_q[21:11];root_key<=run_q[29:22];root_depth<=0;
                        compact_mode<=0;state<=ROOT_READ;
                    end
                end
                ROOT_READ:state<=ROOT_WAIT;
                ROOT_WAIT:begin
                    if(rec_q[71:64]!=root_key)begin
                        root_key<=rec_q[71:64];root_depth<=root_depth+1'b1;state<=ROOT_READ;
                        if(root_depth>=8 || rec_q[71:64]==0)engine_fault<=5;
                    end else if(compact_mode)begin
                        if(rec_q[83:76]!=0)begin copy_id<=rec_q[83:76];state<=CP_RUN;end
                        else begin
                            new_live<=new_live+1'b1;copy_id<=new_live+1'b1;
                            found_id<=root_key;found_rec<={new_live+8'd1,rec_q[75:0]};
                            copy_rec<={8'd0,4'd0,new_live+8'd1,rec_q[63:0]};
                            state<=CP_MAP;
                            if(new_live>=MAX_RUNS)engine_fault<=3;
                        end
                    end else begin
                        found_id<=root_key;found_rec<=rec_q;
                        if(cur_label==0)begin cur_label<=root_key;state<=AFTER_OVERLAP;end
                        else if(cur_label==root_key)state<=AFTER_OVERLAP;
                        else state<=ACC_READ;
                    end
                end
                ACC_READ:state<=ACC_WAIT;
                ACC_WAIT:begin
                    // Union by rank bounds parent depth; no wide alias fanout.
                    if(rec_q[75:72]>=found_rec[75:72])begin
                        winner_id<=cur_label;loser_id<=found_id;
                        loser_rec<={8'd0,found_rec[75:72],cur_label,found_rec[63:0]};
                        merged_rec<={8'd0,rec_q[75:72]+((rec_q[75:72]==found_rec[75:72])?4'd1:4'd0),
                                     cur_label,union_geometry(rec_q[63:0],found_rec[63:0])};
                    end else begin
                        winner_id<=found_id;loser_id<=cur_label;
                        loser_rec<={8'd0,rec_q[75:72],found_id,rec_q[63:0]};
                        merged_rec<={8'd0,found_rec[75:72],found_id,union_geometry(rec_q[63:0],found_rec[63:0])};
                    end
                    state<=MERGE_LOSE;
                end
                MERGE_LOSE:state<=MERGE_WIN;
                MERGE_WIN:begin cur_label<=winner_id;component_count<=component_count-1'b1;state<=AFTER_OVERLAP;end
                AFTER_OVERLAP:begin
                    if(prev_hi<=cur_hi)begin pi<=pi+1'b1;state<=(pi+1>=prev_count)?ADD_START:P_READ;end
                    else state<=ADD_START;
                end
                ADD_START:begin
                    if(cur_label==0)begin
                        if(slots>=MAX_SLOTS)engine_fault<=3;
                        else begin
                            slots<=slots+1'b1;cur_label<=slots+1'b1;
                            if(slots+1>peak_slots)peak_slots<=slots+1'b1;
                            add_rec<={8'd0,4'd0,slots+8'd1,run_geometry};add_new<=1;state<=ADD_WRITE;
                        end
                    end else begin add_new<=0;state<=ADD_READ;end
                end
                ADD_READ:state<=ADD_WAIT;
                ADD_WAIT:begin add_rec<={8'd0,rec_q[75:72],cur_label,union_geometry(rec_q[63:0],run_geometry)};state<=ADD_WRITE;end
                ADD_WRITE:begin
                    if(add_new)component_count<=component_count+1'b1;
                    if(better)best_geometry<=add_rec[63:0];
                    state<=RUN_WRITE;
                end
                RUN_WRITE:begin
                    if(ci+1>=cur_count)begin ci<=0;new_live<=0;state<=CP_READ;end
                    else begin ci<=ci+1'b1;state<=C_READ;end
                end
                CP_READ:state<=CP_WAIT;
                CP_WAIT:begin
                    cur_lo<=run_q[10:0];cur_hi<=run_q[21:11];root_key<=run_q[29:22];root_depth<=0;
                    compact_mode<=1;state<=ROOT_READ;
                end
                CP_MAP:state<=CP_COPY;
                CP_COPY:state<=CP_RUN;
                CP_RUN:begin
                    if(ci+1>=cur_count)state<=ROW_DONE;
                    else begin ci<=ci+1'b1;state<=CP_READ;end
                end
                ROW_DONE:begin
                    prev_bank<=cur_bank;prev_count<=cur_count;prev_live<=new_live;table_bank<=!table_bank;state<=IDLE;
                    if(final_row)begin
                        result_strobe<=1;target_valid<=0;reason<=1;
                        result_frame_id<=held_frame;result_cfg_id<=held_cfg;result_target_id<=held_target;
                        labels_used<=peak_slots;components<=(component_count>4095)?12'hfff:component_count[11:0];
                        area<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;cx<=0;cy<=0;
                        if(best_geometry[19:0]!=0)begin
                            if(best_geometry[19:0]<MIN_AREA)reason<=2;
                            else begin
                                target_valid<=1;reason<=0;area<=best_geometry[19:0];
                                xmin<=best_geometry[30:20];xmax<=best_geometry[41:31];
                                ymin<=best_geometry[52:42];ymax<=best_geometry[63:53];
                                cx<=({1'b0,best_geometry[30:20]}+{1'b0,best_geometry[41:31]})>>1;
                                cy<=({1'b0,best_geometry[52:42]}+{1'b0,best_geometry[63:53]})>>1;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule
