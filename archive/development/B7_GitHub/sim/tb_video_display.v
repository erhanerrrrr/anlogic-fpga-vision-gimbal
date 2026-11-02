`timescale 1ns/1ps

module tb_video_display #(
    parameter integer WIDTH=384,
    parameter integer HEIGHT=240,
    parameter integer FRAME_COUNT=10,
    parameter integer ROW_BLANKS=1,
    parameter integer RESET_TEST=1,
    parameter integer LONG_BLANKS=0,
    parameter integer ACTIVE_LOW=1, OSD_ENABLE=1
);
    localparam integer FRAME_PIXELS=WIDTH*HEIGHT;
    localparam integer PREFIX_LENGTH=4*WIDTH+5;
    localparam integer FLUSH_MAX=6*WIDTH+20;
    localparam integer IDLE=0, PREFIX=1, TAIL=2, FULL=3;
    reg clk=1'b0, rst_n=1'b0, in_valid=1'b0;
    reg [23:0] in_rgb=24'd0;
    reg in_sof=1'b0, in_eol=1'b0, in_eof=1'b0;
    reg [10:0] in_x=11'd0, in_y=11'd0;
    reg [31:0] in_source_frame_id=32'd0;
    wire out_valid, out_sof, out_eol, out_eof, out_error;
    wire [23:0] out_rgb;
    wire [1:0] out_mode;
    reg in_mask=0;
    reg [2:0] buttons_async=ACTIVE_LOW ? 3'b111 : 3'b000;
    reg [2:0] raw_pressed;
    wire [2:0] pressed, press_event;
    wire [1:0] requested_mode;
    wire mode_req_valid=dut.chain.mode_req_valid;
    wire [2:0] mode_req=dut.chain.mode_req;
    integer mode_presses=0, calibrate_presses=0, track_presses=0;
    integer expected_requested=0;
    reg consumed_mode_event;
    reg [1:0] consumed_request;
    wire invalid_request, detect_valid, detect_sof, detect_eol, detect_eof;
    wire [23:0] detect_rgb;
    wire [10:0] detect_x, detect_y;
    wire [31:0] detect_source_frame_id;
    wire [81:0] detect_packet={detect_valid,detect_sof,detect_eol,detect_eof,detect_rgb,detect_x,detect_y,detect_source_frame_id};
    reg [81:0] expected_detect, checked_detect=82'd0;
    reg model_in_frame=0, expected_invalid;
    reg [1:0] expected_mode;
    integer rejects=0, tag_peak=0, detection_pixels=0, events_file;
    integer gray_value;
    reg [1023:0] events_path;
    wire [10:0] out_x, out_y;
    wire [31:0] out_source_frame_id;
    wire [83:0] actual_packet={out_mode,out_valid,out_sof,out_eol,out_eof,out_rgb,out_x,out_y,out_source_frame_id};
    reg [83:0] expected_packet, checked_packet=84'd0;
    reg [23:0] expected_rgb;
    integer fifo_peak=0;
    reg [10:0] expected_x, expected_y;
    reg [31:0] expected_id;
    reg test_done=1'b0, test_passed=1'b0, row_open=1'b0;
    integer phase=IDLE, frame_number, init_index, check_index;
    integer received=0, prefix_pixels=0, errors=0, borders=0;
    integer sof_count=0, eol_count=0, eof_count=0, async_reset_checks=0;
    integer reference_index, reference_frame, reference_pattern;
    integer cycle_count=0, observed_latency, expected_latency;
    integer sof_cycle[0:FRAME_COUNT-1], eof_cycle[0:FRAME_COUNT-1];
    integer done_cycle[0:FRAME_COUNT-1], timeout_reported[0:FRAME_COUNT-1];
    integer input_file, output_file;
    reg [1023:0] input_path, output_path;

    wire display_valid;
    assign out_valid=dut.styled_valid;
    wire [23:0] display_rgb;
    assign out_rgb=dut.styled_rgb;
    wire [1:0] display_mode;
    assign out_mode=dut.styled_mode;
    wire display_sof;
    assign out_sof=dut.styled_sof;
    wire display_eol;
    assign out_eol=dut.styled_eol;
    wire display_eof;
    assign out_eof=dut.styled_eof;
    wire [10:0] display_x;
    assign out_x=dut.styled_x;
    wire [10:0] display_y;
    assign out_y=dut.styled_y;
    wire [31:0] display_source_frame_id;
    assign out_source_frame_id=dut.styled_source_frame_id;
    integer display_file,display_count=0,display_sofs=0,display_eols=0,display_eofs=0;
    reg [59:0] expected_display_meta, display_meta_delay=0;
    reg [83:0] checked_display=0;
    wire [59:0] display_meta={display_mode,display_valid,display_sof,display_eol,display_eof,display_x,display_y,display_source_frame_id};
    wire [83:0] display_packet={display_meta,display_rgb};

    video_display #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DEBOUNCE_CYCLES(4),.ACTIVE_LOW(ACTIVE_LOW),.OSD_ENABLE(OSD_ENABLE)) dut (
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_rgb(in_rgb),
        .in_mask(in_mask),.buttons_async(buttons_async),.pressed(pressed),.press_event(press_event),
        .requested_mode(requested_mode),.invalid_request(invalid_request),
        .detect_valid(detect_valid),.detect_rgb(detect_rgb),.detect_sof(detect_sof),.detect_eol(detect_eol),.detect_eof(detect_eof),
        .detect_x(detect_x),.detect_y(detect_y),.detect_source_frame_id(detect_source_frame_id),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_source_frame_id(in_source_frame_id),
        .out_valid(display_valid),.out_rgb(display_rgb),.out_mode(display_mode),.out_sof(display_sof),.out_eol(display_eol),.out_eof(display_eof),
        .out_x(display_x),.out_y(display_y),.out_source_frame_id(display_source_frame_id),.out_error(out_error)
    );
    always #5 clk=~clk;

    // Fixture definition shared by source and oracle; no DUT signal is used.
    function [23:0] fixture_rgb;
        input integer x,y,pattern;
        reg [7:0] r,g,b;
        reg [23:0] color;
        begin
            case (pattern % 8)
                0: color=24'd0;
                1: color=24'hffffff;
                2: color=(x >= WIDTH/2) ? 24'hffffff : 24'd0;
                3: color=(y >= HEIGHT/2) ? 24'hffffff : 24'd0;
                4: color=(x >= WIDTH/4 && x < 3*WIDTH/4 && y >= HEIGHT/4 && y < 3*HEIGHT/4)
                         ? 24'hff0000 : 24'h0000ff;
                5: color=(x*HEIGHT >= y*WIDTH) ? 24'hffffff : 24'd0;
                default: begin
                    r=(3*x+5*y+102)%256;
                    g=(7*x+11*y+174)%256;
                    b=(13*x+19*y+186)%256;
                    color=(pattern % 8 == 6) ? {r,g,b} : ~{r,g,b};
                end
            endcase
            fixture_rgb=color;
        end
    endfunction

    function integer reference_gray;
        input integer x,y,pattern;
        reg [23:0] color;
        integer r,g,b;
        begin
            color=fixture_rgb(x,y,pattern);
            r=color[23:16]; g=color[15:8]; b=color[7:0];
            reference_gray=(77*r+150*g+29*b+128)/256;
        end
    endfunction

    function [23:0] reference_edge;
        input integer x,y,pattern;
        integer gx,gy,m;
        begin
            if (x == 0 || x == WIDTH-1 || y == 0 || y == HEIGHT-1)
                reference_edge=24'd0;
            else begin
                gx=reference_gray(x+1,y-1,pattern)+2*reference_gray(x+1,y,pattern)+reference_gray(x+1,y+1,pattern)
                   -reference_gray(x-1,y-1,pattern)-2*reference_gray(x-1,y,pattern)-reference_gray(x-1,y+1,pattern);
                gy=reference_gray(x-1,y+1,pattern)+2*reference_gray(x,y+1,pattern)+reference_gray(x+1,y+1,pattern)
                   -reference_gray(x-1,y-1,pattern)-2*reference_gray(x,y-1,pattern)-reference_gray(x+1,y-1,pattern);
                m=((gx < 0) ? -gx : gx)+((gy < 0) ? -gy : gy);
                reference_edge=(m >= 128) ? 24'hffffff : 24'd0;
            end
        end
    endfunction

    function integer frame_mode;
        input integer number;
        begin
            case (number)
                0,7,9: frame_mode=0;
                1,2: frame_mode=1;
                3,4: frame_mode=2;
                5,6,8: frame_mode=3;
                default: frame_mode=2;
            endcase
        end
    endfunction
    function integer frame_pattern;
        input integer number;
        begin frame_pattern=6+(number%2); end
    endfunction
    function integer fixture_mask;
        input integer x,y,number;
        begin fixture_mask=((x/2+y/2+number)%2); end
    endfunction

    task blank;
        begin
            @(negedge clk);
            in_valid=1'b0; in_rgb=24'hbadbad; in_mask=1'b1;
            in_sof=1'b1; in_eol=1'b1; in_eof=1'b1;
            in_x=11'd2047; in_y=11'd2047; in_source_frame_id=32'hdeadbeef;
        end
    endtask

    task send_range;
        input integer first_pixel,end_pixel,pattern;
        input [31:0] source_id;
        integer index,x,y,f,b;
        begin
            for (index=first_pixel;index<end_pixel;index=index+1) begin
                x=index%WIDTH; y=index/WIDTH;
                @(negedge clk);
                in_valid=1'b1; in_rgb=fixture_rgb(x,y,pattern);
                f=source_id-100;
                in_mask=fixture_mask(x,y,f);
                raw_pressed=0;
                if (phase==PREFIX && index>=8 && index<20) raw_pressed[0]=1;
                if (phase==FULL) begin
                    case (f)
                        0,2,4,6: raw_pressed[0]=(index>=8 && index<20);
                        1: begin
                            raw_pressed[0]=(index>=8 && index<10); // rejected short glitch
                            raw_pressed[1]=(index>=32 && index<48);
                            raw_pressed[2]=(index>=32 && index<48);
                        end
                        7: raw_pressed[0]=(index>=8 && index<20) ||
                                          (index>=40 && index<52) || (index>=72 && index<84);
                        8: raw_pressed[0]=(index>=8 && index<144); // held >100 clocks
                    endcase
                end
                #1;
                buttons_async=ACTIVE_LOW ? ~raw_pressed : raw_pressed;
                in_x=x; in_y=y; in_source_frame_id=source_id;
                in_sof=(index == 0); in_eol=(x == WIDTH-1); in_eof=(index == FRAME_PIXELS-1);
                if (ROW_BLANKS && x == WIDTH-1)
                    for (b=0;b<1+(y+pattern)%4+(LONG_BLANKS ? 4*WIDTH : 0);b=b+1) begin
                        blank;
                    end
            end
        end
    endtask

    initial begin
        if (WIDTH < 16 || HEIGHT < 12 || WIDTH > 2048 || HEIGHT > 2048 || FRAME_COUNT != 10 ||
            (RESET_TEST && (WIDTH < 8 || HEIGHT < 6))) begin
            $display("FAIL: invalid full edge test parameters");
            $finish;
        end
        for (init_index=0;init_index<FRAME_COUNT;init_index=init_index+1) begin
            sof_cycle[init_index]=-1; eof_cycle[init_index]=-1;
            done_cycle[init_index]=-1; timeout_reported[init_index]=0;
        end
        input_path="input.csv"; output_path="styled.csv";
        if ($value$plusargs("INPUT_CSV=%s",input_path)) begin end
        if ($value$plusargs("OUTPUT_CSV=%s",output_path)) begin end
        events_path="events.csv";
        if ($value$plusargs("EVENTS_CSV=%s",events_path)) begin end
        events_file=$fopen(events_path,"w");
        $fdisplay(events_file,"cycle,in_sof,in_valid,source_frame_id,raw_pins,pressed,events,requested_mode,active_mode");
        display_file=$fopen("display.csv","w");
        $fdisplay(display_file,"frame,source_frame_id,x,y,mode,rgb");
        input_file=$fopen(input_path,"w"); output_file=$fopen(output_path,"w");
        if (!input_file || !output_file || !events_file || !display_file) begin
            $display("FAIL: cannot create edge CSV files");
            $finish;
        end
        $fdisplay(input_file,"frame,source_frame_id,x,y,rgb,mask");
        $fdisplay(output_file,"frame,source_frame_id,x,y,mode,rgb");
        repeat (3) @(negedge clk);
        rst_n=1'b1;
        blank;
        phase=TAIL;
        send_range(1,2,4,32'd90);
        blank;
        if (RESET_TEST) begin
            phase=PREFIX;
            send_range(0,PREFIX_LENGTH,4,32'd90);
            @(posedge clk);
            #2;
            rst_n=1'b0; in_valid=1'b0; phase=TAIL; buttons_async=ACTIVE_LOW ? 3'b111 : 3'b000;
            repeat (2) @(negedge clk);
            #2;
            rst_n=1'b1;
            blank;
            send_range(PREFIX_LENGTH,FRAME_PIXELS,4,32'd90);
            repeat (8) blank;
        end
        phase=FULL;
        for (frame_number=0;frame_number<FRAME_COUNT;frame_number=frame_number+1) begin
            send_range(0,FRAME_PIXELS,frame_pattern(frame_number),32'd100+frame_number);
            if (ROW_BLANKS) repeat (2+frame_number%3+(LONG_BLANKS ? 4*WIDTH : 0)) blank;
        end
        repeat (FLUSH_MAX+8) blank;
        // A post-EOF fragment must not create another partial output frame.
        send_range(1,2,4,32'd90);
        repeat (FLUSH_MAX+8) blank;
        @(negedge clk);
        if (display_count != FRAME_COUNT*FRAME_PIXELS || display_sofs!=FRAME_COUNT || display_eols!=FRAME_COUNT*HEIGHT || display_eofs!=FRAME_COUNT ||
            received != FRAME_COUNT*FRAME_PIXELS || sof_count != FRAME_COUNT ||
            eol_count != FRAME_COUNT*HEIGHT || eof_count != FRAME_COUNT ||
            borders != FRAME_COUNT*(2*WIDTH+2*HEIGHT-4) || rejects != 0 || mode_presses!=8 || calibrate_presses!=1 || track_presses!=1 || requested_mode!=0 || detection_pixels != FRAME_COUNT*FRAME_PIXELS ||
            (RESET_TEST && (prefix_pixels == 0 || prefix_pixels >= FRAME_PIXELS)) ||
            async_reset_checks != (RESET_TEST ? 1 : 0)) begin
            errors=errors+1;
            $display("FAIL: unexpected full edge frame counts");
        end
        $fclose(input_file); $fclose(output_file); $fclose(events_file); $fclose(display_file);
        test_done=1'b1; test_passed=(errors == 0);
        $display("Pixels=%0d SOF=%0d EOL=%0d EOF=%0d BorderPositions=%0d Errors=%0d",
            received,sof_count,eol_count,eof_count,borders,errors);
        $display("Display pixels=%0d SOF=%0d EOL=%0d EOF=%0d",display_count,display_sofs,display_eols,display_eofs);
        $display("FIFO peak=%0d Tag peak=%0d Capacity=%0d",fifo_peak,tag_peak,4*WIDTH+16);
        $display("Detection pixels=%0d Rejected requests=%0d",detection_pixels,rejects);
        $display("Buttons: mode=%0d calibrate=%0d track=%0d",mode_presses,calibrate_presses,track_presses);
        $display("Reset prefix pixels=%0d Async reset checks=%0d",prefix_pixels,async_reset_checks);
        if (test_passed)
            $display("PASS: buttons, video modes and OSD stream checks completed.");
        else $display("FAIL: four-mode video test failed.");
        $finish;
    end

    always @(posedge clk) begin
        cycle_count=cycle_count+1;
        expected_detect=82'd0;
        expected_invalid=0;
        consumed_mode_event=rst_n && mode_req_valid;
        consumed_request=mode_req[1:0];
        if (!rst_n) expected_requested=0;
        else if (consumed_mode_event) begin
            expected_requested=(expected_requested+1)%4;
            if (consumed_request !== expected_requested[1:0]) begin
                errors=errors+1; $display("FAIL: repeated presses did not accumulate the requested mode");
            end
        end
        if (rst_n && phase==FULL) begin
            if (press_event[0]) mode_presses=mode_presses+1;
            if (press_event[1]) calibrate_presses=calibrate_presses+1;
            if (press_event[2]) track_presses=track_presses+1;
        end
        if (!rst_n) model_in_frame=0;
        else if (in_valid && (model_in_frame || in_sof)) begin
            expected_detect={1'b1,in_sof,in_eol,in_eof,in_rgb,in_x,in_y,in_source_frame_id};
            model_in_frame=!in_eof;
            if (phase==FULL) detection_pixels=detection_pixels+1;
        end
        if (rst_n && phase == FULL && in_valid && in_source_frame_id >= 100 && in_source_frame_id < 100+FRAME_COUNT) begin
            if (in_sof) sof_cycle[in_source_frame_id-100]=cycle_count;
            if (in_eof) eof_cycle[in_source_frame_id-100]=cycle_count;
            if (1)
                $fdisplay(input_file,"%0d,%0d,%0d,%0d,%h,%0d",in_source_frame_id-100,in_source_frame_id,in_x,in_y,in_rgb,in_mask);
        end
        #1;
        expected_packet=84'd0;
        if (rst_n && requested_mode !== expected_requested[1:0]) begin
            errors=errors+1; $display("FAIL: requested mode register mismatch");
        end
        if (detect_packet !== expected_detect || invalid_request !== expected_invalid) begin
            errors=errors+1;
            if (errors<=5) $display("FAIL: base RGB tap or request diagnostic mismatch");
        end
        checked_detect=detect_packet;
        if (rst_n && phase==FULL && invalid_request) rejects=rejects+1;
        if (rst_n && (press_event!=0 || (in_valid && in_sof)))
            $fdisplay(events_file,"%0d,%0d,%0d,%0d,%b,%b,%b,%0d,%0d",cycle_count,in_sof,in_valid,in_source_frame_id,buttons_async,pressed,press_event,requested_mode,dut.chain.video.active_mode);
        if (rst_n && dut.chain.video.tag_count>tag_peak) tag_peak=dut.chain.video.tag_count;
        if (rst_n && dut.chain.video.align.queued_pixels > fifo_peak) fifo_peak=dut.chain.video.align.queued_pixels;
        if (rst_n && out_error !== 1'b0) begin
            errors=errors+1;
            if (errors <= 5) $display("FAIL: raster FIFO/protocol diagnostic asserted");
        end
        if (rst_n && out_valid === 1'b1 && (phase == PREFIX || phase == FULL)) begin
            reference_index=(phase == PREFIX) ? prefix_pixels : received%FRAME_PIXELS;
            reference_frame=(phase == PREFIX) ? 0 : received/FRAME_PIXELS;
            reference_pattern=(phase == PREFIX) ? 4 : frame_pattern(reference_frame);
            expected_x=reference_index%WIDTH; expected_y=reference_index/WIDTH;
            expected_id=(phase == PREFIX) ? 32'd90 : 32'd100+reference_frame;
            expected_mode=(phase==PREFIX) ? 0 : frame_mode(reference_frame);
            case (expected_mode)
                0: expected_rgb=fixture_rgb(expected_x,expected_y,reference_pattern);
                1: begin
                    gray_value=reference_gray(expected_x,expected_y,reference_pattern);
                    expected_rgb={gray_value[7:0],gray_value[7:0],gray_value[7:0]};
                end
                2: expected_rgb=reference_edge(expected_x,expected_y,reference_pattern);
                3: expected_rgb=fixture_mask(expected_x,expected_y,reference_frame) ? 24'hffffff : 24'd0;
            endcase
            if ($test$plusargs("CHECKER_SELFTEST") && phase == FULL && received == WIDTH+1)
                expected_rgb=expected_rgb ^ 24'h000001;
            expected_packet={expected_mode,1'b1,(reference_index == 0),(expected_x == WIDTH-1),
                (reference_index == FRAME_PIXELS-1),expected_rgb,expected_x,expected_y,expected_id};
            if (phase == PREFIX) prefix_pixels=prefix_pixels+1;
            else if (received < FRAME_COUNT*FRAME_PIXELS) begin
                if (out_sof) begin
                    sof_count=sof_count+1;
                    observed_latency=cycle_count-sof_cycle[reference_frame];
                    expected_latency=3*WIDTH+6+(ROW_BLANKS ? 2+reference_pattern%4+(1+reference_pattern)%4+(LONG_BLANKS ? 8*WIDTH : 0) : 0);
                    if (observed_latency != expected_latency) begin
                        errors=errors+1;
                        $display("FAIL: SOF latency expected=%0d observed=%0d",expected_latency,observed_latency);
                    end
                    $display("Frame %0d source_id=%0d SOF latency=%0d cycles",reference_frame,out_source_frame_id,observed_latency);
                end
                if (out_eol) eol_count=eol_count+1;
                if (out_eof) begin
                    eof_count=eof_count+1;
                    done_cycle[reference_frame]=cycle_count;
                    if (eof_cycle[reference_frame] < 0 || cycle_count-eof_cycle[reference_frame] > FLUSH_MAX) begin
                        errors=errors+1;
                        $display("FAIL: frame EOF flush budget exceeded");
                    end
                    $display("Frame %0d complete: pixels=%0d EOF delay=%0d cycles",reference_frame,FRAME_PIXELS,cycle_count-eof_cycle[reference_frame]);
                end
                if (expected_x == 0 || expected_x == WIDTH-1 || expected_y == 0 || expected_y == HEIGHT-1)
                    borders=borders+1;
                if (1)
                    $fdisplay(output_file,"%0d,%0d,%0d,%0d,%0d,%h",reference_frame,out_source_frame_id,out_x,out_y,out_mode,out_rgb);
                received=received+1;
            end else begin
                errors=errors+1;
                if (errors <= 5) $display("FAIL: extra edge pixel after all expected frames");
            end
            row_open=(expected_x != WIDTH-1);
        end else begin
            if (rst_n && row_open) begin
                errors=errors+1;
                if (errors <= 5) $display("FAIL: output row contains a gap");
            end
            row_open=1'b0;
        end
        if (actual_packet !== expected_packet) begin
            errors=errors+1;
            if (errors <= 5) $display("FAIL: mode/pixel packet mismatch at %0t expected=%h actual=%h",$time,expected_packet,actual_packet);
        end
        if (rst_n && phase == FULL)
            for (check_index=0;check_index<FRAME_COUNT;check_index=check_index+1)
                if (eof_cycle[check_index] >= 0 && done_cycle[check_index] < 0 &&
                    !timeout_reported[check_index] && cycle_count > eof_cycle[check_index]+FLUSH_MAX) begin
                    errors=errors+1; timeout_reported[check_index]=1;
                    $display("FAIL: frame %0d did not flush within %0d cycles",check_index,FLUSH_MAX);
                end
        checked_packet=actual_packet;
    end

    always @(negedge rst_n) begin
        row_open=1'b0; checked_packet=84'd0; checked_detect=82'd0; model_in_frame=0; expected_requested=0;
        if ($time > 0) begin
            #1;
            async_reset_checks=async_reset_checks+1;
            if (actual_packet !== 84'd0 || detect_packet !== 82'd0 || invalid_request !== 1'b0 || out_error !== 1'b0 || requested_mode !== 2'd0 || pressed !== 3'd0 || press_event !== 3'd0) begin
                errors=errors+1;
                $display("FAIL: asynchronous reset did not clear edge outputs");
            end
        end
    end
    always @(negedge clk) begin
        #1;
        if (actual_packet !== checked_packet || detect_packet !== checked_detect) begin
            errors=errors+1;
            if (errors <= 5) $display("FAIL: edge output changed between rising edges");
        end
    end
    initial begin
        repeat ((FRAME_COUNT+4)*(FRAME_PIXELS+(5+(LONG_BLANKS ? 4*WIDTH : 0))*(HEIGHT+1))+4*FLUSH_MAX+1000) @(posedge clk);
        $display("FAIL: full edge test watchdog timeout");
        $finish;
    end
    always @(posedge clk) begin
        // Capture the previous stage BEFORE it updates on this edge.
        expected_display_meta=rst_n ? display_meta_delay : 60'd0;
        display_meta_delay=rst_n ? {out_mode,out_valid,out_sof,out_eol,out_eof,out_x,out_y,out_source_frame_id} : 60'd0;
        #1;
        if(display_meta !== expected_display_meta || (display_valid && (^display_rgb)===1'bx) ||
           (!display_valid && display_rgb !== 24'd0)) begin
            errors=errors+1; $display("FAIL: OSD metadata/valid/unknown mismatch");
        end
        checked_display=display_packet;
        if(rst_n && display_valid && display_source_frame_id>=100 && display_source_frame_id<110) begin
            $fdisplay(display_file,"%0d,%0d,%0d,%0d,%0d,%h",display_source_frame_id-100,display_source_frame_id,display_x,display_y,display_mode,display_rgb);
            display_count=display_count+1;
            if(display_sof) begin
                display_sofs=display_sofs+1;
                $display("Display frame %0d SOF latency=%0d cycles",display_source_frame_id-100,cycle_count-sof_cycle[display_source_frame_id-100]);
            end
            if(display_eol) display_eols=display_eols+1;
            if(display_eof) display_eofs=display_eofs+1;
        end
    end
    always @(negedge rst_n) begin
        checked_display=0; display_meta_delay=0;
        #1; if(display_packet !== 84'd0) begin errors=errors+1; $display("FAIL: OSD asynchronous reset"); end
    end
    always @(negedge clk) begin
        #1; if(display_packet !== checked_display) begin errors=errors+1; $display("FAIL: OSD output changed between clocks"); end
    end

endmodule
