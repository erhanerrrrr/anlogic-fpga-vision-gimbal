`timescale 1ns/1ps
// Small raster tests the actual development selector -> packet wiring.
// MAX_RUNS=4 exercises capacity errors cheaply; production stays R64.
module tb_h4e_target_chain;
    localparam W=64,H=24,N=8,ROW_CYCLES=240;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,mv=0,m=0,sof=0,eof=0;
    reg [10:0] x=0,y=0;
    reg [31:0] fid=0;
    reg [15:0] cfg=0;
    reg [1:0] color=0;
    wire s,result_strobe;
    wire [191:0] sample,payload;
    assign sample[158:127]=32'd0;
    h4e_region_select #(.WIDTH(W),.HEIGHT(H),.MAX_RUNS(4)) region(
        .clk(clk),.rst_n(rst_n),.mask_valid(mv),.mask(m),.sof(sof),.eof(eof),
        .x(x),.y(y),.frame_id(fid),.cfg_id(cfg),.target_id(color),
        .result_strobe(s),.busy(),
        .target_valid(sample[191]),
        .result_frame_id(sample[190:159]),
        .result_cfg_id(sample[126:111]),
        .result_target_id(sample[110:109]),
        .area(sample[108:89]),
        .cx(sample[88:78]),
        .cy(sample[77:67]),
        .xmin(sample[66:56]),
        .xmax(sample[55:45]),
        .ymin(sample[44:34]),
        .ymax(sample[33:23]),
        .reason(sample[22:20]),
        .labels_used(sample[19:12]),
        .components(sample[11:0]));
    h4e_target_packet dut(.clk(clk),.rst_n(rst_n),.t_result_strobe(s),
        .t_target_valid(sample[191]),
        .t_frame_id(sample[190:159]),
        .t_capture_epoch(sample[158:127]),
        .t_cfg_id(sample[126:111]),
        .t_target_id(sample[110:109]),
        .t_area(sample[108:89]),
        .t_cx(sample[88:78]),
        .t_cy(sample[77:67]),
        .t_xmin(sample[66:56]),
        .t_xmax(sample[55:45]),
        .t_ymin(sample[44:34]),
        .t_ymax(sample[33:23]),
        .t_reason(sample[22:20]),
        .t_peak_slots(sample[19:12]),
        .t_component_count(sample[11:0]),
        .result_strobe(result_strobe),
        .target_valid(payload[191]),
        .frame_id(payload[190:159]),
        .capture_epoch(payload[158:127]),
        .cfg_id(payload[126:111]),
        .target_id(payload[110:109]),
        .area(payload[108:89]),
        .cx(payload[88:78]),
        .cy(payload[77:67]),
        .xmin(payload[66:56]),
        .xmax(payload[55:45]),
        .ymin(payload[44:34]),
        .ymax(payload[33:23]),
        .reject_reason(payload[22:20]),
        .peak_slots(payload[19:12]),
        .component_count(payload[11:0]));
    reg masks[0:N*W*H-1];
    reg [49:0] metadata[0:N-1];
    reg [191:0] expected_payload=0;
    reg expected_strobe;
    integer f,yy,xx,k,cycle=0,count=0,dst;
    always @(posedge clk) begin
        cycle=cycle+1;
        expected_strobe=rst_n && s;
        if(!rst_n) expected_payload=0;
        else if(s) expected_payload=sample;
        #1;
        if({result_strobe,payload}!=={expected_strobe,expected_payload})
            $fatal(1,"selector-to-packet latency/atomicity mismatch cycle %0d",cycle);
        if(result_strobe) begin
            count=count+1;
            $fdisplay(dst,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,result_strobe,payload[191],payload[190:159],payload[158:127],payload[126:111],payload[110:109],payload[108:89],payload[88:78],payload[77:67],payload[66:56],payload[55:45],payload[44:34],payload[33:23],payload[22:20],payload[19:12],payload[11:0]);
        end
    end
    initial begin #1000000; $fatal(1,"chain watchdog"); end
    initial begin
        $readmemb("chain_masks.mem",masks);
        $readmemh("chain_metadata.mem",metadata);
        dst=$fopen("chain_actual.csv","w");
        if(!dst) $fatal(1,"chain file open");
        $fdisplay(dst,"cycle,result_strobe,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count");
        repeat(3) @(negedge clk); rst_n=1;
        for(f=0;f<N;f=f+1) begin
            for(yy=0;yy<H;yy=yy+1) begin
                for(xx=0;xx<W;xx=xx+1) begin
                    @(negedge clk);
                    mv=1; x=xx; y=yy;
                    sof=(xx==0 && yy==0); eof=(xx==W-1 && yy==H-1);
                    m=masks[f*W*H+yy*W+xx];
                    // Live values are deliberately wrong after SOF.
                    {fid,cfg,color}=sof?metadata[f]:~metadata[f];
                end
                for(k=W;k<ROW_CYCLES;k=k+1) begin
                    @(negedge clk); mv=0;sof=0;eof=0;m=0;
                    {fid,cfg,color}=~metadata[f];
                end
            end
        end
        repeat(80) @(negedge clk);
        if(count!=N) $fatal(1,"wrong packet event count %0d",count);
        $fclose(dst); $display("H4E_C2A_CHAIN_COMPLETE events=%0d",count); $finish;
    end
endmodule
