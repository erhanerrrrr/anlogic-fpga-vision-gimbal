`timescale 1ns/1ps
module tb_b4e_fps_decimal;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,flush=0,start=0;
    reg [15:0] source=0,display=0,result=0;
    wire done;
    wire [19:0] sb,db,rb;
    osd_fps_decimal dut(.clk(clk),.rst_n(rst_n),.flush(flush),.start(start),
        .source_fps_centi(source),.display_fps_centi(display),
        .result_fps_centi(result),
        .done(done),.source_bcd(sb),.display_bcd(db),.result_bcd(rb));
    task begin_conversion;
        input [15:0] s,d,r;
        begin
            @(negedge clk);source=s;display=d;result=r;start=1;
            @(negedge clk);start=0;
        end
    endtask
    task expect_triplet;
        input [19:0] s,d,r;
        input integer cycles;
        begin
            repeat(cycles-1)begin
                @(negedge clk);
                if(done)$fatal(1,"FPS converter finished early");
            end
            @(negedge clk);
            if(!done || sb!==s || db!==d || rb!==r)
                $fatal(1,"FPS BCD mismatch got %h/%h/%h done=%b",sb,db,rb,done);
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst_n=1;
        if(done)$fatal(1,"done after reset");
        begin_conversion(16'd6000,16'd2997,16'd0);
        expect_triplet(20'h06000,20'h02997,20'h00000,48);
        begin_conversion(16'hffff,16'd1,16'd12345);
        expect_triplet(20'h65535,20'h00001,20'h12345,48);
        // A new display SOF restarts conversion; no old/new field mixing.
        begin_conversion(16'd100,16'd200,16'd300);
        repeat(9)@(negedge clk);
        begin_conversion(16'd4500,16'd5000,16'd5500);
        expect_triplet(20'h04500,20'h05000,20'h05500,48);
        begin_conversion(16'd6000,16'd6000,16'd6000);
        repeat(12)@(negedge clk);
        flush=1;
        @(negedge clk);flush=0;
        repeat(60)@(negedge clk);
        if(done || sb!==0 || db!==0 || rb!==0)
            $fatal(1,"flush left stale FPS digits");
        $display("PASS B4E_FPS_DECIMAL: zero, centi-FPS, max, restart, flush");
        $finish;
    end
endmodule
