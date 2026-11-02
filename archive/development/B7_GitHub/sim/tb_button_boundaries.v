`timescale 1ns/1ps
// Real default N is exercised without accelerating or forcing the counters.
module tb_button_boundaries;
    parameter integer N=750000,ACTIVE_LOW=1;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0;
    reg [2:0] pins=ACTIVE_LOW?3'b111:3'b000;
    wire [2:0] pressed,events,req;
    wire [1:0] requested;
    wire rv;
    integer cycles=0,count0=0,count1=0,count2=0,expected_requested=0,scenarios=0;
    integer i,start_cycle,old0,old1,old2,trace;
    reg [2:0] before_event;
    button_mode_request #(.DEBOUNCE_CYCLES(N),.ACTIVE_LOW(ACTIVE_LOW)) dut(
        .clk(clk),.rst_n(rst_n),.buttons_async(pins),.pressed(pressed),.press_event(events),
        .requested_mode(requested),.mode_req_valid(rv),.mode_req(req));
    always @(posedge clk)begin
        cycles=cycles+1;before_event=events;
        #1;
        if(!rst_n)begin count0=0;count1=0;count2=0;expected_requested=0;end
        else begin
            if(before_event[0])expected_requested=(expected_requested+1)%4;
            if(requested!==expected_requested)$fatal(1,"Requested mode did not count consumed presses");
            if(rv!==events[0] || req!=={1'b0,(requested+2'd1)})$fatal(1,"Request routing/value");
            if((events & ~pressed)!=0 || (events & before_event)!=0)$fatal(1,"Invalid event level or wider than one cycle");
            if(events[0])count0=count0+1;
            if(events[1])count1=count1+1;
            if(events[2])count2=count2+1;
            if(events)$fwrite(trace,"%0d,%0d,%0d,%0d,%0d\n",cycles,pressed,events,requested,req);
        end
    end
    task step;input [2:0] normalized;begin
        @(negedge clk);pins=ACTIVE_LOW?~normalized:normalized;
        @(posedge clk);#2;
    end endtask
    task hold;input [2:0] normalized;input integer n;begin repeat(n)step(normalized);end endtask
    task reset;begin
        rst_n=0;hold(0,3);rst_n=1;hold(0,3);
        if(pressed || events || requested)$fatal(1,"Reset state");
    end endtask
    task check_counts;input integer a,b,c;begin
        if(count0!=a || count1!=b || count2!=c)$fatal(1,"Event counts expected=%d/%d/%d actual=%d/%d/%d",a,b,c,count0,count1,count2);
    end endtask
    initial begin
        trace=$fopen("button_events.csv","w");$fwrite(trace,"cycle,pressed,event,requested_mode,next_request\n");
        reset();
        // Raw level for N-1 clocks remains N-1 clocks after synchronization.
        if(N>1)begin
            hold(3'b111,N-1);hold(0,N+3);check_counts(0,0,0);
            if(pressed)$fatal(1,"N-1 press was accepted");scenarios=scenarios+1;
        end
        // Exactly N raw clocks: event is visible two clocks after last raw sample.
        hold(3'b111,N);check_counts(0,0,0);
        step(0);check_counts(0,0,0);step(0);check_counts(1,1,1);
        if(pressed!==3'b111 || events!==3'b111)$fatal(1,"Exact N boundary");
        hold(0,N+3);if(pressed)$fatal(1,"Exact release did not rearm");scenarios=scenarios+1;
        // N+1 press and then release: still exactly one event per key.
        hold(3'b111,N+1);step(0);check_counts(2,2,2);hold(0,N+3);scenarios=scenarios+1;
        // Long hold and too-short release must never auto-repeat or rearm early.
        hold(3'b111,2*N+5);check_counts(3,3,3);
        if(N>1)begin hold(0,N-1);hold(3'b111,N+3);check_counts(3,3,3);end
        hold(3'b111,N+5);check_counts(3,3,3);hold(0,N+3);scenarios=scenarios+1;
        // Three independent bits: calibration and tracking do not advance mode.
        hold(3'b010,N+3);hold(0,N+3);check_counts(3,4,3);
        hold(3'b100,N+3);hold(0,N+3);check_counts(3,4,4);
        hold(3'b001,N+3);hold(0,N+3);check_counts(4,4,4);
        if(requested!==2'd0)$fatal(1,"Four presses did not wrap to RAW");scenarios=scenarios+1;
        // Alternating bounce below N, then settle once. N=1 intentionally has no rejection window.
        if(N>1)begin
            for(i=0;i<8;i=i+1)begin step(3'b111);step(0);end
            hold(0,N+3);check_counts(4,4,4);
            hold(3'b111,N+3);hold(0,N+3);check_counts(5,5,5);scenarios=scenarios+1;
        end
        // Reset while held: after reset the held level is recognized once again.
        hold(3'b111,N+3);rst_n=0;hold(3'b111,3);rst_n=1;
        hold(3'b111,N+1);check_counts(0,0,0);
        step(3'b111);check_counts(1,1,1);hold(3'b111,N+3);check_counts(1,1,1);
        hold(0,N+3);if(pressed)$fatal(1,"Release after reset");scenarios=scenarios+1;
        $fclose(trace);$display("PASS BUTTON_BOUNDARIES: N=%0d polarity=%0d scenarios=%0d",N,ACTIVE_LOW,scenarios);$finish;
    end
    initial begin #1000000000;$fatal(1,"Watchdog");end
endmodule
