// Fixed two-stage raster pipeline; every mode has identical timing.
// EDGE uses perceptual luma differences >=24; BINARY uses perceptual luma >=128.
// MOTION uses a user-captured empty background plus independent frame change.
module f_image #(parameter WIDTH=1280,HEIGHT=720,MOTION_ONLY=0,SENSOR_AE=0)(
 input clk,rst_n,valid,sof,eof,vs,hs,input [10:0] x,y,
 input [23:0] rgb,input [31:0] source_id,input source_ok,
 input hide_motion,motion_capture,camera_stable,input [2:0] mode,input [1:0] color,input [7:0] min_main,diff1,diff2,
 output reg ov,osof,oeof,ovs,ohs,output reg [10:0] ox,oy,
 output reg [23:0] orgb,output reg [31:0] oid,
 output mask_valid,mask,seed_mask,
 output reg [6:0] gain,output reg [7:0] mean_luma,
 output [14:0] motion_count,motion_changes,motion_capture_diff,output [2:0] motion_capture_reason,output [2:0] motion_status,output motion_learned,
 output [10:0] mx0,mx1,my0,my1
);
 localparam GW=(WIDTH+7)/8, GH=(HEIGHT+7)/8;
 wire [9:0] sum={2'b0,rgb[23:16]}+{1'b0,rgb[15:8],1'b0}+{2'b0,rgb[7:0]};
 wire [7:0] gray_now=sum[9:2];
 reg [7:0] line[0:WIDTH-1];
 reg [7:0] above,left_gray;
 reg qv,qs,qe,qvs,qhs,q_sample,q_new,q_hist,q_hide_motion,q_source_ok;
 reg [10:0] qx,qy;
 reg [23:0] qrgb;
 reg [7:0] qgray;
 reg [31:0] qid,last_id;
 reg seen,new_frame,history_valid;
 wire new_now=source_ok && (!seen || source_id!=last_id);
 wire frame_new=sof ? new_now : new_frame;
 wire sample=valid && x[2:0]==3 && y[2:0]==3;
 wire [7:0] motion_gray;
 f_motion_luma #(.WIDTH(WIDTH)) motion_luma(.clk(clk),.rst_n(rst_n),.valid(valid),
 .x(x),.y(y),.gray(gamma22(gray_now)),.mean(motion_gray));
 wire [13:0] addr=(WIDTH==1280)?({y[9:3],7'b0}+{2'b0,y[9:3],5'b0}+{6'b0,x[10:3]}):((y>>3)*GW+(x>>3));
 reg [13:0] qaddr;
 wire color_valid,color_mask,weak_color,strong_color;
 reg [1:0] qcolor;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)qcolor<=0;else qcolor<=color;
 f_seed_color_mask #(.WIDTH(WIDTH)) seeded_local(.clk(clk),.rst_n(rst_n),.valid(valid),.x(x),.y(y),.rgb(rgb),.color(color),
 .min_main(min_main),.diff1(diff1),.diff2(diff2),.strong_mask(strong_color),.weak_mask(weak_color));
 color_classifier_runtime classify(.clk(clk),.rst_n(rst_n),.pixel_valid(valid),.rgb(rgb),
 .active_color(color),.min_main(min_main),.min_diff_1(diff1),.min_diff_2(diff2),
 .mask_valid(color_valid),.mask(color_mask));
 assign mask_valid=!MOTION_ONLY && color_valid;
 assign mask=!MOTION_ONLY && ((qcolor==1 || qcolor==2)?weak_color:color_mask);
 assign seed_mask=!MOTION_ONLY && ((qcolor==1 || qcolor==2)?strong_color:color_mask);
 always @(posedge clk)begin
   if(valid)above<=line[x];
   if(qv)line[qx]<=qgray;

 end
 wire [8:0] dx=qgray>left_gray?qgray-left_gray:left_gray-qgray;
 wire [8:0] dy=qgray>above?qgray-above:above-qgray;
 wire [9:0] gradient=dx+dy;
 wire edge_pixel=qx!=0 && qy!=0 && gradient>=24;

 reg [6:0] pending_gain,qgain;
 wire [14:0] gr=qrgb[23:16]*qgain,gg=qrgb[15:8]*qgain,gb=qrgb[7:0]*qgain;
 wire [7:0] ar=|gr[14:12]?255:gr[11:4];
 wire [7:0] ag=|gg[14:12]?255:gg[11:4];
 wire [7:0] ab=|gb[14:12]?255:gb[11:4];
 wire motion_box=motion_count!=0 && qx>=mx0 && qx<=mx1 && qy>=my0 && qy<=my1 &&
   (qx<mx0+3 || qx+3>mx1 || qy<my0+3 || qy+3>my1);
 wire [7:0] display_r=gamma22(qrgb[23:16]),display_g=gamma22(qrgb[15:8]),display_b=gamma22(qrgb[7:0]);
 reg [23:0] selected;
     function [7:0] gamma22;
        input [7:0] v;
        begin case(v)
            8'd0: gamma22=8'd0;
            8'd1: gamma22=8'd21;
            8'd2: gamma22=8'd28;
            8'd3: gamma22=8'd34;
            8'd4: gamma22=8'd39;
            8'd5: gamma22=8'd43;
            8'd6: gamma22=8'd46;
            8'd7: gamma22=8'd50;
            8'd8: gamma22=8'd53;
            8'd9: gamma22=8'd56;
            8'd10: gamma22=8'd59;
            8'd11: gamma22=8'd61;
            8'd12: gamma22=8'd64;
            8'd13: gamma22=8'd66;
            8'd14: gamma22=8'd68;
            8'd15: gamma22=8'd70;
            8'd16: gamma22=8'd72;
            8'd17: gamma22=8'd74;
            8'd18: gamma22=8'd76;
            8'd19: gamma22=8'd78;
            8'd20: gamma22=8'd80;
            8'd21: gamma22=8'd82;
            8'd22: gamma22=8'd84;
            8'd23: gamma22=8'd85;
            8'd24: gamma22=8'd87;
            8'd25: gamma22=8'd89;
            8'd26: gamma22=8'd90;
            8'd27: gamma22=8'd92;
            8'd28: gamma22=8'd93;
            8'd29: gamma22=8'd95;
            8'd30: gamma22=8'd96;
            8'd31: gamma22=8'd98;
            8'd32: gamma22=8'd99;
            8'd33: gamma22=8'd101;
            8'd34: gamma22=8'd102;
            8'd35: gamma22=8'd103;
            8'd36: gamma22=8'd105;
            8'd37: gamma22=8'd106;
            8'd38: gamma22=8'd107;
            8'd39: gamma22=8'd109;
            8'd40: gamma22=8'd110;
            8'd41: gamma22=8'd111;
            8'd42: gamma22=8'd112;
            8'd43: gamma22=8'd114;
            8'd44: gamma22=8'd115;
            8'd45: gamma22=8'd116;
            8'd46: gamma22=8'd117;
            8'd47: gamma22=8'd118;
            8'd48: gamma22=8'd119;
            8'd49: gamma22=8'd120;
            8'd50: gamma22=8'd122;
            8'd51: gamma22=8'd123;
            8'd52: gamma22=8'd124;
            8'd53: gamma22=8'd125;
            8'd54: gamma22=8'd126;
            8'd55: gamma22=8'd127;
            8'd56: gamma22=8'd128;
            8'd57: gamma22=8'd129;
            8'd58: gamma22=8'd130;
            8'd59: gamma22=8'd131;
            8'd60: gamma22=8'd132;
            8'd61: gamma22=8'd133;
            8'd62: gamma22=8'd134;
            8'd63: gamma22=8'd135;
            8'd64: gamma22=8'd136;
            8'd65: gamma22=8'd137;
            8'd66: gamma22=8'd138;
            8'd67: gamma22=8'd139;
            8'd68: gamma22=8'd140;
            8'd69: gamma22=8'd141;
            8'd70: gamma22=8'd142;
            8'd71: gamma22=8'd143;
            8'd72: gamma22=8'd144;
            8'd73: gamma22=8'd144;
            8'd74: gamma22=8'd145;
            8'd75: gamma22=8'd146;
            8'd76: gamma22=8'd147;
            8'd77: gamma22=8'd148;
            8'd78: gamma22=8'd149;
            8'd79: gamma22=8'd150;
            8'd80: gamma22=8'd151;
            8'd81: gamma22=8'd151;
            8'd82: gamma22=8'd152;
            8'd83: gamma22=8'd153;
            8'd84: gamma22=8'd154;
            8'd85: gamma22=8'd155;
            8'd86: gamma22=8'd156;
            8'd87: gamma22=8'd156;
            8'd88: gamma22=8'd157;
            8'd89: gamma22=8'd158;
            8'd90: gamma22=8'd159;
            8'd91: gamma22=8'd160;
            8'd92: gamma22=8'd160;
            8'd93: gamma22=8'd161;
            8'd94: gamma22=8'd162;
            8'd95: gamma22=8'd163;
            8'd96: gamma22=8'd164;
            8'd97: gamma22=8'd164;
            8'd98: gamma22=8'd165;
            8'd99: gamma22=8'd166;
            8'd100: gamma22=8'd167;
            8'd101: gamma22=8'd167;
            8'd102: gamma22=8'd168;
            8'd103: gamma22=8'd169;
            8'd104: gamma22=8'd170;
            8'd105: gamma22=8'd170;
            8'd106: gamma22=8'd171;
            8'd107: gamma22=8'd172;
            8'd108: gamma22=8'd173;
            8'd109: gamma22=8'd173;
            8'd110: gamma22=8'd174;
            8'd111: gamma22=8'd175;
            8'd112: gamma22=8'd175;
            8'd113: gamma22=8'd176;
            8'd114: gamma22=8'd177;
            8'd115: gamma22=8'd178;
            8'd116: gamma22=8'd178;
            8'd117: gamma22=8'd179;
            8'd118: gamma22=8'd180;
            8'd119: gamma22=8'd180;
            8'd120: gamma22=8'd181;
            8'd121: gamma22=8'd182;
            8'd122: gamma22=8'd182;
            8'd123: gamma22=8'd183;
            8'd124: gamma22=8'd184;
            8'd125: gamma22=8'd184;
            8'd126: gamma22=8'd185;
            8'd127: gamma22=8'd186;
            8'd128: gamma22=8'd186;
            8'd129: gamma22=8'd187;
            8'd130: gamma22=8'd188;
            8'd131: gamma22=8'd188;
            8'd132: gamma22=8'd189;
            8'd133: gamma22=8'd190;
            8'd134: gamma22=8'd190;
            8'd135: gamma22=8'd191;
            8'd136: gamma22=8'd192;
            8'd137: gamma22=8'd192;
            8'd138: gamma22=8'd193;
            8'd139: gamma22=8'd194;
            8'd140: gamma22=8'd194;
            8'd141: gamma22=8'd195;
            8'd142: gamma22=8'd195;
            8'd143: gamma22=8'd196;
            8'd144: gamma22=8'd197;
            8'd145: gamma22=8'd197;
            8'd146: gamma22=8'd198;
            8'd147: gamma22=8'd199;
            8'd148: gamma22=8'd199;
            8'd149: gamma22=8'd200;
            8'd150: gamma22=8'd200;
            8'd151: gamma22=8'd201;
            8'd152: gamma22=8'd202;
            8'd153: gamma22=8'd202;
            8'd154: gamma22=8'd203;
            8'd155: gamma22=8'd203;
            8'd156: gamma22=8'd204;
            8'd157: gamma22=8'd205;
            8'd158: gamma22=8'd205;
            8'd159: gamma22=8'd206;
            8'd160: gamma22=8'd206;
            8'd161: gamma22=8'd207;
            8'd162: gamma22=8'd207;
            8'd163: gamma22=8'd208;
            8'd164: gamma22=8'd209;
            8'd165: gamma22=8'd209;
            8'd166: gamma22=8'd210;
            8'd167: gamma22=8'd210;
            8'd168: gamma22=8'd211;
            8'd169: gamma22=8'd212;
            8'd170: gamma22=8'd212;
            8'd171: gamma22=8'd213;
            8'd172: gamma22=8'd213;
            8'd173: gamma22=8'd214;
            8'd174: gamma22=8'd214;
            8'd175: gamma22=8'd215;
            8'd176: gamma22=8'd215;
            8'd177: gamma22=8'd216;
            8'd178: gamma22=8'd217;
            8'd179: gamma22=8'd217;
            8'd180: gamma22=8'd218;
            8'd181: gamma22=8'd218;
            8'd182: gamma22=8'd219;
            8'd183: gamma22=8'd219;
            8'd184: gamma22=8'd220;
            8'd185: gamma22=8'd220;
            8'd186: gamma22=8'd221;
            8'd187: gamma22=8'd221;
            8'd188: gamma22=8'd222;
            8'd189: gamma22=8'd223;
            8'd190: gamma22=8'd223;
            8'd191: gamma22=8'd224;
            8'd192: gamma22=8'd224;
            8'd193: gamma22=8'd225;
            8'd194: gamma22=8'd225;
            8'd195: gamma22=8'd226;
            8'd196: gamma22=8'd226;
            8'd197: gamma22=8'd227;
            8'd198: gamma22=8'd227;
            8'd199: gamma22=8'd228;
            8'd200: gamma22=8'd228;
            8'd201: gamma22=8'd229;
            8'd202: gamma22=8'd229;
            8'd203: gamma22=8'd230;
            8'd204: gamma22=8'd230;
            8'd205: gamma22=8'd231;
            8'd206: gamma22=8'd231;
            8'd207: gamma22=8'd232;
            8'd208: gamma22=8'd232;
            8'd209: gamma22=8'd233;
            8'd210: gamma22=8'd233;
            8'd211: gamma22=8'd234;
            8'd212: gamma22=8'd234;
            8'd213: gamma22=8'd235;
            8'd214: gamma22=8'd235;
            8'd215: gamma22=8'd236;
            8'd216: gamma22=8'd236;
            8'd217: gamma22=8'd237;
            8'd218: gamma22=8'd237;
            8'd219: gamma22=8'd238;
            8'd220: gamma22=8'd238;
            8'd221: gamma22=8'd239;
            8'd222: gamma22=8'd239;
            8'd223: gamma22=8'd240;
            8'd224: gamma22=8'd240;
            8'd225: gamma22=8'd241;
            8'd226: gamma22=8'd241;
            8'd227: gamma22=8'd242;
            8'd228: gamma22=8'd242;
            8'd229: gamma22=8'd243;
            8'd230: gamma22=8'd243;
            8'd231: gamma22=8'd244;
            8'd232: gamma22=8'd244;
            8'd233: gamma22=8'd245;
            8'd234: gamma22=8'd245;
            8'd235: gamma22=8'd246;
            8'd236: gamma22=8'd246;
            8'd237: gamma22=8'd247;
            8'd238: gamma22=8'd247;
            8'd239: gamma22=8'd248;
            8'd240: gamma22=8'd248;
            8'd241: gamma22=8'd249;
            8'd242: gamma22=8'd249;
            8'd243: gamma22=8'd249;
            8'd244: gamma22=8'd250;
            8'd245: gamma22=8'd250;
            8'd246: gamma22=8'd251;
            8'd247: gamma22=8'd251;
            8'd248: gamma22=8'd252;
            8'd249: gamma22=8'd252;
            8'd250: gamma22=8'd253;
            8'd251: gamma22=8'd253;
            8'd252: gamma22=8'd254;
            8'd253: gamma22=8'd254;
            8'd254: gamma22=8'd255;
            8'd255: gamma22=8'd255;
            default:gamma22=0;
        endcase end
    endfunction

 always @*begin
   case(mode)
    0:selected={gamma22(qrgb[23:16]),gamma22(qrgb[15:8]),gamma22(qrgb[7:0])};
    1:selected={3{qgray}};
    2:selected={24{qgray>=128}};
    3:selected={24{edge_pixel}};
    4:selected=mask?(seed_mask?24'hffffff:24'h707070):24'h000000;
    5:selected={display_r[7:5],5'b0,display_g[7:5],5'b0,display_b[7:5],5'b0};
    6:selected=motion_box && !q_hide_motion?24'hffff00:{gamma22(qrgb[23:16]),gamma22(qrgb[15:8]),gamma22(qrgb[7:0])};
    7:selected=SENSOR_AE?{display_r,display_g,display_b}:{gamma22(ar),gamma22(ag),gamma22(ab)};
    default:selected=0;
   endcase
 end
 reg [23:0] luma_sum;
 reg [16:0] roi_count;
 reg evaluate_gain;
 wire in_roi=x>=(WIDTH-256)/2 && x<(WIDTH+256)/2 && y>=(HEIGHT-256)/2 && y<(HEIGHT+256)/2;
 wire [14:0] adjusted_mean=mean_luma*gain;
 f_motion_bg #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) motion_regions(
 .clk(clk),.rst_n(rst_n),.enable(mode==6),.source_ok(source_ok),.request(motion_capture),
 .camera_stable(camera_stable),.frame_start(qv && qs && q_new),.frame_end(qv && qe && q_new),
 .sample_valid(qv && q_sample && q_new),.gray(motion_gray),
 .x({3'b0,qx[10:3]}),.y({3'b0,qy[10:3]}),.source_id(qid),
 .capture_diff(motion_capture_diff),.capture_reason(motion_capture_reason),
 .count(motion_count),.changes(motion_changes),.status(motion_status),.learned(motion_learned),
 .x0(mx0),.x1(mx1),.y0(my0),.y1(my1));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   q_source_ok<=0;q_hide_motion<=0;qv<=0;qs<=0;qe<=0;qvs<=0;qhs<=0;qx<=0;qy<=0;qrgb<=0;qgray<=0;qid<=0;
   qaddr<=0;q_sample<=0;q_new<=0;q_hist<=0;left_gray<=0;
   ov<=0;osof<=0;oeof<=0;ovs<=0;ohs<=0;ox<=0;oy<=0;orgb<=0;oid<=0;
   seen<=0;new_frame<=0;last_id<=0;history_valid<=0;
   gain<=16;pending_gain<=16;qgain<=16;mean_luma<=0;luma_sum<=0;roi_count<=0;evaluate_gain<=0;
 end else begin
   evaluate_gain<=0;
   if(evaluate_gain && !SENSOR_AE)begin
     if(adjusted_mean<1536 && gain<64)pending_gain<=gain+1'b1;
     else if(adjusted_mean>2048 && gain>8)pending_gain<=gain-1'b1;
   end
   q_source_ok<=source_ok;q_hide_motion<=hide_motion;qv<=valid;qs<=sof;qe<=eof;qvs<=vs;qhs<=hs;qx<=x;qy<=y;qrgb<=rgb;qgray<=gamma22(gray_now);qid<=source_id;
   qaddr<=addr;q_sample<=sample;q_new<=frame_new;q_hist<=history_valid;qgain<=sof?pending_gain:gain;
   if(qv)left_gray<=qgray;
   ov<=qv;osof<=qs;oeof<=qe;ovs<=qvs;ohs<=qhs;ox<=qx;oy<=qy;oid<=qid;orgb<=qv?selected:0;
   if(sof && valid)begin
     gain<=pending_gain;
     new_frame<=new_now;
     if(source_ok)begin seen<=1;last_id<=source_id;end
     else begin seen<=0;history_valid<=0;end
     luma_sum<=in_roi?gray_now:0;roi_count<=in_roi?1:0;
   end else if(valid && in_roi)begin luma_sum<=luma_sum+gray_now;roi_count<=roi_count+1'b1;end
   if(eof && valid && frame_new && roi_count+(in_roi?17'd1:17'd0)==65536)begin
     mean_luma<=(luma_sum+(in_roi?gray_now:24'd0))>>16;
     evaluate_gain<=1;
   end
   if(qv && qe && q_new)history_valid<=1;
 end
endmodule
