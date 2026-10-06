`timescale 1ns/1ps
module tb_validated_rgb;
    parameter WIDTH=64,HEIGHT=48,MAX_AREA=WIDTH*HEIGHT;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,v=0,s=0,l=0,f=0,accepted=0;
    reg [23:0] rgb=0;reg [10:0] x=0,y=0;reg [31:0] fid=0;
    reg [15:0] cfg=0;reg [1:0] color=0;
    wire fv,fm,fs,fl,fe,rs,tv;wire [10:0] fx,fy;wire [31:0] ff,rf;
    wire [15:0] fc,rc;wire [1:0] ft,rt;wire [19:0] area,dc;wire [2:0] reason;
    wire [10:0] cx,cy,x0,y0,x1,y1,dl,dt,dr,db;
    rgb_validated_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_AREA(MAX_AREA)) dut(
        clk,rst_n,v,rgb,x,y,s,l,f,fid,cfg,color,
        fv,fm,fx,fy,fs,fl,fe,ff,fc,ft,rs,tv,rf,rc,rt,area,cx,x0,x1,cy,y0,y1,reason,dc,dl,dt,dr,db);
    wire [203:0] packet={rf,rc,rt,tv,area,x0,y0,x1,y1,cx,cy,reason,dc,dl,dt,dr,db};
    reg [203:0] previous=0;reg [2:0] pending=0;
    integer src,results,timing,counts,n,pattern,abort_flag,next_cfg,next_color;
    integer xx,yy,idx,k,cycle=0,out_index=0,ones=0;
    reg [31:0] next_id,observed_id;reg [15:0] observed_cfg;reg [1:0] observed_color;
    reg bit_value;reg [23:0] value;
    initial begin #200000000;$fatal(1,"watchdog");end
    always @(posedge clk) begin
        #1;
        if($time>10) begin
            cycle=cycle+1;
            if(rst_n && accepted && f) $fdisplay(timing,"input,%0d,%0d",fid,cycle);
            if(!rst_n) begin
                if({rs,packet}!==205'b0) $fatal(1,"reset failed");
                pending=0;out_index=0;ones=0;
            end else begin
                if((^{rs,packet,fv,fm,fs,fl,fe,fx,fy,ff,fc,ft})===1'bx) $fatal(1,"unknown output");
                if(rs!==pending[2]) $fatal(1,"C6 notification timing mismatch");
                if(!rs && packet!==previous) $fatal(1,"packet not held");
                pending={pending[1:0],fv&&fe};
                if(fv) begin
                    if(fx!=out_index%WIDTH || fy!=out_index/WIDTH || fs!=(out_index==0) ||
                       fl!=(out_index%WIDTH==WIDTH-1) || fe!=(out_index==WIDTH*HEIGHT-1)) $fatal(1,"filtered stream mismatch");
                    if(fs) begin observed_id=ff;observed_cfg=fc;observed_color=ft;ones=0;end
                    if(ff!=observed_id || fc!=observed_cfg || ft!=observed_color) $fatal(1,"filtered metadata changed");
                    ones=ones+fm;out_index=out_index+1;
                    if(fe) begin
                        $fdisplay(counts,"%0d,%0d,%0d,%0d,%0d",ff,fc,ft,out_index,ones);
                        $fdisplay(timing,"filtered,%0d,%0d",ff,cycle);out_index=0;
                    end
                end
                if(rs) begin
                    $fdisplay(results,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                        cycle,rf,rc,rt,tv,area,x0,y0,x1,y1,cx,cy,reason,dc,dl,dt,dr,db);
                    $fdisplay(timing,"result,%0d,%0d",rf,cycle);
                    if(rf==20) $dumpoff;
                end
            end
            previous=packet;
        end
    end
    task beat;
        input reset_value,valid_value,a;
        input [23:0] rgb_value;
        input integer px,py;
        input start_flag,line_flag,end_flag;
        begin
            @(negedge clk);rst_n=reset_value;v=valid_value;accepted=a;rgb=rgb_value;
            x=px;y=py;s=start_flag;l=line_flag;f=end_flag;
            @(posedge clk);#2;
        end
    endtask
    initial begin
        $dumpfile("validity_trace.vcd");$dumpvars(0,tb_validated_rgb);$dumpoff;
        src=$fopen("cases.txt","r");results=$fopen("actual.csv","w");timing=$fopen("timing.csv","w");counts=$fopen("filtered_counts.csv","w");
        if(!src || !results || !timing || !counts) $fatal(1,"file open failed");
        $fdisplay(results,"cycle,frame_id,cfg_id,target_id,valid,area,xmin,ymin,xmax,ymax,cx,cy,reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax");
        $fdisplay(timing,"kind,frame_id,cycle");$fdisplay(counts,"frame_id,cfg_id,target_id,pixels,ones");
        beat(0,0,0,0,0,0,0,0,0);beat(1,1,0,24'hc82828,7,2,0,1,1);
        while(!$feof(src)) begin
            n=$fscanf(src,"%h %d %d %d %d\n",next_id,pattern,abort_flag,next_cfg,next_color);
            if(n!=5) $fatal(1,"bad scene");
            fid=next_id;cfg=next_cfg;color=next_color;
            for(yy=0;yy<HEIGHT;yy=yy+1) begin
                for(xx=0;xx<WIDTH;xx=xx+1) begin
                    idx=yy*WIDTH+xx;
                    if(abort_flag && idx==2*WIDTH+7) beat(0,0,0,0,0,0,0,0,0);
                    case(pattern)
                        0:bit_value=(xx>=100 && xx<=140 && yy>=80 && yy<=110);
                        1:bit_value=((xx>=100 && xx<=140)||(xx>=300 && xx<=340)) && yy>=80 && yy<=110;
                        2:bit_value=((xx>=100 && xx<=140)||(xx>=142 && xx<=182)) && yy>=80 && yy<=110;
                        3:bit_value=0;
                        4:bit_value=xx>=10 && xx<=12 && yy>=10 && yy<=12;
                        5:bit_value=xx>=10 && xx<=13 && yy>=10 && yy<=13;
                        6:bit_value=xx>=10 && xx<=11 && yy>=10 && yy<=19;
                        7:bit_value=1;
                        default:$fatal(1,"unknown pattern");
                    endcase
                    if(!bit_value) value=0;
                    else case(color)
                        0:value=24'hc82828;1:value=24'h28c828;2:value=24'h2828c8;
                    endcase
                    if(fid==20 && idx==WIDTH*HEIGHT-4) $dumpon;
                    beat(1,1,(!abort_flag || idx<2*WIDTH+7),value,xx,yy,idx==0,xx==WIDTH-1,idx==WIDTH*HEIGHT-1);
                end
                if(yy<HEIGHT-1) for(k=0;k<1+yy%3;k=k+1) beat(1,0,0,0,0,0,0,0,0);
            end
        end
        for(k=0;k<WIDTH+20;k=k+1) beat(1,0,0,0,0,0,0,0,0);
        $fclose(src);$fclose(results);$fclose(timing);$fclose(counts);
        $display("C6_CHAIN_COMPLETE cycles=%0d",cycle);$finish;
    end
endmodule
