module f_osd #(parameter MOTION_ONLY=0,INTEGRATED=0)(
 input [511:0] extra_line,input extra_draw,input [23:0] extra_rgb,
 input clk,rst_n,valid,vs,hs,input [10:0] x,y,input [23:0] rgb,
 input [2:0] motion_status,motion_capture_reason,input [14:0] motion_changes,motion_capture_diff,
 input [1:0] view_page,input source_live,input [2:0] mode,input source_ok,input [31:0] source_id,result_id,latency,
 input target_valid,input [2:0] reason,input [10:0] cx,cy,x0,x1,y0,y1,
 input [19:0] area,input [1:0] object_class,color,input [2:0] state,
 input [11:0] pan,tilt,input [14:0] motion,input [6:0] gain,input [7:0] mean,
 input [15:0] cfg,input [4:0] cal,input active_calibrated,
 input [15:0] source_fps,display_fps,capture_fps,input [19:0] diagnostics,
 input [23:0] sample_rgb,input [8:0] sample_pixels,input [7:0] sample_span,
 input [7:0] threshold_main,threshold_d1,threshold_d2,
 output reg ov,ovs,ohs,output reg [23:0] orgb
);
    function [34:0] glyph;
        input [7:0] c;
        begin case(c)
        8'd80: glyph=35'b11110100011000111110100001000010000;
        8'd84: glyph=35'b11111001000010000100001000010000100;
        8'd86: glyph=35'b10001100011000110001100010101000100;
        8'd79: glyph=35'b01110100011000110001100011000101110;
        8'd82: glyph=35'b11110100011000111110101001001010001;
        8'd73: glyph=35'b01110001000010000100001000010001110;
        8'd71: glyph=35'b01111100001000010111100011000101111;
        8'd78: glyph=35'b10001110011100110101100111001110001;
        8'd65: glyph=35'b01110100011000111111100011000110001;
        8'd76: glyph=35'b10000100001000010000100001000011111;
        8'd77: glyph=35'b10001110111010110101100011000110001;
        8'd50: glyph=35'b01110100010000100010001000100011111;
        8'd46: glyph=35'b00000000000000000000000000011000110;
        8'd47: glyph=35'b00001000100001000100010000100010000;
        8'd66: glyph=35'b11110100011000111110100011000111110;
        8'd67: glyph=35'b01111100001000010000100001000001111;
        8'd89: glyph=35'b10001100010101000100001000010000100;
        8'd43: glyph=35'b00000001000010011111001000010000000;
        8'd48: glyph=35'b01110100011001110101110011000101110;
        8'd49: glyph=35'b00100011000010000100001000010001110;
        8'd51: glyph=35'b11110000010000101110000010000111110;
        8'd52: glyph=35'b00010001100101010010111110001000010;
        8'd53: glyph=35'b11111100001000011110000010000111110;
        8'd54: glyph=35'b01110100001000011110100011000101110;
        8'd55: glyph=35'b11111000010001000100010000100001000;
        8'd56: glyph=35'b01110100011000101110100011000101110;
        8'd57: glyph=35'b01110100011000101111000010000101110;
        8'd68: glyph=35'b11110100011000110001100011000111110;
        8'd69: glyph=35'b11111100001000011110100001000011111;
        8'd70: glyph=35'b11111100001000011110100001000010000;
        8'd87: glyph=35'b10001100011000110101101011010101010;
        8'd88: glyph=35'b10001100010101000100010101000110001;
        8'd72: glyph=35'b10001100011000111111100011000110001;
        8'd83: glyph=35'b01111100001000001110000010000111110;
        8'd85: glyph=35'b10001100011000110001100011000101110;
        8'd81: glyph=35'b01110100011000110001101011001001101;
        8'd74: glyph=35'b00001000010000100001100011000101110;
        8'd75: glyph=35'b10001100101010011000101001001010001;
        8'd90: glyph=35'b11111000010001000100010001000011111;
            default:glyph=0;
        endcase end
    endfunction
 // Carry numeric nibbles through the text mux; decode just the selected character.
 function [7:0] hc;input [3:0] n;begin hc={4'h8,n};end endfunction
 function [15:0] h2;input [7:0] n;begin h2={hc(n[7:4]),hc(n[3:0])};end endfunction
 function [23:0] h3;input [11:0] n;begin h3={hc(n[11:8]),hc(n[7:4]),hc(n[3:0])};end endfunction
 function [31:0] h4;input [15:0] n;begin h4={hc(n[15:12]),h3(n[11:0])};end endfunction
 function [63:0] h8;input [31:0] n;begin h8={h4(n[31:16]),h4(n[15:0])};end endfunction
 reg [127:0] mode_name;
 reg [95:0] state_name;
 reg [63:0] class_name;
 reg [39:0] color_name;
 always @*begin
   case(mode)
    0:mode_name="ORIGINAL        ";1:mode_name="GRAYSCALE       ";2:mode_name="BINARY          ";3:mode_name="EDGE            ";
    4:mode_name="COLOR MASK      ";5:mode_name="POSTERIZE       ";6:mode_name="MOTION          ";7:mode_name=INTEGRATED?"SENSOR AE       ":"AUTO LIGHT      ";
   endcase
   case(state)
    0:state_name="OFF         ";1:state_name="REACQUIRE   ";2:state_name="TRACK       ";3:state_name="LOSS HOLD   ";
    4:state_name="TIMEOUT HOLD";5:state_name="OBSERVE HOLD";default:state_name="FAULT       ";
   endcase
   case(object_class)
    1:class_name="CARD    ";2:class_name="BALL    ";3:class_name="BLOB    ";default:class_name="NONE    ";
   endcase
   case(color)
    0:color_name="RED  ";1:color_name="GREEN";2:color_name="BLUE ";default:color_name="NONE ";
   endcase
 end
 reg [127:0] motion_name;
 always @*case(motion_status)
  0:motion_name="K3 SET EMPTY BG ";1:motion_name="LEARNING        ";2:motion_name="BACKGROUND CLEAR";
  3:motion_name="MOVING          ";4:motion_name="PRESENT STILL   ";5:motion_name="BG INVALID K3   ";
  6:motion_name="NO VIDEO        ";default:motion_name="SETTLING        ";endcase
 reg [63:0] capture_why;
 always @*case(motion_capture_reason)
  1:capture_why="REGION  ";2:capture_why="CHANGE  ";3:capture_why="CAMERA  ";
  4:capture_why="SCAN    ";5:capture_why="TIMEOUT ";default:capture_why="NONE    ";endcase
 reg [511:0] textline;
 always @*begin
   textline=0;
   case(y[7:5])
     0:textline=MOTION_ONLY?{"F2U MOTION TEST",392'b0}:{(INTEGRATED?"F3A VISION GIMBAL ":"F2U VISION GIMBAL "),mode_name,240'b0};
     1:textline={"OBJECT ",color_name," ",class_name," V ",hc({3'b0,target_valid})," LIVE ",hc({3'b0,source_live})," CAL ",hc({3'b0,cal[4]}),hc({3'b0,cal[3]}),hc({1'b0,cal[2:0]})," R ",hc({1'b0,reason}),160'b0};
     2:textline={"X ",h3({1'b0,cx})," Y ",h3({1'b0,cy})," AREA ",h8({12'b0,area})," HEX",280'b0};
     3:textline={"STATE ",state_name," PAN ",h3(pan)," TILT ",h3(tilt)," US HEX",176'b0};
     4:textline={"SRC ",h8(source_id)," RESULT ",h8(result_id)," OK ",hc({3'b0,source_ok})," DT ",h2(diagnostics[19:12])," STEP ",hc(diagnostics[11:8]),"/",hc(diagnostics[7:4])," B ",hc({2'b0,diagnostics[3:2]}),hc({2'b0,diagnostics[1:0]}),88'b0};
     5:textline={"LAT ",h8(latency)," RGB ",h2(sample_rgb[23:16])," ",h2(sample_rgb[15:8])," ",h2(sample_rgb[7:0])," N ",h3({3'b0,sample_pixels})," SP ",h2(sample_span)," K3 HEX",160'b0};
     6:textline={"MOTION ",h4({1'b0,motion})," GAIN Q4 ",h3({5'b0,gain})," MEAN ",h3({4'b0,mean})," TH ",h2(threshold_main)," ",h2(threshold_d1)," ",h2(threshold_d2),160'b0};
     7:textline={"CFG ",h4(cfg)," ",(active_calibrated?"CALIB ":"PRESET")," SRC FPS ",h4(source_fps)," DISP ",h4(display_fps)," CAP ",h4(capture_fps),136'b0};
   endcase
   if(mode==6)case(y[7:5])
    1:textline={"MOTION ",motion_name," FIX CAMERA K3 EMPTY BG",144'b0};
    2:textline={"FOREGROUND ",h4({1'b0,motion})," CHANGE ",h4({1'b0,motion_changes})," CELLS HEX",216'b0};
    3:textline={"CAMERA HOLD PAN ",h3(pan)," TILT ",h3(tilt)," US HEX",232'b0};
    6:textline={"BG DIFF ",h4({1'b0,motion_capture_diff})," RETRY ",capture_why," K3 EMPTY",224'b0};
   endcase
   if(MOTION_ONLY)case(y[7:5])
    3:textline={"FIXED CAMERA PWM OFF",352'b0};
    5:textline={"K3 EMPTY BG   K1 K2 DISABLED",288'b0};
    7:textline={"SRC FPS ",h4(source_fps)," DISP ",h4(display_fps)," CAP ",h4(capture_fps),264'b0};
   endcase
 end
 wire extra_page=INTEGRATED && (view_page==3 || mode==7);
 wire [511:0] selected_text=extra_page?extra_line:textline;
 wire [10:0] tx=x-16;
 wire [7:0] selected_char=selected_text[(63-tx[9:4])*8+:8];
 wire [7:0] decoded_char=(!extra_page && selected_char[7]) ?
   (selected_char[3:0]<10 ? 8'd48+{4'b0,selected_char[3:0]} : 8'd55+{4'b0,selected_char[3:0]}) : selected_char;
 wire clean_view=view_page==2;
 wire text_region=!clean_view && x>=16 && x<1040 && (view_page==1?y<64:y<256);
 // Integrated demo view hides the information panel, retaining tracking overlays and logo.
 wire logo_region=!MOTION_ONLY && (!clean_view || INTEGRATED) && x>=1104 && x<1264 && y>=16 && y<176;
 wire [10:0] lx=x-1104,ly=y-16;
 reg [14:0] logo_addr;
 wire [24:0] logo_pixel;
 // Synchronous index ROM uses the incoming address before the first pipeline edge.
 wire [14:0] logo_lookup_addr=logo_region?{ly[7:0],7'b0}+{2'b0,ly[7:0],5'b0}+{4'b0,lx}:0;
 anlogic_logo_rom #(.XY_ADDR(INTEGRATED)) logo(.I_x(lx[7:0]),.I_y(ly[7:0]),.I_clk(clk),.I_addr(logo_lookup_addr),.O_pixel(logo_pixel));
 wire box=mode!=6 && target_valid && (((x==x0 || x==x1) && y>=y0 && y<=y1) || ((y==y0 || y==y1) && x>=x0 && x<=x1));
 wire target_cross=mode!=6 && target_valid && ((x==cx && y+6>=cy && y<=cy+6) || (y==cy && x+6>=cx && x<=cx+6));
 wire center=(x==640 && y>=352 && y<=368)||(y==360 && x>=632 && x<=648);
 wire cal_box=((x==631 || x==648) && y>=351 && y<=368)||((y==351 || y==368) && x>=631 && x<=648);
 reg [7:0] ch;
 reg [3:0] fx;
 reg [4:0] fy;
 reg qtext,qlogo,qv,qvs,qhs;
 reg [23:0] qrgb;
 reg rvalid,rvs,rhs,rlogo;reg [23:0] rrgb;
 wire [34:0] bits=glyph(ch);
 wire ink=qtext && fx<10 && fy<14 && bits[34-(fy>>1)*5-(fx>>1)];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin ch<=0;fx<=0;fy<=0;qtext<=0;qlogo<=0;qv<=0;qvs<=0;qhs<=0;qrgb<=0;logo_addr<=0;
   rvalid<=0;rvs<=0;rhs<=0;rlogo<=0;rrgb<=0;
   ov<=0;ovs<=0;ohs<=0;orgb<=0;end
 else begin
   ch<=text_region?decoded_char:0;
   fx<=tx[3:0];fy<=y[4:0];qtext<=text_region;qlogo<=logo_region;
   qv<=valid;qvs<=vs;qhs<=hs;
   qrgb<=(clean_view && !INTEGRATED)?rgb:(!clean_view && extra_page && extra_draw)?extra_rgb:box || target_cross?24'h00ff00:(mode!=6 && (center || cal_box)?24'hff00ff:rgb);
   logo_addr<=logo_region?{ly[7:0],7'b0}+{2'b0,ly[7:0],5'b0}+{4'b0,lx}:0;
   // Palette ROM takes a second edge. Retiming all pixels and syncs together
   // preserves the exact image, with one additional pixel-clock latency.
   rvalid<=qv;rvs<=qvs;rhs<=qhs;rlogo<=qlogo && !qtext;
   rrgb<=ink?24'hffffff:qtext?24'h101010:qrgb;
   ov<=rvalid;ovs<=rvs;ohs<=rhs;
   orgb<=!rvalid?24'b0:(rlogo && logo_pixel[24])?logo_pixel[23:0]:rrgb;
 end
endmodule
