`timescale 1ns/1ps
module tb_denoised_result;
    parameter WIDTH=64,HEIGHT=48,LINE_GAPS=1;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,valid=0,mask=0,sof=0,eol=0,eof=0,accepted=0;
    reg [23:0] rgb=0;reg [10:0] x=0,y=0;
    reg [31:0] fid=0;reg [15:0] cfg=0;reg [1:0] color=0;
    wire [1:0] fv,fm,fs,fl,fe,rs,tv;
    wire [10:0] fx[0:1],fy[0:1];wire [31:0] ff[0:1];wire [15:0] fc[0:1];wire [1:0] ft[0:1];
    wire [31:0] rf[0:1];wire [15:0] rc[0:1];wire [1:0] rt[0:1];wire [19:0] area[0:1];
    wire [10:0] cx[0:1],cy[0:1],xmin[0:1],ymin[0:1],xmax[0:1],ymax[0:1];
    wire [75:0] mp[0:1];wire [136:0] rp[0:1];
    mask_denoised_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) direct(
        clk,rst_n,valid,mask,x,y,sof,eof,fid,cfg,color,
        fv[0],fm[0],fx[0],fy[0],fs[0],fl[0],fe[0],ff[0],fc[0],ft[0],
        rs[0],tv[0],rf[0],rc[0],rt[0],area[0],cx[0],xmin[0],xmax[0],cy[0],ymin[0],ymax[0]);
    rgb_denoised_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) chain(
        clk,rst_n,valid,rgb,x,y,sof,eol,eof,fid,cfg,color,
        fv[1],fm[1],fx[1],fy[1],fs[1],fl[1],fe[1],ff[1],fc[1],ft[1],
        rs[1],tv[1],rf[1],rc[1],rt[1],area[1],cx[1],xmin[1],xmax[1],cy[1],ymin[1],ymax[1]);
    genvar g;generate for(g=0;g<2;g=g+1) begin
        assign mp[g]={fm[g],fs[g],fl[g],fe[g],fx[g],fy[g],ff[g],fc[g],ft[g]};
        assign rp[g]={tv[g],rf[g],rc[g],rt[g],area[g],xmin[g],ymin[g],xmax[g],ymax[g],cx[g],cy[g]};
    end endgenerate
    integer masks[0:1],results,timing,source,n,pattern,abort_flag,next_cfg,next_color;
    integer xx,yy,idx,k,path,cycle=0,left,top,delta;
    integer row_pos[0:1];reg [1:0] pending[0:1];reg [136:0] previous[0:1];
    reg [31:0] next_id,noise;
    reg bit_value;reg [23:0] value;
    initial begin #200000000;$fatal(1,"watchdog");end
    always @(posedge clk) begin
        #1;
        if($time>10) begin
            cycle=cycle+1;
            if(accepted && eof && rst_n) $fdisplay(timing,"input,-1,%0d,%0d",fid,cycle);
            for(path=0;path<2;path=path+1) begin
                if(!rst_n) begin
                    if({fv[path],rs[path],mp[path],rp[path]} !== 215'b0) $fatal(1,"reset output mismatch");
                    pending[path]=0;row_pos[path]=0;
                end else begin
                    if((^{fv[path],rs[path],mp[path],rp[path]})===1'bx) $fatal(1,"unknown output");
                    if(rs[path] !== pending[path][1]) $fatal(1,"result not driven by filtered EOF");
                    if(!rs[path] && rp[path] !== previous[path]) $fatal(1,"result not held");
                    pending[path]={pending[path][0],fv[path]&&fe[path]};
                    if(fv[path]) begin
                        $fdisplay(masks[path],"%h",mp[path]);
                        if(fx[path] != row_pos[path]) $fatal(1,"row order error");
                        row_pos[path]=fl[path]?0:row_pos[path]+1;
                        if(fe[path]) $fdisplay(timing,"filtered,%0d,%0d,%0d",path,ff[path],cycle);
                    end else begin
                        if(mp[path] !== 76'b0) $fatal(1,"invalid mask fields not zero");
                        if(row_pos[path]!=0) $fatal(1,"gap inside output row");
                    end
                    if(rs[path]) begin
                        $fdisplay(results,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                            path,cycle,rf[path],rc[path],rt[path],tv[path],area[path],xmin[path],ymin[path],xmax[path],ymax[path],cx[path],cy[path]);
                        $fdisplay(timing,"result,%0d,%0d,%0d",path,rf[path],cycle);
                        if(path==1 && rf[path]==10) $dumpoff;
                    end
                end
                previous[path]=rp[path];
            end
        end
    end
    task beat;
        input reset_value,v,m,a;
        input [23:0] rgb_value;
        input integer px,py;
        input s,l,f;
        begin
            @(negedge clk);rst_n=reset_value;valid=v;mask=m;accepted=a;rgb=rgb_value;
            x=px;y=py;sof=s;eol=l;eof=f;
            @(posedge clk);#2;
        end
    endtask
    initial begin
        row_pos[0]=0;row_pos[1]=0;pending[0]=0;pending[1]=0;previous[0]=0;previous[1]=0;
        $dumpfile("filter_trace.vcd");$dumpvars(0,tb_denoised_result);$dumpoff;
        masks[0]=$fopen("mask0.hex","w");masks[1]=$fopen("mask1.hex","w");
        results=$fopen("actual.csv","w");timing=$fopen("timing.csv","w");source=$fopen("cases.txt","r");
        if(!masks[0] || !masks[1] || !results || !timing || !source) $fatal(1,"file open failed");
        $fdisplay(results,"path,cycle,frame_id,cfg_id,target_id,valid,area,xmin,ymin,xmax,ymax,cx,cy");
        $fdisplay(timing,"kind,path,frame_id,cycle");
        beat(0,0,0,0,0,0,0,0,0,0);
        beat(1,1,1,0,24'hc82828,7,2,0,1,1);
        while(!$feof(source)) begin
            n=$fscanf(source,"%h %d %d %d %d\n",next_id,pattern,abort_flag,next_cfg,next_color);
            if(n!=5) $fatal(1,"bad input case");
            fid=next_id;cfg=next_cfg;color=next_color;
            left=(WIDTH>=640)?100:10;top=(HEIGHT>=360)?80:8;
            for(yy=0;yy<HEIGHT;yy=yy+1) begin
                for(xx=0;xx<WIDTH;xx=xx+1) begin
                    idx=yy*WIDTH+xx;
                    if(abort_flag && idx==2*WIDTH+7) beat(0,0,0,0,0,0,0,0,0,0);
                    bit_value=0;
                    case(pattern)
                        0,1: begin
                            bit_value=(xx>=left && xx<=left+40 && yy>=top && yy<=top+30);
                            if(pattern==1) begin
                                if(xx==left+20 && yy==top+15) bit_value=0;
                                if(xx==2 && yy==2) bit_value=1;
                            end
                        end
                        2:bit_value=(xx==10 && yy==10);
                        3:bit_value=(xx%8==3 && yy%8==3);
                        4:bit_value=(xx==WIDTH/2 && yy>=2 && yy<HEIGHT-2);
                        5:bit_value=(xx<=8 && yy<=6);
                        6,7:begin
                            delta=(yy-5)*3+(xx-5);
                            if(xx>=5 && xx<=7 && yy>=5 && yy<=7)
                                bit_value=(delta==0 || delta==2 || delta==6 || delta==8 || (pattern==6 && delta==4));
                        end
                        8:bit_value=1;
                        9:bit_value=0;
                        10:begin
                            noise=(idx+20261005)*32'd1664525+32'd1013904223;
                            bit_value=(noise[31:24]<96);
                        end
                    endcase
                    if(!bit_value) value=0;
                    else case(color)
                        0:value=24'hc82828;1:value=24'h28c828;2:value=24'h2828c8;
                    endcase
                    if(fid==10 && idx==WIDTH*HEIGHT-4) $dumpon;
                    beat(1,1,bit_value,(!abort_flag || idx<2*WIDTH+7),value,xx,yy,
                        idx==0,xx==WIDTH-1,idx==WIDTH*HEIGHT-1);
                end
                if(yy<HEIGHT-1 && LINE_GAPS) for(k=0;k<1+yy%3;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
            end
        end
        for(k=0;k<WIDTH+20;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
        $fclose(masks[0]);$fclose(masks[1]);$fclose(results);$fclose(timing);$fclose(source);
        $display("C5_SIM_COMPLETE cycles=%0d",cycle);$finish;
    end
endmodule
