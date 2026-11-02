`timescale 1ns/1ps
module tb_raw_gray_stage;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort_in=0,iv=0;
    reg [131:0] data=0;
    reg [7:0] gray=0;
    wire ov,oa;
    wire [23:0] raw,ogray;
    wire [107:0] meta;
    integer f,code,n=0,r,a,v;
    video_raw_gray_stage dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),.in_valid(iv),
        .in_rgb(data[23:0]),.in_mask(data[131]),.in_sof(data[130]),.in_eol(data[129]),.in_eof(data[128]),
        .in_x(data[127:117]),.in_y(data[116:106]),.in_epoch(data[105:74]),.in_frame_id(data[73:42]),
        .in_cfg_id(data[41:26]),.in_target_id(data[25:24]),
        .out_valid(ov),.out_raw_rgb(raw),.out_gray_rgb(ogray),
        .out_mask(meta[107]),.out_sof(meta[106]),.out_eol(meta[105]),.out_eof(meta[104]),
        .out_x(meta[103:93]),.out_y(meta[92:82]),.out_epoch(meta[81:50]),.out_frame_id(meta[49:18]),
        .out_cfg_id(meta[17:2]),.out_target_id(meta[1:0]),.out_abort(oa));
    initial begin
        f=$fopen("stage_vectors.txt","r");if(!f)$fatal(1,"Missing vectors");
        while(!$feof(f))begin
            @(negedge clk);
            code=$fscanf(f,"%d %d %d %h %h\n",r,a,v,data,gray);
            if(code!=5)$fatal(1,"Malformed vector");
            rst_n=r;abort_in=a;iv=v;
            if(!rst_n)begin #1;if(ov || raw || ogray || meta || oa)$fatal(1,"Async reset failed");end
            @(posedge clk);#1;
            if(ov!==(r && v && !a) || oa!==(r && a))$fatal(1,"Valid/abort timing mismatch %d",n);
            if(ov)begin
                if(raw!==data[23:0] || ogray!=={3{gray}} || meta!==data[131:24])
                    $fatal(1,"Stage pixel/metadata mismatch %d",n);
            end else if(raw || ogray || meta)$fatal(1,"Invalid outputs not cleared");
            n=n+1;
        end
        $fclose(f);$display("PASS RAW_GRAY_STAGE: vectors=%0d",n);$finish;
    end
endmodule
