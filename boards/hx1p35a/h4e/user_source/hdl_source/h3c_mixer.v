module h3c_mixer #(
    parameter H_OFFSET = 128,
    parameter V_OFFSET = 60,
    parameter IMG_WIDTH = 1920,
    parameter IMG_HEIGHT = 1080,
    parameter integer DEBUG_MODE = 0,
    parameter [511:0] HEADER_TEXT = {"WB FIX R1.56 B2.03 BLC16 G2.2",280'd0}
)(
    input wire        I_clk,
    input wire        I_rst_n,

    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_de,
    input wire        I_video_user,
    input wire        I_video_last,

    input wire[3:0]   I_debug_status,
    input wire [10:0] I_pixel_x, I_pixel_y,
    input wire I_target_valid,
    input wire [10:0] I_target_cx, I_target_cy,
    input wire [19:0] I_target_area,
    input wire [10:0] I_target_xmin, I_target_xmax, I_target_ymin, I_target_ymax,

    output wire       O_video_rd_en,
    input wire[23:0]  I_video_rd_data,

    output reg        O_hdmi_vsync,
    output reg        O_hdmi_hsync,
    output reg        O_hdmi_de,
    output reg[23:0]  O_hdmi_data
);

    reg        S_video_vsync_1d;
    reg        S_video_vsync_2d;
    reg        S_video_hsync_1d;
    reg        S_video_hsync_2d;
    reg        S_video_de_1d;
    reg        S_video_de_2d;
    reg [23:0] S_video_data_1d;
    reg [23:0] S_video_data_2d;
    wire [11:0] S_x = {1'b0,I_pixel_x};
    wire [11:0] S_y = {1'b0,I_pixel_y};


    // BLC16 and fixed R1.56/G1/B2.03 white balance are upstream. Full-screen Gamma2.2.
    // Calibration statistics use linear DDR output BEFORE Gamma and overlays.
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
    function [34:0] glyph;
        input [7:0] c;
        begin case(c)
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
            default:glyph=0;
        endcase end
    endfunction
    reg [23:0] gamma_d1,gamma_d2;
    reg [11:0] x_d1,x_d2,y_d1,y_d2;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            gamma_d1<=0;gamma_d2<=0;x_d1<=0;x_d2<=0;y_d1<=0;y_d2<=0;
        end else begin
            gamma_d1<={gamma22(I_video_rd_data[23:16]),gamma22(I_video_rd_data[15:8]),gamma22(I_video_rd_data[7:0])};
            gamma_d2<=gamma_d1;
            x_d1<=S_x;x_d2<=x_d1;y_d1<=S_y;y_d2<=y_d1;
        end
    end
    // 256x256 center ROI: exact 65536 pixels; displayed sum / 65536 = mean.
    // Entire block remains in HDMI pixel clock domain, no added CDC.
    reg [23:0] sum_r,sum_g,sum_b,held_r,held_g,held_b;
    reg [16:0] roi_count,held_count;
    reg [7:0] max_r,max_g,max_b,held_max_r,held_max_g,held_max_b;
    reg seen_frame;
    wire in_roi = S_x>=512 && S_x<768 && S_y>=232 && S_y<488;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            sum_r<=0;sum_g<=0;sum_b<=0;roi_count<=0;
            held_r<=0;held_g<=0;held_b<=0;held_count<=0;
            max_r<=0;max_g<=0;max_b<=0;
            held_max_r<=0;held_max_g<=0;held_max_b<=0;seen_frame<=0;
        end else if(I_video_user)begin
            if(seen_frame)begin
                held_r<=sum_r;held_g<=sum_g;held_b<=sum_b;held_count<=roi_count;
                held_max_r<=max_r;held_max_g<=max_g;held_max_b<=max_b;
            end
            sum_r<=0;sum_g<=0;sum_b<=0;roi_count<=0;
            max_r<=0;max_g<=0;max_b<=0;seen_frame<=1;
        end else if(seen_frame && I_video_de && in_roi)begin
            sum_r<=sum_r+I_video_rd_data[23:16];
            sum_g<=sum_g+I_video_rd_data[15:8];
            sum_b<=sum_b+I_video_rd_data[7:0];
            roi_count<=roi_count+1'b1;
            if(I_video_rd_data[23:16]>max_r)max_r<=I_video_rd_data[23:16];
            if(I_video_rd_data[15:8]>max_g)max_g<=I_video_rd_data[15:8];
            if(I_video_rd_data[7:0]>max_b)max_b<=I_video_rd_data[7:0];
        end
    end
    function [7:0] hexchar;
        input [3:0] v;
        begin hexchar=(v<10)?(8'd48+v):(8'd65+v-10);end
    endfunction
    function [47:0] hex6;
        input [23:0] v;
        begin hex6={hexchar(v[23:20]),hexchar(v[19:16]),hexchar(v[15:12]),
                    hexchar(v[11:8]),hexchar(v[7:4]),hexchar(v[3:0])};end
    endfunction
    reg [511:0] label_text;
    reg [11:0] label_x;
    reg [4:0] label_y;
    reg [34:0] label_glyph;
    reg [7:0] label_char;
    // Frame-stable geometry is overlaid AFTER measurement; it cannot feed back
    // into the classifier/ROI. Widened unsigned distances avoid edge wraparound.
    wire geometry_valid = I_target_valid && I_target_xmin<=I_target_xmax &&
        I_target_ymin<=I_target_ymax && I_target_xmax<IMG_WIDTH && I_target_ymax<IMG_HEIGHT &&
        I_target_cx<IMG_WIDTH && I_target_cy<IMG_HEIGHT;
    wire inside_box = geometry_valid && x_d2>=I_target_xmin && x_d2<=I_target_xmax &&
        y_d2>=I_target_ymin && y_d2<=I_target_ymax;
    wire [11:0] box_left=x_d2-{1'b0,I_target_xmin}, box_right={1'b0,I_target_xmax}-x_d2;
    wire [11:0] box_top=y_d2-{1'b0,I_target_ymin}, box_bottom={1'b0,I_target_ymax}-y_d2;
    wire box_on = inside_box && (box_left<12'd2 || box_right<12'd2 || box_top<12'd2 || box_bottom<12'd2);
    wire [11:0] cross_dx = x_d2>={1'b0,I_target_cx} ? x_d2-{1'b0,I_target_cx} : {1'b0,I_target_cx}-x_d2;
    wire [11:0] cross_dy = y_d2>={1'b0,I_target_cy} ? y_d2-{1'b0,I_target_cy} : {1'b0,I_target_cy}-y_d2;
    wire cross_on = geometry_valid && x_d2<IMG_WIDTH && y_d2<IMG_HEIGHT &&
        ((cross_dx<=12'd8 && cross_dy<=12'd1) || (cross_dx<=12'd1 && cross_dy<=12'd8));
    reg [23:0] compare_rgb;
    always @(*)begin
        compare_rgb=gamma_d2;
        // Border is OUTSIDE the sampled rectangle and never included in sums.
        if(((x_d2==511 || x_d2==768) && y_d2>=231 && y_d2<=488) ||
           ((y_d2==231 || y_d2==488) && x_d2>=511 && x_d2<=768))
            compare_rgb=24'hffff00;
        if(box_on) compare_rgb=24'h00ff00;
        if(cross_on) compare_rgb=24'h00ffff;
        label_text=0;label_x=x_d2-16;label_y=y_d2[4:0];
        label_char=0;label_glyph=0;
        if(y_d2<128)begin
            compare_rgb=24'h101010;
            if(y_d2<32)
                label_text=HEADER_TEXT;
            else if(y_d2<64)
                label_text={"V ",hexchar({3'd0,I_target_valid})," X ",hex6({13'd0,I_target_cx}),
                            " Y ",hex6({13'd0,I_target_cy})," A ",hex6({4'd0,I_target_area})," HEX",240'd0};
            else if(y_d2<96)
                label_text={"R ",hex6(held_r)," G ",hex6(held_g)," B ",hex6(held_b)," N ",hex6({7'd0,held_count}),232'd0};
            else
                label_text={"MAX R ",hexchar(held_max_r[7:4]),hexchar(held_max_r[3:0]),
                            " G ",hexchar(held_max_g[7:4]),hexchar(held_max_g[3:0]),
                            " B ",hexchar(held_max_b[7:4]),hexchar(held_max_b[3:0]),
                            "  HEX",328'd0};
            if(label_x<1024 && label_y<14)begin
                label_char=label_text[(63-label_x[9:4])*8+:8];
                label_glyph=glyph(label_char);
                if(label_x[3:1]<5 && label_glyph[34-label_y[3:1]*5-label_x[3:1]])
                    compare_rgb=24'hffffff;
            end
        end
    end

    assign O_video_rd_en = I_video_de;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_hsync_1d <= 1'b0;
            S_video_hsync_2d <= 1'b0;
            S_video_de_1d    <= 1'b0;
            S_video_de_2d    <= 1'b0;
            O_hdmi_vsync     <= 1'b0;
            O_hdmi_hsync     <= 1'b0;
            O_hdmi_de        <= 1'b0;
            O_hdmi_data      <= 24'd0;
        end
        else begin
            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            O_hdmi_vsync     <= S_video_vsync_2d;

            S_video_hsync_1d <= I_video_hsync;
            S_video_hsync_2d <= S_video_hsync_1d;
            O_hdmi_hsync     <= S_video_hsync_2d;

            S_video_de_1d    <= I_video_de;
            S_video_de_2d    <= S_video_de_1d;
            O_hdmi_de        <= S_video_de_2d;
            S_video_data_1d  <= I_video_rd_data;
            S_video_data_2d  <= S_video_data_1d;

            if(DEBUG_MODE == 1) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd128)
                        O_hdmi_data <= 24'hff0000;
                    else if(S_x < 12'd256)
                        O_hdmi_data <= 24'h00ff00;
                    else if(S_x < 12'd384)
                        O_hdmi_data <= 24'h0000ff;
                    else if(S_x < 12'd512)
                        O_hdmi_data <= 24'hffff00;
                    else if(S_x < 12'd640)
                        O_hdmi_data <= 24'h00ffff;
                    else if(S_x < 12'd768)
                        O_hdmi_data <= 24'hff00ff;
                    else if(S_x < 12'd896)
                        O_hdmi_data <= 24'hffffff;
                    else
                        O_hdmi_data <= 24'h202020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 2) begin
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'b0000: O_hdmi_data <= 24'h000000;
                        4'b0001: O_hdmi_data <= 24'hff0000;
                        4'b0011: O_hdmi_data <= 24'hffff00;
                        4'b0111: O_hdmi_data <= 24'h00ff00;
                        4'b1111: O_hdmi_data <= I_video_rd_data;
                        default: O_hdmi_data <= 24'h0000ff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 3) begin
                if(S_video_de_2d) begin
                    if(S_x < (IMG_WIDTH/4))
                        O_hdmi_data <= I_debug_status[0] ? 24'hff8000 : 24'h404040;
                    else if(S_x < (IMG_WIDTH/2))
                        O_hdmi_data <= I_debug_status[1] ? 24'hffff00 : 24'h404040;
                    else if(S_x < ((IMG_WIDTH*3)/4))
                        O_hdmi_data <= I_debug_status[2] ? 24'hff0000 : 24'h404040;
                    else
                        O_hdmi_data <= I_debug_status[3] ? 24'h00ffff : 24'h404040;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else begin
                O_hdmi_data <= S_video_de_2d ? compare_rgb : 24'd0;
            end
        end
    end

endmodule
