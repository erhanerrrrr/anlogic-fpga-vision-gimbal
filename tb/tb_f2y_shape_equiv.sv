`timescale 1ns/1ps
module tb_f2y_shape_equiv;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,st=0;reg [31:0] id=0;reg [19:0] area=0;reg [1023:0] ext=0;
 wire ad,av,bd,bv;wire [31:0] ai,bi;wire [1:0] ac,bc;
 f_shape_metrics a(.clk(clk),.rst_n(rst),.input_strobe(st),.input_id(id),.input_area(area),.input_extrema(ext),.done(ad),.valid(av),.result_id(ai),.object_class(ac));
 f2x_shape_metrics_reference b(.clk(clk),.rst_n(rst),.input_strobe(st),.input_id(id),.input_area(area),.input_extrema(ext),.done(bd),.valid(bv),.result_id(bi),.object_class(bc));
 integer cycles=0,start_cycle,ref_cycle,seed=32'h4f2a1991,checked=0;
 always @(posedge clk)begin
   cycles=cycles+1;#1;
   if(rst && bd)ref_cycle=cycles;
   if(rst && ad)begin
     if({av,ai,ac}!=={bv,bi,bc})$fatal(1,"result mismatch id=%0d a=%b/%0d b=%b/%0d",id,av,ac,bv,bc);
     if(a.min_box!==b.min_box || a.max_box!==b.max_box || a.octagon2!==b.octagon2 || a.best_short!==b.best_short)$fatal(1,"intermediate arithmetic differs");
     if(cycles-ref_cycle!=140 || cycles-start_cycle>=1100)$fatal(1,"bounded schedule %0d vs %0d",cycles-start_cycle,cycles-ref_cycle);
     checked=checked+1;
   end
 end
 task launch;
 begin @(negedge clk);id=id+1;st=1;start_cycle=cycles+1;@(negedge clk);st=0;end
 endtask
 task finish;
 integer timeout;
 begin timeout=0;while(!ad && timeout<1100)begin @(negedge clk);timeout=timeout+1;end
 if(!ad)$fatal(1,"completion timeout");@(negedge clk);end
 endtask
 integer fd,n,j,k,lo,hi,cancel_at;reg [1:0] expected;
 initial begin
   repeat(4)@(negedge clk);rst=1;
   fd=$fopen("tb/shape_metrics720_vectors.txt","r");
   while(!$feof(fd))begin
     n=$fscanf(fd,"%h %h %h\n",area,expected,ext);
     if(n==3)begin launch();finish();if(!av || ac!=expected)$fatal(1,"integer fixture");end
   end
   $fclose(fd);
   // Wide/adversarial descriptors also exercise 32-bit wrap and invalid paths.
   for(k=0;k<180;k=k+1)begin
     area=$random(seed);
     for(j=0;j<32;j=j+1)begin
       lo=$unsigned($random(seed))%65536;hi=$unsigned($random(seed))%65536;
       ext[j*32+:32]=k%3==0?{16'(hi),16'(lo)}:{16'(lo>hi?lo:hi),16'(lo<hi?lo:hi)};
     end
     if(k%11==0)area=0;
     launch();finish();
   end
   // Restart throughout the original and added serial phases: no stale result.
   for(k=0;k<18;k=k+1)begin
     area=1024;ext={32{32'h003f0020}};launch();
     cancel_at=k<8?1+k*110:905+(k-8)*14;
     repeat(cancel_at)@(negedge clk);
     area=$random(seed);ext={32{32'h005f0010}};launch();
     // Inputs may change immediately after capture.
     area=0;ext=0;finish();
   end
   if(checked!=235)$fatal(1,"missing cases %0d",checked);
   rst=0;repeat(3)@(negedge clk);if(ad || av || ai || ac)$fatal(1,"reset");
   $display("PASS F2Y shared shape arithmetic: 235 frozen-F2X comparisons, full720p integer fixtures, wide malformed descriptors, cancellation across all phases, exact +140-cycle bound under1100");$finish;
 end
endmodule
