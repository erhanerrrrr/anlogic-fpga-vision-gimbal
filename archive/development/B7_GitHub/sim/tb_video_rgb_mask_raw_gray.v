`timescale 1ns/1ps
module tb_video_rgb_mask_raw_gray;
    parameter W=16,H=12,HT=16,VT=12,N=6,GUARD=1;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort_in=0,iv=0,s=0,l=0,e=0;
    reg [23:0] rgb=0;
    reg [10:0] x=0,y=0;
    reg [105:0] tag=0;
    wire ov,om,os,ol,oe,oa;
    wire [23:0] orgb,ogray;
    reg [7:0] expected_gray[0:N*W*H-1];
    integer gray_file;
    wire [10:0] ox,oy;
    wire [81:0] ot;
    wire [7:0] err;
    wire [15:0] used,peak;
    reg [24:0] pixels[0:N*W*H-1];
    reg [105:0] tags[0:N-1];
    integer i,j,k,n,seen=0,cycles=0,f,m,trace,oframe,offset,input_frame=0;
    integer input_eof[0:N-1];
    integer overlap=0;
    video_rgb_mask_raw_gray #(.WIDTH(W),.HEIGHT(H),.GUARD_ROWS(GUARD)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),
        .in_valid(iv),.in_sof(s),.in_eol(l),.in_eof(e),.in_rgb(rgb),.in_x(x),.in_y(y),
        .in_epoch(tag[105:74]),.in_frame_id(tag[73:42]),.in_cfg_id(tag[41:26]),
        .in_target_id(tag[25:24]),.min_main(tag[23:16]),.min_diff_1(tag[15:8]),.min_diff_2(tag[7:0]),
        .out_valid(ov),.out_raw_rgb(orgb),.out_gray_rgb(ogray),.out_mask(om),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_epoch(ot[81:50]),.out_frame_id(ot[49:18]),
        .out_cfg_id(ot[17:2]),.out_target_id(ot[1:0]),.out_abort(oa),
        .error_flags(err),.fifo_used(used),.fifo_peak(peak));
    always @(posedge clk)begin
        cycles=cycles+1;
        if(iv && e)input_eof[input_frame]=cycles;
        #1;
        if(rst_n)begin
            if(err || oa)$fatal(1,"Unexpected fault flags=%h cycle=%d x=%d y=%d",err,cycles,x,y);
            if(ov)begin
                if(seen>=N*W*H)$fatal(1,"Extra output");
                oframe=seen/(W*H);offset=seen%(W*H);
                if(orgb!==pixels[seen][24:1] || om!==pixels[seen][0] || ogray!=={3{expected_gray[seen]}})
                    $fatal(1,"Pixel mismatch index=%d RGB=%h expected=%h mask=%b expected=%b",seen,orgb,pixels[seen][24:1],om,pixels[seen][0]);
                if(ox!==offset%W || oy!==offset/W || ot!==tags[oframe][105:24] ||
                   os!==(offset==0) || ol!==(offset%W==W-1) || oe!==(offset==W*H-1))
                    $fatal(1,"Metadata mismatch index=%d",seen);
                $fwrite(f,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);
                $fwrite(m,"%c",om?8'd255:8'd0);$fwrite(gray_file,"%c",ogray[7:0]);
                if(os || ol || oe)$fwrite(trace,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",cycles,oframe,ox,oy,os,ol,oe,used,peak);
                if(oe && cycles-input_eof[oframe]!=W+5)
                    $fatal(1,"EOF delay unexpected: %d",cycles-input_eof[oframe]);
                if(iv && input_frame>oframe)overlap=overlap+1;
                seen=seen+1;
            end
        end
    end
    initial begin
        $readmemh("gray.mem",expected_gray);$readmemh("pixels.mem",pixels);$readmemh("tags.mem",tags);
        gray_file=$fopen("actual.gray","wb");f=$fopen("actual.rgb","wb");m=$fopen("actual.mask","wb");trace=$fopen("timing.csv","w");
        $fwrite(trace,"cycle,frame,x,y,sof,eol,eof,fifo_used,fifo_peak\n");
        repeat(3)@(negedge clk);rst_n=1;
        for(k=0;k<N;k=k+1)begin
            for(j=0;j<VT;j=j+1)for(i=0;i<HT;i=i+1)begin
                @(negedge clk);tag=tags[k];input_frame=k;iv=i<W && j<H;s=iv && i==0 && j==0;
                l=iv && i==W-1;e=l && j==H-1;x=iv?i:0;y=iv?j:0;
                rgb=iv?pixels[k*W*H+j*W+i][24:1]:24'd0;
            end
        end
        @(negedge clk);iv=0;s=0;l=0;e=0;
        repeat(2*W+32)@(negedge clk);
        if(seen!=N*W*H || used!=0)$fatal(1,"Missing pixels seen=%d used=%d",seen,used);
        if(peak>W+4)$fatal(1,"Unexpected FIFO peak %d",peak);
        if(HT==W && VT==H && overlap==0)$fatal(1,"No cross-frame tail overlap exercised");
        $fclose(gray_file);$fclose(f);$fclose(m);$fclose(trace);
        $display("PASS RAW_GRAY: frames=%0d pixels=%0d peak=%0d overlap=%0d eof_delay=%0d",N,seen,peak,overlap,W+5);
        $finish;
    end
    initial begin #200000000; $fatal(1,"Watchdog");end
endmodule
