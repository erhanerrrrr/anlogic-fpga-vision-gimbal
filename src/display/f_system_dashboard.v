// one decimal engine and one shared OSD/Logo for AE and latency pages.
module f_system_dashboard(
 input clk,rst_n,sof,input [10:0] x,y,input latency_page,
 input [81:0] ae_status,input [2:0] state,
 input [1:0] status,scale,input paused,clear,publish,
 input [11:0] current_tenths,min_tenths,max_tenths,
 input [15:0] samples,repeats,invalid,capture_fps,display_fps,input [31:0] frame_id,
 output reg [511:0] textline,output draw,output [23:0] pixel
);
 wire [1:0] mode=ae_status[81:80];wire [3:0] aes=ae_status[79:76];
 wire [7:0] target=ae_status[75:68],mean=ae_status[67:60];
 wire [11:0] clipped=ae_status[59:48];wire [15:0] exposure=ae_status[47:32],gain_index=ae_status[31:16],updates=ae_status[15:0];
 wire [6:0] index=gain_index[6:0]-7'd16;
 wire [8:0] gain_q5=index<32?9'd32+index:index<64?9'd64+((index-32)<<1):9'd128;
 wire [19:0] exp_tenths=({1'b0,exposure[10:0]}+12'd6)/12'd12;
 wire [19:0] gain_hundredths=(gain_q5*16'd100+16'd16)>>5;
 wire [159:0] values=latency_page?
   {4'd0,invalid,4'd0,samples,4'd0,repeats,4'd0,display_fps,4'd0,capture_fps,8'd0,max_tenths,8'd0,min_tenths,8'd0,current_tenths}:
   {4'd0,updates,4'd0,exposure,8'd0,clipped,12'd0,mean,12'd0,target,gain_hundredths,exp_tenths,20'd0};
 wire [191:0] bcd;
 f_lab_numbers numbers(.clk(clk),.rst_n(rst_n),.start(sof),.values(values),.digits(bcd));
 function [7:0] d;input [3:0] n;begin d=8'd48+n;end endfunction
 function [23:0] n3;input [11:0] n;begin n3={d(n[11:8]),d(n[7:4]),d(n[3:0])};end endfunction
 function [31:0] n4;input [15:0] n;begin n4={d(n[15:12]),n3(n[11:0])};end endfunction
 function [39:0] n5;input [19:0] n;begin n5={d(n[19:16]),n4(n[15:0])};end endfunction
 function [39:0] ms;input [15:0] n;begin ms={n3(n[15:4]),".",d(n[3:0])};end endfunction
 function [7:0] hc;input [3:0] n;begin hc=n<10?48+n:55+n;end endfunction
 function [63:0] hex8;input [31:0] n;begin hex8={hc(n[31:28]),hc(n[27:24]),hc(n[23:20]),hc(n[19:16]),hc(n[15:12]),hc(n[11:8]),hc(n[7:4]),hc(n[3:0])};end endfunction
 reg [127:0] name;reg [95:0] control_name;
 always @*begin
   case(state)
     0:control_name="OFF         ";1:control_name="REACQUIRE   ";2:control_name="TRACK       ";
     3:control_name="LOSS HOLD   ";4:control_name="TIMEOUT HOLD";5:control_name="OBSERVE HOLD";default:control_name="FAULT       ";
   endcase
   name=0;textline=0;
   if(latency_page)begin
     case(status)0:name="WAIT CAPTURE    ";1:name="LIVE            ";2:name="STALE VIDEO     ";default:name="INVALID TAG     ";endcase
     case(y[7:5])
     0:textline={"F3A LATENCY  STATE ",control_name,264'b0};
     1:textline={"CSI SOF TO HDMI INPUT  ",name,200'b0};
     2:textline={"NOW ",ms(bcd[15:0])," MS   MIN ",ms(bcd[39:24]),"   MAX ",ms(bcd[63:48])," MS",200'b0};
     3:textline={"CAP FPS ",n3(bcd[83:72])," DISP FPS ",n3(bcd[107:96])," REPEATS ",n5(bcd[139:120]),208'b0};
     4:textline={"FRAME ",hex8(frame_id)," HEX  SAMPLES ",n5(bcd[163:144])," INVALID ",n5(bcd[187:168]),136'b0};
     5:textline={"GRAPH ",(scale==0?"064":scale==1?"128":"256")," MS   LAST 64 DISPLAYS   ",(paused?"PAUSED":"RUN   "),192'b0};
     6:textline={"K1 FREEZE  K2 SCALE  K3 CLEAR",280'b0};
     7:textline={"SW1 OFF K4 PAGE  K4 STOP WHEN ENABLED",216'b0};
     endcase
   end else begin
     case(aes)
       0:name="STARTING        ";1:name="ADJUSTING       ";2:name="STABLE          ";3:name="DARK LIMIT      ";
       4:name="BRIGHT LIMIT    ";5:name="FIXED BASELINE  ";6:name="HOLD CURRENT    ";7:name="NO FRESH VIDEO  ";
       8:name="I2C ERROR RESET ";10:name="HIGHLIGHT LIMIT ";default:name="SETTLING        ";
     endcase
     case(y[7:5])
     0:textline={"F3A SENSOR AE  STATE ",control_name,248'b0};
     1:textline={"MODE ",(mode==0?"AUTO ":mode==1?"FIXED":"HOLD "),"   ",name,280'b0};
     2:textline={"EXPOSURE ",d(bcd[35:32]),d(bcd[31:28]),".",d(bcd[27:24])," MS    GAIN ",d(bcd[59:56]),".",d(bcd[55:52]),d(bcd[51:48])," X",264'b0};
     3:textline={"MEAN ",n3(bcd[107:96]),"  TARGET ",n3(bcd[83:72]),"  CLIPPED ",n4(bcd[135:120])," /2048",192'b0};
     4:textline={"EXPOSURE ",n4(bcd[159:144])," HALF LINES  WRITES ",n5(bcd[187:168]),208'b0};
     5:textline={"K2 AUTO 112/96/128/FIXED  K3 HOLD",248'b0};
     6:textline={"K1 NEXT MODE  SW1 OFF K4 PAGE",280'b0};
     7:textline={"SENSOR AE/AGC  FIXED WB  K4 STOP",256'b0};
     endcase
   end
 end
 // No reset over the history RAM: valid_count masks old samples after clear.
 reg [11:0] history[0:63];reg [5:0] cursor;reg [6:0] valid_count;
 always @(posedge clk)if(publish && !clear)history[cursor]<=current_tenths;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin cursor<=0;valid_count<=0;end
 else if(clear)begin cursor<=0;valid_count<=0;end
 else if(publish)begin cursor<=cursor+1'b1;if(valid_count<64)valid_count<=valid_count+1'b1;end
 wire [10:0] gx=x-128;wire [5:0] column=gx[9:4],index_h=cursor+column;
 wire [11:0] hist=(column+{1'b0,valid_count}>=64)?history[index_h]:12'd0;
 wire [13:0] height64=({2'b0,hist}<<1)/5;
 wire [13:0] height=scale==0?height64:scale==1?height64>>1:height64>>2;
 wire graph=x>=128 && x<1152 && y>=384 && y<=640;
 wire grid=graph && (y==384 || y==448 || y==512 || y==576 || y==640);
 wire fill=graph && gx[3:0]<13 && height!=0 && (640-y)<height;
 wire roi=((x==128 || x==1151) && y>=104 && y<=615) || ((y==104 || y==615) && x>=128 && x<=1151);
 wire bar=x>=128 && x<1152 && y>=650 && y<674;
 wire target_mark=x>=128+{target,2'b0}-2 && x<=128+{target,2'b0}+2 && y>=644 && y<680;
 assign draw=latency_page?graph:(target_mark || bar || roi);
 assign pixel=latency_page?(fill?(status==1?24'h30c8e8:24'hcc8844):grid?24'h738090:24'h101820):
   target_mark?24'hffffff:bar?(x<128+{mean,2'b0}?24'h20c080:24'h203040):24'h609080;
endmodule
