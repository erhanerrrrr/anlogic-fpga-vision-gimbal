`timescale 1ns/1ps
module tb_osd_decimal_fields;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,flush=0,start=0;
    reg [10:0] cx=0,cy=0;
    reg [19:0] area=0;
    reg [7:0] slots=0;
    reg [11:0] components=0;
    wire done;
    wire [15:0] x_bcd,y_bcd,components_bcd;
    wire [27:0] area_bcd;
    wire [11:0] slots_bcd;
    osd_decimal_fields dut(.*);
    integer f,n,i,cases=0;
    reg [87:0] expected;
    task launch;
        begin @(negedge clk);start=1;@(negedge clk);start=0;end
    endtask
    initial begin
        f=$fopen("decimal.txt","r");if(!f)$fatal(1,"Missing decimal fixtures");
        repeat(2)@(negedge clk);rst_n=1;
        while(!$feof(f))begin
            n=$fscanf(f,"%d %d %d %d %d %h\n",cx,cy,area,slots,components,expected);
            if(n!=6)$fatal(1,"Bad fixture");
            launch();
            for(i=1;i<=100;i=i+1)begin
                @(negedge clk);
                if(done!==(i==100))$fatal(1,"Decimal ready latency %0d",i);
            end
            if({x_bcd,y_bcd,area_bcd,slots_bcd,components_bcd}!==expected)$fatal(1,"BCD mismatch case %0d",cases);
            repeat(3)begin @(negedge clk);if(!done)$fatal(1,"Done not held");end
            cases=cases+1;
        end
        // New frame interrupts an in-flight conversion, then completes all zeros.
        cx=2047;cy=2047;area=1048575;slots=255;components=4095;
        launch();repeat(31)@(negedge clk);
        cx=0;cy=0;area=0;slots=0;components=0;launch();
        repeat(100)@(negedge clk);
        if(!done || {x_bcd,y_bcd,area_bcd,slots_bcd,components_bcd}!==0)$fatal(1,"Restart mixes fields");
        launch();repeat(13)@(negedge clk);flush=1;@(negedge clk);flush=0;
        repeat(110)@(negedge clk);if(done)$fatal(1,"Flush did not cancel");
        launch();repeat(37)@(negedge clk);rst_n=0;#1;
        if(done || {x_bcd,y_bcd,area_bcd,slots_bcd,components_bcd}!==0)$fatal(1,"Async reset");
        @(negedge clk);rst_n=1;repeat(110)@(negedge clk);if(done)$fatal(1,"Reset did not cancel");
        $display("PASS DECIMAL: %0d cases, 100-cycle completion, restart, flush, reset",cases);$finish;
    end
endmodule
