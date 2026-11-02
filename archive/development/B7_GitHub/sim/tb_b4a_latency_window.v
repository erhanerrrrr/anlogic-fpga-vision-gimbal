`timescale 1ns/1ps
module tb_b4a_latency_window;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,clear=0,sample_valid=0;
    reg [31:0] sample_us=0;
    reg [1:0] sample_kind=0;
    wire stats_valid;
    wire [1:0] stats_kind;
    wire [31:0] min_us,avg_us,max_us;
    wire [8:0] sample_count;
    latency_window_stats dut(
        .clk(clk),.rst_n(rst_n),.clear(clear),.sample_valid(sample_valid),
        .sample_us(sample_us),.sample_kind(sample_kind),
        .stats_valid(stats_valid),.stats_kind(stats_kind),
        .min_us(min_us),.avg_us(avg_us),.max_us(max_us),
        .sample_count(sample_count));
    task sample;
        input [1:0] kind;
        input [31:0] value;
        begin
            @(negedge clk);sample_kind=kind;sample_us=value;sample_valid=1;
            @(negedge clk);sample_valid=0;
        end
    endtask
    task expect_stats;
        input valid;
        input [1:0] kind;
        input [31:0] lo,mean,hi;
        begin
            if(stats_valid!==valid || (valid &&
                (stats_kind!==kind || min_us!==lo || avg_us!==mean ||
                 max_us!==hi || sample_count!==9'd8)))
                $fatal(1,"stats mismatch valid=%b kind=%d min=%d avg=%d max=%d n=%d",
                    stats_valid,stats_kind,min_us,avg_us,max_us,sample_count);
        end
    endtask
    integer i;
    initial begin
        repeat(3)@(negedge clk);rst_n=1;
        expect_stats(0,0,0,0,0);
        sample(0,0);
        for(i=1;i<7;i=i+1)sample(0,i*10);
        expect_stats(0,0,0,0,0);
        sample(0,70);
        expect_stats(1,0,0,35,70);
        // Idle cycles must not consume the same event again.
        repeat(10)@(negedge clk);
        expect_stats(1,0,0,35,70);
        // The next incomplete window still exposes the last complete one.
        sample(0,123);expect_stats(1,0,0,35,70);
        // A different measurement kind discards a partial window and hides old stats.
        sample(1,32'hffffffff);expect_stats(0,0,0,0,0);
        for(i=1;i<8;i=i+1)sample(1,32'hffffffff);
        expect_stats(1,1,32'hffffffff,32'hffffffff,32'hffffffff);
        // Reserved kind cannot change the displayed kind or count.
        sample(3,0);expect_stats(1,1,32'hffffffff,32'hffffffff,32'hffffffff);
        @(negedge clk);clear=1;
        @(negedge clk);clear=0;
        expect_stats(0,0,0,0,0);
        // A zero measurement is a real sample, distinct from no data.
        for(i=0;i<8;i=i+1)sample(2,0);
        expect_stats(1,2,0,0,0);
        $display("PASS B4A_LATENCY_WINDOW: zero, N/A, kind, max, idle and clear");
        $finish;
    end
endmodule
