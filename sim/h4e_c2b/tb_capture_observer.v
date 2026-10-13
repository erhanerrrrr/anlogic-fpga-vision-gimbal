`timescale 1ns/1ps
module tb_capture_observer;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=1,packet_strobe=0,source_flush=0;
    reg [31:0] active_epoch=0,packet_epoch=0,packet_frame_id=0;
    wire result_strobe,new_observation;
    capture_observation_guard dut(.*);
    integer src,dst,n,cycle;
    initial begin
        src=$fopen("observer.txt","r");dst=$fopen("observer_actual.csv","w");
        if(!src || !dst)$fatal(1,"file open");
        $fdisplay(dst,"cycle,result_strobe,new_observation");
        while(!$feof(src)) begin
            @(negedge clk);
            n=$fscanf(src,"%d %d %d %d %h %h %h\n",cycle,rst_n,packet_strobe,source_flush,active_epoch,packet_epoch,packet_frame_id);
            if(n!=7)$fatal(1,"bad observer vector");
            @(posedge clk);
            if((^{result_strobe,new_observation})===1'bx)$fatal(1,"unknown flags");
            $fdisplay(dst,"%0d,%0d,%0d",cycle,result_strobe,new_observation);
        end
        $fclose(src);$fclose(dst);$display("H4E_C2B_OBSERVER_COMPLETE");$finish;
    end
    initial begin #100000;$fatal(1,"observer watchdog");end
endmodule
