`timescale 1ns/1ps
module tb_validity_unit;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,s=0;reg [31:0] fid=0;reg [15:0] cfg=0;reg [1:0] color=0;
    reg [19:0] count=0;reg [10:0] l=0,t=0,r=0,b=0;
    wire [1:0] rs,v;wire [31:0] rf[0:1];wire [15:0] rc[0:1];wire [1:0] rt[0:1];
    wire [19:0] a[0:1],dc[0:1];wire [2:0] reason[0:1];
    wire [10:0] cx[0:1],cy[0:1],x0[0:1],y0[0:1],x1[0:1],y1[0:1],dl[0:1],dt[0:1],dr[0:1],db[0:1];
    genvar g;generate for(g=0;g<2;g=g+1) begin
        target_validated_pack #(.MAX_AREA(g==0?921600:100)) dut(clk,rst_n,s,fid,cfg,color,count,l,t,r,b,
            rs[g],v[g],rf[g],rc[g],rt[g],a[g],cx[g],x0[g],x1[g],cy[g],y0[g],y1[g],reason[g],dc[g],dl[g],dt[g],dr[g],db[g]);
    end endgenerate
    integer src,dst,n,id,reset_value,strobe_value,ncount,nl,nt,nr,nb,p;
    initial begin #1000000;$fatal(1,"watchdog");end
    initial begin
        src=$fopen("unit.txt","r");dst=$fopen("unit_actual.csv","w");
        if(!src || !dst) $fatal(1,"file open failed");
        $fdisplay(dst,"id,profile,strobe,frame_id,cfg_id,target_id,valid,area,xmin,ymin,xmax,ymax,cx,cy,reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax");
        while(!$feof(src)) begin
            n=$fscanf(src,"%d %d %d %d %d %d %d %d\n",id,reset_value,strobe_value,ncount,nl,nt,nr,nb);
            if(n!=8) $fatal(1,"bad unit vector");
            @(negedge clk);rst_n=reset_value;s=strobe_value;fid=id;cfg=id%65536;color=id%3;
            count=ncount;l=nl;t=nt;r=nr;b=nb;
            @(posedge clk);#1;
            for(p=0;p<2;p=p+1) begin
                if((^{rs[p],v[p],rf[p],rc[p],rt[p],a[p],x0[p],y0[p],x1[p],y1[p],cx[p],cy[p],reason[p],dc[p],dl[p],dt[p],dr[p],db[p]})===1'bx)
                    $fatal(1,"unknown unit output");
                $fdisplay(dst,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    id,p,rs[p],rf[p],rc[p],rt[p],v[p],a[p],x0[p],y0[p],x1[p],y1[p],cx[p],cy[p],reason[p],dc[p],dl[p],dt[p],dr[p],db[p]);
            end
        end
        $fclose(src);$fclose(dst);$display("C6_UNIT_COMPLETE");$finish;
    end
endmodule
