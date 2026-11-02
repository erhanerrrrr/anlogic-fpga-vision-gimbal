`timescale 1ns/1ps
module tb_video_four_mode_stream;
    parameter W=16,H=12,HT=16,VT=12,N=6,GUARD=1,TH=128,MODE_SHIFT=0;
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
    wire [15:0] err;
    reg [1:0] mode=0;wire [1:0] out_mode;wire [23:0] selected,mask_rgb;integer selected_file;
    function [1:0] frame_mode;input integer f;begin
        case(f%6)0:frame_mode=0;1:frame_mode=3;2:frame_mode=3;3:frame_mode=2;4:frame_mode=1;default:frame_mode=0;endcase
        frame_mode=frame_mode+MODE_SHIFT;end endfunction
    wire ev,es,el,ee;wire [23:0] ergb;wire [10:0] ex,ey;wire [81:0] et;
    reg [7:0] expected_edge[0:N*W*H-1];
    integer edge_file,edge_seen=0,edge_frame,edge_offset,edge_overlap=0;
    wire [15:0] used,peak;
    reg [24:0] pixels[0:N*W*H-1];
    reg [105:0] tags[0:N-1];
    integer i,j,k,n,seen=0,cycles=0,f,m,trace,oframe,offset,input_frame=0;
    integer input_eof[0:N-1];
    integer overlap=0;
    video_four_mode_stream #(.WIDTH(W),.HEIGHT(H),.GUARD_ROWS(GUARD),.THRESHOLD(TH)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),
        .in_valid(iv),.in_sof(s),.in_eol(l),.in_eof(e),.in_rgb(rgb),.in_x(x),.in_y(y),
        .in_epoch(tag[105:74]),.in_frame_id(tag[73:42]),.in_cfg_id(tag[41:26]),
        .in_target_id(tag[25:24]),.in_mode(mode),.min_main(tag[23:16]),.min_diff_1(tag[15:8]),.min_diff_2(tag[7:0]),
        .out_valid(ov),.out_raw_rgb(orgb),.out_gray_rgb(ogray),.out_mask_rgb(mask_rgb),.out_edge_rgb(ergb),
        .out_rgb(selected),.out_mode(out_mode),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_epoch(ot[81:50]),.out_frame_id(ot[49:18]),
        .out_cfg_id(ot[17:2]),.out_target_id(ot[1:0]),.out_abort(oa),
        .error_flags(err),.fifo_used(used),.fifo_peak(peak));
    assign ev=ov;assign ex=ox;assign ey=oy;assign et=ot;assign es=os;assign el=ol;assign ee=oe;assign om=mask_rgb[0];
    always @(posedge clk)begin
        cycles=cycles+1;
        if(iv && e)input_eof[input_frame]=cycles;
        #1;
        if(rst_n)begin
            if(err || oa)$fatal(1,"Unexpected fault flags=%h cycle=%d x=%d y=%d align=%b mode=%b desc=%b pv/ev=%b/%b pxy=%d/%d exy=%d/%d",err,cycles,x,y,dut.alignment_bad,dut.mode_bad,dut.descriptor_bad,dut.pv,dut.ev,dut.px,dut.py,dut.ex,dut.ey);
            if(ev)begin
                if(edge_seen>=N*W*H)$fatal(1,"Extra EDGE output");
                edge_frame=edge_seen/(W*H);edge_offset=edge_seen%(W*H);
                if(ergb!=={3{expected_edge[edge_seen]}})$fatal(1,"EDGE pixel mismatch index=%d actual=%h expected=%h",edge_seen,ergb,expected_edge[edge_seen]);
                if(ex!==edge_offset%W || ey!==edge_offset/W || et!==tags[edge_frame][105:24] ||
                    es!==(edge_offset==0) || el!==(edge_offset%W==W-1) || ee!==(edge_offset==W*H-1))
                    $fatal(1,"EDGE metadata mismatch index=%d",edge_seen);
                if(ee && cycles-input_eof[edge_frame]!=W+5)$fatal(1,"EDGE EOF delay %d",cycles-input_eof[edge_frame]);
                $fwrite(edge_file,"%c",ergb[7:0]);
                if(es || el || ee)$fwrite(trace,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",cycles,edge_frame,ex,ey,es,el,ee,used,peak);
                if(iv && input_frame>edge_frame)edge_overlap=edge_overlap+1;
                edge_seen=edge_seen+1;
            end
            if(ov)begin
                if(seen>=N*W*H)$fatal(1,"Extra output");
                oframe=seen/(W*H);offset=seen%(W*H);
                if(out_mode!==frame_mode(oframe))$fatal(1,"Mode tag mismatch");
                if(mask_rgb!=={24{pixels[seen][0]}})$fatal(1,"MASK RGB mismatch");
                case(frame_mode(oframe))
                    0:if(selected!==pixels[seen][24:1])$fatal(1,"Selected RAW mismatch");
                    1:if(selected!=={3{expected_gray[seen]}})$fatal(1,"Selected GRAY mismatch");
                    2:if(selected!=={3{expected_edge[seen]}})$fatal(1,"Selected EDGE mismatch");
                    3:if(selected!=={24{pixels[seen][0]}})$fatal(1,"Selected MASK mismatch");
                endcase
                $fwrite(selected_file,"%c%c%c",selected[23:16],selected[15:8],selected[7:0]);
                if(orgb!==pixels[seen][24:1] || om!==pixels[seen][0] || ogray!=={3{expected_gray[seen]}})
                    $fatal(1,"Pixel mismatch index=%d RGB=%h expected=%h mask=%b expected=%b",seen,orgb,pixels[seen][24:1],om,pixels[seen][0]);
                if(ox!==offset%W || oy!==offset/W || ot!==tags[oframe][105:24] ||
                   os!==(offset==0) || ol!==(offset%W==W-1) || oe!==(offset==W*H-1))
                    $fatal(1,"Metadata mismatch index=%d",seen);
                $fwrite(f,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);
                $fwrite(m,"%c",om?8'd255:8'd0);$fwrite(gray_file,"%c",ogray[7:0]);
                if(oe && cycles-input_eof[oframe]!=W+5)
                    $fatal(1,"EOF delay unexpected: %d",cycles-input_eof[oframe]);
                if(iv && input_frame>oframe)overlap=overlap+1;
                seen=seen+1;
            end
        end
    end
    initial begin
        $readmemh("edge.mem",expected_edge);$readmemh("gray.mem",expected_gray);$readmemh("pixels.mem",pixels);$readmemh("tags.mem",tags);
        selected_file=$fopen("actual.selected","wb");edge_file=$fopen("actual.edge","wb");gray_file=$fopen("actual.gray","wb");f=$fopen("actual.rgb","wb");m=$fopen("actual.mask","wb");trace=$fopen("timing.csv","w");
        $fwrite(trace,"cycle,frame,x,y,sof,eol,eof,fifo_used,fifo_peak\n");
        repeat(3)@(negedge clk);rst_n=1;
        for(k=0;k<N;k=k+1)begin
            for(j=0;j<VT;j=j+1)for(i=0;i<HT;i=i+1)begin
                @(negedge clk);tag=tags[k];input_frame=k;mode=frame_mode(k);iv=i<W && j<H;s=iv && i==0 && j==0;
                l=iv && i==W-1;e=l && j==H-1;x=iv?i:0;y=iv?j:0;
                rgb=iv?pixels[k*W*H+j*W+i][24:1]:24'd0;
            end
        end
        @(negedge clk);iv=0;s=0;l=0;e=0;
        repeat(4*W+64)@(negedge clk);
        if(seen!=N*W*H || edge_seen!=N*W*H || used!=0)$fatal(1,"Missing pixels seen=%d used=%d",seen,used);
        if(peak>W+4)$fatal(1,"Unexpected FIFO peak %d",peak);
        if(HT==W && VT==H && overlap==0)$fatal(1,"No cross-frame tail overlap exercised");
        $fclose(selected_file);$fclose(edge_file);$fclose(gray_file);$fclose(f);$fclose(m);$fclose(trace);
        $display("PASS FOUR_MODE: frames=%0d pixels=%0d peak=%0d overlap=%0d eof_delay=%0d",N,edge_seen,peak,edge_overlap,W+5);
        $finish;
    end
    initial begin #200000000; $fatal(1,"Watchdog");end
endmodule
