`timescale 1ns/1ps
module tb_b4f_performance_text;
    localparam integer LEFT=976,TOP=208,WIDTH=304,HEIGHT=112,FRAMES=5;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,abort=0,iv=0,sof=0,eol=0,eof=0;
    reg [10:0] x=0,y=0;
    reg [23:0] rgb=24'h101010;
    reg [83:0] tag=0;
    reg [87:0] packet=0;
    wire ov,os,ol,oe;
    wire [10:0] ox,oy;
    wire [23:0] orgb;
    wire [83:0] otag;
    video_performance_text dut(.clk(clk),.rst_n(rst_n),.stream_abort(abort),
        .performance_packet(packet),.in_valid(iv),.in_sof(sof),
        .in_eol(eol),.in_eof(eof),.in_x(x),.in_y(y),.in_rgb(rgb),.in_tag(tag),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_rgb(orgb),.out_tag(otag));
    integer fd,frames=0,seen=0,xx,yy,i;
    always @(posedge clk) begin
        #2;
        if(rst_n && ov) begin
            if(frames>=FRAMES || otag!==frames)
                $fatal(1,"B4f unexpected output frame/tag %0d/%h",frames,otag);
            if(seen==0) begin
                if(ox!==0 || oy!==0 || os!==1 || ol!==0 || oe!==0 || orgb!==24'h101010)
                    $fatal(1,"B4f SOF metadata/pass-through mismatch frame=%0d",frames);
            end else begin
                if(ox!==LEFT+(seen-1)%WIDTH ||
                   oy!==TOP+(seen-1)/WIDTH || os!==0 ||
                   ol!==((seen-1)%WIDTH==WIDTH-1) ||
                   oe!==(seen==WIDTH*HEIGHT))
                    $fatal(1,"B4f metadata mismatch frame=%0d pixel=%0d x=%0d y=%0d",frames,seen,ox,oy);
                $fwrite(fd,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);
            end
            seen=seen+1;
            if(oe) begin
                if(seen!=WIDTH*HEIGHT+1)$fatal(1,"B4f short frame");
                seen=0;frames=frames+1;
            end
        end
    end
    task frame;
        input integer index;
        input [87:0] value;
        integer px,py;
        begin
            @(negedge clk);
            packet=value;iv=1;sof=1;eol=0;eof=0;x=0;y=0;tag=index;
            @(negedge clk);
            iv=0;sof=0;
            // Conversion must complete before the first text pixel.
            repeat(55)@(negedge clk);
            for(py=0;py<HEIGHT;py=py+1) begin
                if(py==32 && index==1)packet=0;
                for(px=0;px<WIDTH;px=px+1) begin
                    iv=1;sof=0;eol=(px==WIDTH-1);
                    eof=(py==HEIGHT-1 && px==WIDTH-1);
                    x=LEFT+px;y=TOP+py;tag=index;
                    @(negedge clk);
                end
            end
            iv=0;sof=0;eol=0;eof=0;
        end
    endtask
    initial begin
        fd=$fopen("actual.rgb","wb");
        if(fd==0)$fatal(1,"cannot open actual.rgb");
        repeat(4)@(negedge clk);rst_n=1;
        frame(0,{1'b0,1'b0,16'd0, 1'b0,1'b0,16'd0,
                 1'b0,1'b0,16'd0, 1'b0,32'd0,1'b0});
        frame(1,{1'b1,1'b0,16'd6000, 1'b1,1'b0,16'd5994,
                 1'b1,1'b0,16'd2997, 1'b1,32'h1a2b3c4d,1'b1});
        frame(2,{1'b1,1'b0,16'd65535, 1'b1,1'b0,16'd0,
                 1'b1,1'b0,16'd1, 1'b1,32'hffffffff,1'b1});
        frame(3,{1'b1,1'b1,16'd65535, 1'b0,1'b0,16'd1234,
                 1'b1,1'b0,16'd1234, 1'b1,32'd0,1'b0});
        frame(4,{1'b1,1'b0,16'd1234, 1'b1,1'b0,16'd4567,
                 1'b1,1'b0,16'd890, 1'b1,32'd7,1'b0});
        repeat(5)@(negedge clk);
        if(frames!=FRAMES || seen!=0)$fatal(1,"B4f output count %0d/%0d",frames,seen);
        $fclose(fd);
        $display("PASS B4F_PERFORMANCE_TEXT: five panel snapshots and pixel metadata");
        $finish;
    end
endmodule
