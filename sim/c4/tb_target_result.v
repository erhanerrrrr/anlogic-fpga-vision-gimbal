`timescale 1ns/1ps
module tb_target_result;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,valid=0,mask=0,sof=0,eol=0,eof=0;
    reg [23:0] rgb=0;
    reg [10:0] x=0,y=0;
    reg [31:0] fid=0;
    reg [15:0] cfg=0;
    reg [1:0] color=0;
    wire [1:0] strobe,tv;
    wire [31:0] rf[0:1];wire [15:0] rcfg[0:1];wire [1:0] tid[0:1];
    wire [19:0] area[0:1];
    wire [10:0] cx[0:1],cy[0:1],xmin[0:1],xmax[0:1],ymin[0:1],ymax[0:1];
    wire [136:0] packet[0:1];
    mask_target_result direct(clk,rst_n,valid,mask,x,y,sof,eof,fid,cfg,color,
        strobe[0],tv[0],rf[0],rcfg[0],tid[0],area[0],cx[0],xmin[0],xmax[0],cy[0],ymin[0],ymax[0]);
    rgb_target_result chain(clk,rst_n,valid,rgb,x,y,sof,eol,eof,fid,cfg,color,
        strobe[1],tv[1],rf[1],rcfg[1],tid[1],area[1],cx[1],xmin[1],xmax[1],cy[1],ymin[1],ymax[1]);
    genvar j;generate for(j=0;j<2;j=j+1) begin
        assign packet[j]={tv[j],rf[j],rcfg[j],tid[j],area[j],xmin[j],ymin[j],xmax[j],ymax[j],cx[j],cy[j]};
    end endgenerate
    reg [136:0] previous[0:1];
    reg [1:0] pending=0;
    integer input_file,actual,timing,n,w,h,p,abort_at,xx,yy,index,k,path,cycle=0;
    integer frame_eof_cycle[0:1];
    reg [31:0] next_id;integer next_cfg,next_color;
    reg bit_value;
    reg [23:0] value;
    initial begin #100000000;$fatal(1,"watchdog");end
    task beat;
        input reset_value,v,m,accepted;
        input [23:0] rgb_value;
        input integer px,py;
        input s,l,f;
        reg [1:0] expected_strobe;
        begin
            @(negedge clk);
            for(path=0;path<2;path=path+1)
                if(packet[path] !== previous[path]) $fatal(1,"packet changed between edges");
            rst_n=reset_value;valid=v;mask=m;rgb=rgb_value;x=px;y=py;sof=s;eol=l;eof=f;
            #1;
            if(!rst_n && ({strobe,packet[0],packet[1]} !== 276'b0)) $fatal(1,"reset failed");
            expected_strobe=reset_value ? pending : 2'b0;
            @(posedge clk);#1;cycle=cycle+1;
            if(strobe !== expected_strobe) $fatal(1,"result timing mismatch");
            for(path=0;path<2;path=path+1) begin
                if ((^packet[path]) === 1'bx) $fatal(1,"unknown result");
                if(rst_n && !strobe[path] && packet[path] !== previous[path]) $fatal(1,"packet not held");
                if(strobe[path]) $fdisplay(actual,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    path,cycle,rf[path],rcfg[path],tid[path],tv[path],area[path],xmin[path],ymin[path],xmax[path],ymax[path],cx[path],cy[path]);
                previous[path]=packet[path];
            end
            if(f && accepted || strobe!=0 || !rst_n)
                $fdisplay(timing,"%0d,%0d,%0d,%0d,%0d,%0d",cycle,rst_n,fid,accepted&&f,strobe[0],strobe[1]);
            if(!reset_value) pending=0;
            else pending={pending[0],accepted&&f};
        end
    endtask
    initial begin
        previous[0]=0;previous[1]=0;
        $dumpfile("result_trace.vcd");$dumpvars(0,tb_target_result);$dumpoff;
        input_file=$fopen("cases.txt","r");actual=$fopen("actual.csv","w");timing=$fopen("timing.csv","w");
        if(!input_file || !actual || !timing) $fatal(1,"file open failed");
        $fdisplay(actual,"path,cycle,frame_id,cfg_id,target_id,valid,area,xmin,ymin,xmax,ymax,cx,cy");
        $fdisplay(timing,"cycle,rst_n,input_id,input_eof,direct_strobe,chain_strobe");
        beat(0,0,0,0,0,0,0,0,0,0);
        beat(1,1,1,0,24'hc82828,3,2,0,1,1);
        while(!$feof(input_file)) begin
            n=$fscanf(input_file,"%d %d %h %d %d %d %d\n",w,h,next_id,next_cfg,next_color,p,abort_at);
            if(n!=7) $fatal(1,"bad case");
            fid=next_id;cfg=next_cfg;color=next_color;
            for(yy=0;yy<h;yy=yy+1) begin
                for(xx=0;xx<w;xx=xx+1) begin
                    index=yy*w+xx;
                    if(index==abort_at) beat(0,0,0,0,0,0,0,0,0,0);
                    case(p)
                        0:bit_value=(xx>=100 && xx<=140 && yy>=80 && yy<=110);
                        1:bit_value=(xx>=10 && xx<=11 && yy>=20 && yy<=21);
                        2:bit_value=0;
                        3:bit_value=1;
                        4:bit_value=(index==w*h-1);
                        default:$fatal(1,"unknown pattern");
                    endcase
                    if(!bit_value) value=0;
                    else case(color)
                        0:value=24'hc82828;1:value=24'h28c828;2:value=24'h2828c8;
                    endcase
                    if(w==1280 && index==w*h-4) $dumpon;
                    if(w==1280 && index==4) $dumpoff;
                    if(fid==4 && index==5) $dumpoff;
                    beat(1,1,bit_value,(abort_at<0 || index<abort_at),value,xx,yy,index==0,xx==w-1,index==w*h-1);
                end
                if(yy<h-1) for(k=0;k<1+yy%3;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
            end
        end
        for(k=0;k<20;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
        $fclose(input_file);$fclose(actual);$fclose(timing);
        $display("C4_SIM_COMPLETE cycles=%0d",cycle);$finish;
    end
endmodule
