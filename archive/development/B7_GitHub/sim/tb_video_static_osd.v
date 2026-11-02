`timescale 1ns/1ps
module tb_video_static_osd;
    parameter integer WIDTH=384, HEIGHT=240, ROW_BLANKS=1, LAYOUT=0, ENABLE=1;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, in_valid=0, in_sof=0,in_eol=0,in_eof=0;
    reg [23:0] in_rgb=0;
    reg [1:0] in_mode=0;
    reg [10:0] in_x=0,in_y=0;
    reg [31:0] in_source_frame_id=0;
    wire out_valid,out_sof,out_eol,out_eof;
    wire [23:0] out_rgb;
    wire [1:0] out_mode;
    wire [10:0] out_x,out_y;
    wire [31:0] out_source_frame_id;
    localparam LX=LAYOUT==1 ? WIDTH-80 : 0;
    localparam LY=LAYOUT==1 ? HEIGHT-90 : 0;
    localparam TX=LAYOUT==1 ? WIDTH-40 : LAYOUT==2 ? 45 : 168;
    localparam TY=LAYOUT==1 ? HEIGHT-24 : LAYOUT==2 ? 40 : 16;
    localparam MX=LAYOUT==1 ? WIDTH-20 : LAYOUT==2 ? 45 : 168;
    localparam MY=LAYOUT==1 ? HEIGHT-8 : LAYOUT==2 ? 40 : 48;
    localparam CX=LAYOUT==1 ? 0 : LAYOUT==2 ? 60 : WIDTH/2;
    localparam CY=LAYOUT==1 ? 0 : LAYOUT==2 ? 45 : HEIGHT/2;
    video_static_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ENABLE(ENABLE),
        .LOGO_X(LX),.LOGO_Y(LY),.TITLE_X(TX),.TITLE_Y(TY),.LABEL_X(MX),.LABEL_Y(MY),.CROSS_X(CX),.CROSS_Y(CY)) dut (
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_rgb(in_rgb),.in_mode(in_mode),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_x(in_x),.in_y(in_y),.in_source_frame_id(in_source_frame_id),
        .out_valid(out_valid),.out_rgb(out_rgb),.out_mode(out_mode),.out_sof(out_sof),.out_eol(out_eol),.out_eof(out_eof),
        .out_x(out_x),.out_y(out_y),.out_source_frame_id(out_source_frame_id));
    integer csv,errors=0,received=0,sofs=0,eols=0,eofs=0,cycle=0;
    integer f,x,y,i;
    reg test_done=0,test_passed=0,ref_frame=0,expected_valid;
    reg [58:0] expected_meta, meta_delay=0;
    reg valid_delay=0;
    reg [23:0] input_rgb_delay=0;
    reg [23:0] checked_input_rgb;
    function [23:0] color;
        input integer frame,x,y;
        reg [7:0] gray;
        begin
            gray=(x+3*y)&255;
            case(frame)
                0:color=24'hb02020; 1:color=24'h208020;
                2:color=24'h2030b0; 3:color=24'hffffff;
                default:color={gray,gray,gray};
            endcase
        end
    endfunction
    task pixel;
        input integer frame,px,py,id;
        begin
            @(negedge clk);
            in_valid=1; in_x=px; in_y=py; in_source_frame_id=id;
            in_sof=(px==0 && py==0); in_eol=(px==WIDTH-1); in_eof=(px==WIDTH-1 && py==HEIGHT-1);
            in_rgb=color(frame,px,py); in_mode=frame%4;
        end
    endtask
    task blank;
        begin @(negedge clk); in_valid=0; in_sof=1; in_eol=1; in_eof=1; end
    endtask
    // Check the exact two-register transaction, independent of DUT state.
    always @(posedge clk) begin
        cycle=cycle+1;
        if (!rst_n) begin ref_frame=0; expected_valid=0; end
        else begin
            expected_valid=in_valid && (ref_frame || in_sof);
            if (expected_valid) ref_frame=!in_eof;
        end
        expected_meta=meta_delay;
        checked_input_rgb=input_rgb_delay;
        meta_delay=expected_valid ? {in_mode,in_sof,in_eol,in_eof,in_x,in_y,in_source_frame_id} : 59'd0;
        input_rgb_delay=expected_valid ? in_rgb : 24'd0;
        // Use the previous expected valid for the second stage check.
        begin : queue_valid
            reg incoming_valid;
            incoming_valid=expected_valid;
            expected_valid=valid_delay;
            valid_delay=incoming_valid;
        end
        #1;
        if (out_valid !== expected_valid || {out_mode,out_sof,out_eol,out_eof,out_x,out_y,out_source_frame_id} !== expected_meta) errors=errors+1;
        if (!expected_valid && out_rgb !== 24'd0) errors=errors+1;
        if (out_valid && (^out_rgb)===1'bx) errors=errors+1;
        if (out_valid) begin
            $fdisplay(csv,"%0d,%0d,%0d,%0d,%0d,%06h,%06h",cycle,out_source_frame_id,out_x,out_y,out_mode,checked_input_rgb,out_rgb);
            if (out_source_frame_id>=100) begin
                received=received+1;
                if (out_sof) sofs=sofs+1;
                if (out_eol) eols=eols+1;
                if (out_eof) eofs=eofs+1;
            end
        end
    end
    initial begin
        csv=$fopen("pixels.csv","w");
        if (!csv) begin $display("FAIL: cannot open CSV"); $finish; end
        $fdisplay(csv,"cycle,id,x,y,mode,input,output");
        repeat(3) @(negedge clk); rst_n=1;
        for(i=0;i<200;i=i+1) pixel(0,i%WIDTH,i/WIDTH,90);
        // Interrupt after a real output prefix, not only an empty pipeline.
        blank; @(negedge clk); #2; rst_n=0; ref_frame=0; meta_delay=0; valid_delay=0; input_rgb_delay=0;
        #1; if ({out_valid,out_rgb,out_mode,out_sof,out_eol,out_eof,out_x,out_y,out_source_frame_id} !== 84'd0) errors=errors+1;
        repeat(2) @(negedge clk); rst_n=1;
        for(i=201;i<300;i=i+1) pixel(0,i%WIDTH,i/WIDTH,90);
        blank;
        for(f=0;f<5;f=f+1) begin
            for(y=0;y<HEIGHT;y=y+1) begin
                for(x=0;x<WIDTH;x=x+1) pixel(f,x,y,100+f);
                if(ROW_BLANKS) repeat(y%3) blank;
            end
            if(ROW_BLANKS) repeat(3) blank;
        end
        blank; repeat(3) @(negedge clk);
        if(received!=5*WIDTH*HEIGHT || sofs!=5 || eols!=5*HEIGHT || eofs!=5) errors=errors+1;
        test_done=1; test_passed=(errors==0);
        $fclose(csv);
        $display("Pixels=%0d SOF=%0d EOL=%0d EOF=%0d Errors=%0d",received,sofs,eols,eofs,errors);
        if(test_passed) $display("PASS: static OSD stream timing checks completed.");
        else $display("FAIL: static OSD stream timing");
        $finish;
    end
    initial begin
        repeat(7*(WIDTH*HEIGHT+3*HEIGHT)+1000) @(posedge clk);
        $display("FAIL: static OSD watchdog timeout"); $finish;
    end
endmodule
