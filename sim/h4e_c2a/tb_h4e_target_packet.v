`timescale 1ns/1ps
module tb_h4e_target_packet;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=1,s=0;
    reg [191:0] sample=0;
    wire [191:0] payload;
    wire result_strobe;
    h4e_target_packet dut(.clk(clk),.rst_n(rst_n),.t_result_strobe(s),
        .t_target_valid(sample[191]),
        .t_frame_id(sample[190:159]),
        .t_capture_epoch(sample[158:127]),
        .t_cfg_id(sample[126:111]),
        .t_target_id(sample[110:109]),
        .t_area(sample[108:89]),
        .t_cx(sample[88:78]),
        .t_cy(sample[77:67]),
        .t_xmin(sample[66:56]),
        .t_xmax(sample[55:45]),
        .t_ymin(sample[44:34]),
        .t_ymax(sample[33:23]),
        .t_reason(sample[22:20]),
        .t_peak_slots(sample[19:12]),
        .t_component_count(sample[11:0]),
        .result_strobe(result_strobe),
        .target_valid(payload[191]),
        .frame_id(payload[190:159]),
        .capture_epoch(payload[158:127]),
        .cfg_id(payload[126:111]),
        .target_id(payload[110:109]),
        .area(payload[108:89]),
        .cx(payload[88:78]),
        .cy(payload[77:67]),
        .xmin(payload[66:56]),
        .xmax(payload[55:45]),
        .ymin(payload[44:34]),
        .ymax(payload[33:23]),
        .reject_reason(payload[22:20]),
        .peak_slots(payload[19:12]),
        .component_count(payload[11:0]));
    integer src,dst,n,cycle,reset_value,strobe_value;
    initial begin #1000000; $fatal(1,"unit watchdog"); end
    initial begin
        src=$fopen("unit.txt","r"); dst=$fopen("unit_actual.csv","w");
        if (!src || !dst) $fatal(1,"unit file open");
        $fdisplay(dst,"cycle,result_strobe,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count");
        while (!$feof(src)) begin
            @(negedge clk);
            n=$fscanf(src,"%d %d %d %h\n",cycle,reset_value,strobe_value,sample);
            if(n!=4) $fatal(1,"bad unit vector");
            rst_n=reset_value; s=strobe_value;
            #1;
            if(!rst_n && {result_strobe,payload}!==193'd0)
                $fatal(1,"asynchronous reset did not clear full packet");
            @(posedge clk); #1;
            if ((^{result_strobe,payload})===1'bx) $fatal(1,"unknown output");
            $fdisplay(dst,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,result_strobe,payload[191],payload[190:159],payload[158:127],payload[126:111],payload[110:109],payload[108:89],payload[88:78],payload[77:67],payload[66:56],payload[55:45],payload[44:34],payload[33:23],payload[22:20],payload[19:12],payload[11:0]);
        end
        $fclose(src); $fclose(dst);
        $display("H4E_C2A_UNIT_COMPLETE"); $finish;
    end
endmodule
