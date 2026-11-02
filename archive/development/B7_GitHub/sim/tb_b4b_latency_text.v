`timescale 1ns/1ps
module tb_b4b_latency_text;
    localparam integer WIDTH=896,HEIGHT=288;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,clear=0,sample_valid=0;
    reg [31:0] sample_us=0;
    reg [1:0] sample_kind=0;
    wire stats_valid;
    wire [1:0] stats_kind;
    wire [31:0] min_us,avg_us,max_us;
    wire [8:0] sample_count;
    latency_window_stats stats(.clk(clk),.rst_n(rst_n),.clear(clear),
        .sample_valid(sample_valid),.sample_us(sample_us),.sample_kind(sample_kind),
        .stats_valid(stats_valid),.stats_kind(stats_kind),
        .min_us(min_us),.avg_us(avg_us),.max_us(max_us),.sample_count(sample_count));
    reg iv=0,sof=0,eol=0,eof=0,abort=0;
    reg [10:0] x=0,y=0;
    reg [23:0] rgb=24'h101010;
    reg [83:0] tag=0;
    wire ov,os,ol,oe;
    wire [10:0] ox,oy;
    wire [23:0] orgb;
    wire [83:0] otag;
    video_latency_text dut(.clk(clk),.rst_n(rst_n),.stream_abort(abort),
        .stats_valid(stats_valid),.stats_kind(stats_kind),
        .min_us(min_us),.avg_us(avg_us),.max_us(max_us),
        .sample_count(sample_count),.synthetic_source(1'b1),
        .in_valid(iv),.in_sof(sof),.in_eol(eol),.in_eof(eof),
        .in_x(x),.in_y(y),.in_rgb(rgb),.in_tag(tag),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_rgb(orgb),.out_tag(otag));
    integer fd,seen=0,frames=0;
    always @(posedge clk)begin
        #2;
        if(rst_n && ov)begin
            if(frames>=4 || ox!==seen%WIDTH || oy!==seen/WIDTH ||
                os!==(seen==0) || ol!==(seen%WIDTH==WIDTH-1) ||
                oe!==(seen==WIDTH*HEIGHT-1) || otag!=={52'd0,32'(frames)})
                $fatal(1,"B4b pixel metadata mismatch frame=%0d pixel=%0d",frames,seen);
            $fwrite(fd,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);
            seen=seen+1;
            if(oe)begin
                if(seen!=WIDTH*HEIGHT)$fatal(1,"B4b short frame");
                seen=0;frames=frames+1;
            end
        end
    end
    task sample;
        input [1:0] kind;
        input [31:0] value;
        begin
            @(negedge clk);iv=0;sof=0;eol=0;eof=0;
            sample_kind=kind;sample_us=value;sample_valid=1;
            @(negedge clk);sample_valid=0;
        end
    endtask
    task frame;
        input integer index;
        integer xx,yy,k;
        begin
            for(yy=0;yy<HEIGHT;yy=yy+1)begin
                if(yy==240 && index==1)
                    for(k=0;k<8;k=k+1)sample(2,32'hffffffff);
                if(yy==240 && index==2)
                    for(k=0;k<8;k=k+1)sample(2,0);
                for(xx=0;xx<WIDTH;xx=xx+1)begin
                    @(negedge clk);
                    iv=1;sof=xx==0 && yy==0;eol=xx==WIDTH-1;
                    eof=eol && yy==HEIGHT-1;
                    x=xx;y=yy;tag={52'd0,32'(index)};
                end
            end
            @(negedge clk);iv=0;sof=0;eol=0;eof=0;
        end
    endtask
    integer i;
    initial begin
        fd=$fopen("actual.rgb","wb");
        if(fd==0)$fatal(1,"cannot open actual.rgb");
        repeat(4)@(negedge clk);rst_n=1;
        frame(0);
        sample(1,10);
        for(i=0;i<6;i=i+1)sample(1,20);
        sample(1,30);
        if(!stats_valid || min_us!=10 || avg_us!=20 || max_us!=30)
            $fatal(1,"initial statistics wrong");
        frame(1);frame(2);frame(3);
        repeat(5)@(negedge clk);
        if(frames!=4)$fatal(1,"B4b output frames=%0d",frames);
        $fclose(fd);
        $display("PASS B4B_LATENCY_TEXT: four frame snapshots and metadata");
        $finish;
    end
endmodule
