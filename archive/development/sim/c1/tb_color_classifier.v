`timescale 1ns/1ps
module tb_color_classifier;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, pixel_valid=0;
    reg [23:0] rgb=0;
    reg [1:0] active_color=0;
    wire [3:0] valids, masks;
    color_classifier d0(clk,rst_n,pixel_valid,rgb,active_color,valids[0],masks[0]);
    color_classifier #(.MIN_MAIN(0),.MIN_DIFF_1(0),.MIN_DIFF_2(0)) d1
        (clk,rst_n,pixel_valid,rgb,active_color,valids[1],masks[1]);
    color_classifier #(.MIN_MAIN(255),.MIN_DIFF_1(255),.MIN_DIFF_2(255)) d2
        (clk,rst_n,pixel_valid,rgb,active_color,valids[2],masks[2]);
    color_classifier #(.MIN_MAIN(120),.MIN_DIFF_1(30),.MIN_DIFF_2(90)) d3
        (clk,rst_n,pixel_valid,rgb,active_color,valids[3],masks[3]);
    integer src, dst, n, id, reset_value, valid_value, color_value, rgb_value;
    reg [3:0] previous_valid, previous_mask;
    initial begin
        #2000000;
        $display("FAIL: watchdog");
        $fatal(1);
    end
    initial begin
        src=$fopen("vectors.txt","r");
        dst=$fopen("actual.csv","w");
        if (!src || !dst) $fatal(1,"file open failed");
        $fdisplay(dst,"id,valid0,mask0,valid1,mask1,valid2,mask2,valid3,mask3");
        #1;
        previous_valid=valids;
        previous_mask=masks;
        while (!$feof(src)) begin
            n=$fscanf(src,"%d %d %d %d %h\n",id,reset_value,valid_value,color_value,rgb_value);
            if (n != 5) $fatal(1,"bad vector");
            @(negedge clk);
            if (id > 0 && (valids !== previous_valid || masks !== previous_mask))
                $fatal(1,"output did not hold between sampling edges");
            rst_n=reset_value;
            pixel_valid=valid_value;
            active_color=color_value;
            rgb=rgb_value;
            #1;
            if (!rst_n && (valids !== 4'b0 || masks !== 4'b0))
                $fatal(1,"asynchronous reset did not clear outputs");
            if (rst_n && id > 0 && (valids !== previous_valid || masks !== previous_mask))
                $fatal(1,"output changed before clock");
            @(posedge clk);
            #1;
            if ((^valids === 1'bx) || (^masks === 1'bx)) $fatal(1,"unknown output");
            $fdisplay(dst,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",id,
                valids[0],masks[0],valids[1],masks[1],valids[2],masks[2],valids[3],masks[3]);
            previous_valid=valids;
            previous_mask=masks;
        end
        $fclose(src);
        $fclose(dst);
        $display("C1_SIM_COMPLETE");
        $finish;
    end
endmodule
