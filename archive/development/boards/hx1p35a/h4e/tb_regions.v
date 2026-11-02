`timescale 1ns/1ps
module tb_regions;
    parameter N=68,W=384,H=96;
    reg clk=0,rst=0,v=0,m=0,sof=0,eof=0;
    reg [10:0] x=0,y=0;
    reg [31:0] fid=0;
    wire st,tv,busy;
    wire [2:0] reason;
    wire [1:0] tid;
    wire [31:0] rf;
    wire [15:0] cfg;
    wire [19:0] a;
    wire [10:0] l,r,t,b,cx,cy;
    wire [7:0] used;
    wire [11:0] comps;
    reg pixels[0:N*W*H-1];
    integer f,xx,yy,k,fd,n,ef,period,ev,er,ea,el,ex,et,eb,ecx,ecy,ec,results=0,waits;
    integer work_cycles=0,peak_work=0;
    reg [167:0] held;
    wire [167:0] snapshot={tv,reason,rf,cfg,tid,a,l,r,t,b,cx,cy,used,comps};
    h4e_region_select #(.WIDTH(W),.HEIGHT(H)) dut(clk,rst,v,m,sof,eof,x,y,fid,16'd7,2'd2,
        st,tv,reason,rf,cfg,tid,a,l,r,t,b,cx,cy,used,comps,busy);
    always #5 clk=~clk;
    always @(posedge clk)begin
        #1;
        if(rst && st)results=results+1;
        if(busy)begin work_cycles=work_cycles+1;if(work_cycles>peak_work)peak_work=work_cycles;end
        else work_cycles=0;
    end
    task idle;
        begin @(negedge clk);v=0;sof=0;eof=0;end
    endtask
    task partial;
        begin
            for(k=0;k<W;k=k+1)begin
                @(negedge clk);v=1;m=(k%16<8);x=k;y=0;sof=(k==0);eof=0;fid=999;
            end
            repeat(12)idle();
            if(!busy)$fatal(1,"Partial-frame reset/restart did not interrupt an active RAM job");
        end
    endtask
    initial begin
        $readmemb("simulation/masks.mem",pixels);
        fd=$fopen("simulation/expected.txt","r");
        repeat(3)@(negedge clk);rst=1;
        partial();rst=0;repeat(3)@(negedge clk);rst=1;
        partial();
        for(f=0;f<N;f=f+1)begin
            n=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d\n",ef,period,ev,er,ea,el,ex,et,eb,ecx,ecy,ec);
            if(n!=12)$fatal(1,"Bad expected row");
            held=snapshot;peak_work=0;
            for(yy=0;yy<H;yy=yy+1)begin
                for(xx=0;xx<W;xx=xx+1)begin
                    @(negedge clk);v=1;x=xx;y=yy;sof=(xx==0&&yy==0);eof=(xx==W-1&&yy==H-1);
                    fid=f+1;m=pixels[f*W*H+yy*W+xx];
                    if(snapshot!==held)$fatal(1,"Result changed before complete frame %d",f+1);
                end
                if(yy<H-1)repeat(period-W)idle();
            end
            idle();waits=0;
            while(!st && waits<5000)begin @(negedge clk);waits=waits+1;end
            if(!st)$fatal(1,"Missing result frame %d",f+1);
            if(rf!=ef || tv!=ev || reason!=er || a!=ea || l!=el || r!=ex || t!=et || b!=eb || cx!=ecx || cy!=ecy || comps!=ec || cfg!=7 || tid!=2 || used>128)
                $fatal(1,"frame%0d got V/E/A=%0d/%0d/%0d box=%0d,%0d,%0d,%0d peak=%0d C=%0d expected=%0d/%0d/%0d box=%0d,%0d,%0d,%0d C=%0d",ef,tv,reason,a,l,r,t,b,used,comps,ev,er,ea,el,ex,et,eb,ec);
            $display("FRAME %0d PASS A=%0d E=%0d peak_slots=%0d components=%0d max_row_cycles=%0d EOF_WAIT=%0d",ef,a,reason,used,comps,peak_work,waits);$fflush();
            held=snapshot;
            repeat(5)begin idle();if(snapshot!==held || st)$fatal(1,"Result hold/strobe");end
        end
        if(results!=N)$fatal(1,"Result count %0d",results);
        $display("PASS ROW_REGIONS: %0d independent oracle frames; row recycling and capacity/deadline recovery",N);
        $finish;
    end
    initial begin #200000000;$fatal(1,"Watchdog");end
endmodule
