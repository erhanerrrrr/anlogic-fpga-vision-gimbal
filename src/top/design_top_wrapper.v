

module design_top_wrapper (
    input wire        I_sys_clk,
    input wire        I_rst_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
      
    input wire [3:0] I_key_n,
    input wire [3:0] I_sw,
    output wire [3:0] O_led,
    output wire [7:0] O_dig,O_sel,
    output wire O_buzzer_n,O_source_mark,O_result_mark,
    output wire O_uart_tx,
    output wire O_pan_pwm, O_tilt_pwm,

    output wire       O_screen_pwm,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);


    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req; 
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;
		
	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
	

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    // 720p input-format diagnostics.  One RAW10 line from the factory
    // 1280-pixel mode contains 1600 bytes, i.e. 400 valid 32-bit CSI words.
    reg         S_dbg_hs_valid_d;
    reg [10:0]  S_dbg_csi_words;
    reg [10:0]  S_dbg_good_lines;
    reg         S_dbg_frame_seen_once;
    reg         S_dbg_frame_repeat_seen;
    reg         S_dbg_width_1280_seen;
    reg         S_dbg_height_720_seen;
    reg         S_dbg_isp_frame_seen_once;
    reg         S_dbg_isp_frame_repeat_seen;
    reg [1:0]   S_dbg_frame_repeat_sync;
    reg [1:0]   S_dbg_width_1280_sync;
    reg [1:0]   S_dbg_height_720_sync;
    reg [1:0]   S_dbg_isp_frame_repeat_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;


    assign O_screen_pwm = 1'b1;
    assign S_video_out_vsync = ~S_hdmi_vsync;
	
	
    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    // Count CSI payload words between HS packet boundaries.  This avoids
    // probing an internal net of csi_unpacket_2lane (which ChipWatcher cannot
    // legally connect to) and verifies the received line length externally.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_dbg_hs_valid_d          <= 1'b0;
            S_dbg_csi_words           <= 11'd0;
            S_dbg_good_lines          <= 11'd0;
            S_dbg_frame_seen_once     <= 1'b0;
            S_dbg_frame_repeat_seen   <= 1'b0;
            S_dbg_width_1280_seen     <= 1'b0;
            S_dbg_height_720_seen     <= 1'b0;
            S_dbg_isp_frame_seen_once <= 1'b0;
            S_dbg_isp_frame_repeat_seen <= 1'b0;
        end
        else begin
            S_dbg_hs_valid_d <= S_hs_rx_valid;

            if(!S_dbg_hs_valid_d && S_hs_rx_valid)
                S_dbg_csi_words <= 11'd0;
            else if(S_csi_valid)
                S_dbg_csi_words <= S_dbg_csi_words + 11'd1;

            // A packet with CSI payload is an image line.  Ignore short
            // frame-start/frame-end packets, whose payload count is zero.
            if(S_dbg_hs_valid_d && !S_hs_rx_valid && (S_dbg_csi_words != 0)) begin
                if(S_dbg_csi_words == 11'd400) begin
                    S_dbg_width_1280_seen <= 1'b1;
                    S_dbg_good_lines <= S_dbg_good_lines + 11'd1;
                end
            end

            if(S_csi_frame_start) begin
                if(S_dbg_frame_seen_once) begin
                    S_dbg_frame_repeat_seen <= 1'b1;
                    if(S_dbg_good_lines == 11'd720)
                        S_dbg_height_720_seen <= 1'b1;
                end
                else
                    S_dbg_frame_seen_once <= 1'b1;
                S_dbg_good_lines <= 11'd0;
            end

            if(S_ISP_O_tuser) begin
                if(S_dbg_isp_frame_seen_once)
                    S_dbg_isp_frame_repeat_seen <= 1'b1;
                else
                    S_dbg_isp_frame_seen_once <= 1'b1;
            end
        end
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
            S_dbg_frame_repeat_sync <= 2'b00;
            S_dbg_width_1280_sync <= 2'b00;
            S_dbg_height_720_sync <= 2'b00;
            S_dbg_isp_frame_repeat_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            S_dbg_frame_repeat_sync <= {S_dbg_frame_repeat_sync[0], S_dbg_frame_repeat_seen};
            S_dbg_width_1280_sync <= {S_dbg_width_1280_sync[0], S_dbg_width_1280_seen};
            S_dbg_height_720_sync <= {S_dbg_height_720_sync[0], S_dbg_height_720_seen};
            S_dbg_isp_frame_repeat_sync <= {S_dbg_isp_frame_repeat_sync[0], S_dbg_isp_frame_repeat_seen};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    // On-screen bring-up status, from left to right in DEBUG_MODE=3:
    // I2C configuration completed, MIPI HS activity seen, repeated CSI frames,
    // and a 1280-pixel RAW10 line (400 x 32-bit CSI payload words) seen.
    assign S_hdmi_debug_status = {
        S_dbg_width_1280_sync[1],
        S_dbg_frame_repeat_sync[1],
        S_dbg_hs_seen_sync[1],
        S_dbg_cam_cfg_seen_sync[1]
    };
	
	assign O_cam_rst 	= 1'b1;
    assign O_cam_24m 	= S_24m_clk;
	
	
	
	
    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );


	

  
  wire ae_bus_error;
  wire ae_sample_pulse;wire [31:0] ae_sample_data;
  wire ae_key_pulse;wire [2:0] ae_keys;wire ae_locked;
  wire ae_frame_pulse,ae_frame_ready;
  f_cdc #(.W(1)) ae_frame_cdc(.sclk(S_csi_rx_clk),.dclk(S_24m_clk),.rst_n(S_rst_n),
    .send(S_csi_frame_start),.din(1'b0),.ready(ae_frame_ready),.pulse(ae_frame_pulse),.dout());
  wire [1:0] ae_mode;wire [3:0] ae_status;wire [7:0] ae_target,ae_mean;
  wire [11:0] ae_clipped;wire [15:0] ae_updates;wire ae_fault,ae_live;
  f_sensor_ae #(.INTEGRATED(1)) auto_exposure(.clk(S_24m_clk),.rst_n(S_rst_n),.frame_start(ae_frame_pulse),
    .cfg_done(S_cam_cfg_done),.ae_done(S_ae_cfg_done),.bus_error(ae_bus_error),
    .sample(ae_sample_pulse),.mean(ae_sample_data[31:24]),.clipped(ae_sample_data[23:12]),.near_clip(ae_sample_data[11:0]),
    .inhibit(ae_keys[2]),.locked(ae_locked),.key_mode(1'b0),.key_target(ae_key_pulse && ae_keys[0]),.key_hold(ae_key_pulse && ae_keys[1]),
    .request(S_ae_req),.exposure(S_ae),.gain_index(S_ag),.mode(ae_mode),.target(ae_target),
    .status(ae_status),.measured(ae_mean),.highlights(ae_clipped),.updates(ae_updates),.fault(ae_fault),.live(ae_live));
    uicfgcs500_720p #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_rst_n),  //系统复位输入
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_bus_error(ae_bus_error),.O_ae_cfg_done(S_ae_cfg_done)  //AE配置完成
  );
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),//"0dB","1.5dB","3dB","4.5dB","6dB","7.5dB","9dB","10.5dB"
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


//将数据转为stream流
uial2axis #(
.IMG_WIDTH(1280),
.IMG_HEIGHT(720),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);
	

// SC500 factory HD mode already outputs native 1280x720 RAW10.
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


//ISP算法顶层模块
isp_top u_isp_top (
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_tready        ()
  );


    wire [1:0] meta_write_slot,read_slot,latest_slot;
    wire meta_start,read_start,write_error;
    wire [31:0] ddr_tick,pixel_tick,timer_gray,csi_tick;
    wire meta_publish,meta_ready,meta_received;
    wire [80:0] meta_packet,display_meta;
    f_gray_time timebase(.sclk(S_ddr_clk),.dclk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
      .tick(ddr_tick),.remote_tick(pixel_tick),.gray_tick(timer_gray));
    f_gray_receive capture_time(.clk(S_csi_rx_clk),.rst_n(S_rst_n),.gray(timer_gray),.tick(csi_tick));
    wire capture_tag_send,tag_ready,tag_pulse;wire [64:0] capture_tag,ddr_tag;
    f_capture_tag capture_tagging(.clk(S_csi_rx_clk),.rst_n(S_rst_n),.csi_sof(S_csi_frame_start),
      .isp_sof(S_ISP_O_tuser),.tick(csi_tick),.send(capture_tag_send),.packet(capture_tag));
    f_cdc #(.W(65)) tag_cdc(.sclk(S_csi_rx_clk),.dclk(S_ddr_clk),.rst_n(S_rst_n),
      .send(capture_tag_send),.din(capture_tag),.ready(tag_ready),.pulse(tag_pulse),.dout(ddr_tag));
    f_capture_meta metadata(.clk(S_ddr_clk),.rst_n(S_rst_n),.write_start(meta_start),
      .write_slot(meta_write_slot),.write_beat(S_vi_ddr_wr_en),.write_error(write_error),
      .tag_pulse(tag_pulse),.tag(ddr_tag),.read_start(read_start),.read_slot(latest_slot),
      .latest_slot(latest_slot),.publish(meta_publish),.packet(meta_packet),.capture_count(),.rejected());
    f_cdc #(.W(81)) meta_cdc(.sclk(S_ddr_clk),.dclk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
      .send(meta_publish),.din(meta_packet),.ready(meta_ready),.pulse(meta_received),.dout(display_meta));
    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_read_slot(read_slot),.O_frame_start(meta_start),.O_write_slot(meta_write_slot),.O_write_error(write_error),
        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( latest_slot          ),
        .O_selected_slot(read_slot),.O_frame_start(read_start),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    uivtc #(
        .H_ActiveSize ( 1280 ),
        .H_FrameSize  ( 1650 ),
        .H_SyncStart  ( 1390 ),
        .H_SyncEnd    ( 1430 ),
        .V_ActiveSize ( 720  ),
        .V_FrameSize  ( 750  ),
        .V_SyncStart  ( 725  ),
        .V_SyncEnd    ( 730  )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n    ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    // Full-system configuration; 1 selects the motion-only diagnostic path.
    localparam F2S_MOTION_ONLY=0;
    wire [3:0] key_pressed,sw_value;
    wire [1:0] page;
    wire pan_reverse,tilt_reverse,toggle_enable;
    wire [11:0] pan_us,tilt_us;
    wire [19:0] control_diagnostics;
    wire [2:0] control_state;
    wire enabled;
    f2_inputs #(.EXTENDED_PAGES(1),.DEFAULT_PAGE(2)) inputs(.clk(S_100m_clk),.rst_n(S_rst_n),.key_n(I_key_n),.sw(I_sw),.enabled(enabled),
      .pressed(key_pressed),.sw_value(sw_value),.toggle_enable(toggle_enable),
      .page(page),.pan_reverse(pan_reverse),.tilt_reverse(tilt_reverse));
    wire key_pulse,key_ready;
    wire [2:0] key_events;
    // Keep events pending until the mailbox accepts them.
    reg [2:0] key_pending;
    always @(posedge S_100m_clk or negedge S_rst_n)
      if(!S_rst_n)key_pending<=0;
      else key_pending<=(key_ready?3'b0:key_pending)|key_pressed[2:0];
    f_cdc #(.W(3)) key_cdc(.sclk(S_100m_clk),.dclk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
      .send(|key_pending),.din(key_pending),.ready(key_ready),.pulse(key_pulse),.dout(key_events));
    wire result_send,result_pulse,result_ready;
    wire [71:0] result_packet,control_packet;
    wire [63:0] result_info,control_info;
    wire motion_hold;
    (* async_reg="true" *) reg mh1,mh2;
    always @(posedge S_100m_clk or negedge S_rst_n)
      if(!S_rst_n)begin mh1<=0;mh2<=0;end else begin mh1<=motion_hold;mh2<=mh1;end
    f_cdc #(.W(136)) result_cdc(.sclk(S_hdmi_pixel_clk),.dclk(S_100m_clk),.rst_n(S_rst_n),
      .send(result_send),.din({result_info,result_packet}),.ready(result_ready),.pulse(result_pulse),.dout({control_info,control_packet}));
    wire [10:0] directed_x=pan_reverse?11'd1280-control_packet[21:11]:control_packet[21:11];
    wire [10:0] directed_y=tilt_reverse?11'd720-control_packet[10:0]:control_packet[10:0];
    generate if(F2S_MOTION_ONLY)begin : g_motion_control
      assign O_pan_pwm=1'b0;assign O_tilt_pwm=1'b0;
      assign pan_us=12'd1500;assign tilt_us=12'd1500;
      assign control_state=3'd0;assign enabled=1'b0;assign control_diagnostics=20'd0;
    end else begin : g_full_control
    f_control #(.HOLD_ENABLE(1),.CLK_HZ(100000000),.PAN_MIN_US(1000),.PAN_MAX_US(2000),
      .TILT_MIN_US(1200),.TILT_MAX_US(1800)) controller(.clk(S_100m_clk),.rst_n(S_rst_n),
      .hold_request(mh2),.toggle_enable(toggle_enable),.recenter(1'b0),
      .result_strobe(result_pulse),.source_ok(control_packet[71]),.target_valid(control_packet[70] && !mh2),
      .source_id(control_packet[69:38]),.cfg_id(control_packet[37:22]),.cx(directed_x),.cy(directed_y),
      .pan_pwm(O_pan_pwm),.tilt_pwm(O_tilt_pwm),.pan_us(pan_us),.tilt_us(tilt_us),.state(control_state),.enabled(enabled),.diagnostics(control_diagnostics));
    end endgenerate
    wire source_live,target_live,result_new;
    wire local_ready,local_pulse;
    wire [7:0] pixel_local,control_local;
    f_cdc #(.W(8)) local_cdc(.sclk(S_hdmi_pixel_clk),.dclk(S_100m_clk),.rst_n(S_rst_n),
      .send(local_ready),.din(pixel_local),.ready(local_ready),.pulse(local_pulse),.dout(control_local));
    reg cal_sequence;
    always @(posedge S_100m_clk or negedge S_rst_n)
      if(!S_rst_n)cal_sequence<=0;else if(local_pulse)cal_sequence<=control_local[4];
    f2_panel #(.DEMO_MODE(1)) panel(.motion_mode(control_local[7:5]==6),.motion_status(control_info[55:53]),.motion_area(control_info[52:38]),.clk(S_100m_clk),.rst_n(S_rst_n),.dual_mode(sw_value[1]),.page(page!=0),.enabled(enabled),.state(control_state),
      .result_strobe(result_pulse),.source_ok(control_packet[71]),.target_valid(control_packet[70]),
      .source_id(control_packet[69:38]),.cx(control_packet[21:11]),.cy(control_packet[10:0]),.pan_us(pan_us),.tilt_us(tilt_us),
      .cal_event(local_pulse && control_local[4]!=cal_sequence),.cal_ok(control_local[3]),
      .led(O_led),.dig(O_dig),.sel(O_sel),.buzzer_n(O_buzzer_n),.source_live(source_live),.target_live(target_live),.result_new(result_new));
    f2_markers markers(.source_clk(S_csi_rx_clk),.clk(S_100m_clk),.rst_n(S_rst_n),
      .source_sof(S_ISP_O_tvalid && S_ISP_O_tuser),.result_new(result_new),.source_mark(O_source_mark),.result_mark(O_result_mark));
    wire status_ready,status_pulse;
    wire [49:0] pixel_status;
    f_cdc #(.W(50)) status_cdc(.sclk(S_100m_clk),.dclk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
      .send(status_ready),.din({control_diagnostics,page,source_live,control_state,pan_us,tilt_us}),.ready(status_ready),.pulse(status_pulse),.dout(pixel_status));
    assign S_hdmi_window_rd_en=S_hdmi_de;
    // video_out returns a requested RGB pixel two sampling edges later.
    // Delay the matching control packet, while DDR requests use native DE.
    reg [3:0] display_ctl1,display_ctl2;
    always @(posedge S_hdmi_pixel_clk or negedge S_rst_n)
      if(!S_rst_n)begin display_ctl1<=0;display_ctl2<=0;end
      else begin display_ctl1<={S_hdmi_vsync,S_hdmi_hsync,S_hdmi_de,S_hdmi_user};display_ctl2<=display_ctl1;end
    f_uart_telemetry telemetry(.clk(S_100m_clk),.rst_n(S_rst_n),.event_strobe(result_pulse),
      .result(control_packet),.info(control_info),.source_live(source_live),.target_live(target_live),.enabled(enabled),
      .state(control_state),.pan(pan_us),.tilt(tilt_us),.tx(O_uart_tx));
    // All pixel-domain AE feedback and control use bundled mailboxes.
    wire meter_sample,meter_ready,ae_inhibit,ae_profile_event,ae_hold_event;
    wire [31:0] meter_data;wire ae_control_ready;reg [1:0] ae_events_pending;
    always @(posedge S_hdmi_pixel_clk or negedge S_rst_n)
      if(!S_rst_n)ae_events_pending<=0;
      else ae_events_pending<=(ae_control_ready?2'b0:ae_events_pending)|{ae_hold_event,ae_profile_event};
    f_cdc #(.W(3)) ae_control_cdc(.sclk(S_hdmi_pixel_clk),.dclk(S_24m_clk),.rst_n(S_rst_n),
      .send(ae_control_ready),.din({ae_inhibit,ae_events_pending}),.ready(ae_control_ready),.pulse(ae_key_pulse),.dout(ae_keys));
    f_cdc #(.W(32)) meter_cdc(.sclk(S_hdmi_pixel_clk),.dclk(S_24m_clk),.rst_n(S_rst_n),
      .send(meter_sample),.din(meter_data),.ready(meter_ready),.pulse(ae_sample_pulse),.dout(ae_sample_data));
    wire ae_status_ready,ae_status_pulse;wire [82:0] ae_pixel_status;
    f_cdc #(.W(83)) ae_status_cdc(.sclk(S_24m_clk),.dclk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
      .send(ae_status_ready),.din({ae_locked,ae_mode,ae_status,ae_target,ae_mean,ae_clipped,S_ae,S_ag,ae_updates}),
      .ready(ae_status_ready),.pulse(ae_status_pulse),.dout(ae_pixel_status));
    f_vision #(.MOTION_ONLY(F2S_MOTION_ONLY),.INTEGRATED(1)) vision(.motion_hold(motion_hold),.result_info(result_info),.clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),.vs(display_ctl2[3]),.hs(display_ctl2[2]),
      .de(display_ctl2[1]),.user(display_ctl2[0]),.rgb(S_video_rd_data),.source_meta(display_meta),.tick(pixel_tick),
      .ae_status(ae_pixel_status),.ae_inhibit(ae_inhibit),.ae_profile_event(ae_profile_event),.ae_hold_event(ae_hold_event),
      .ae_sample(meter_sample),.ae_sample_data(meter_data),
      .mode_event(key_pulse && key_events[0]),.color_event(key_pulse && key_events[1]),.cal_event(key_pulse && key_events[2]),
      .view_page(pixel_status[29:28]),.source_live(pixel_status[27]),.local_status(pixel_local),
      .diagnostics(pixel_status[49:30]),.tracking_state(pixel_status[26:24]),.pan_us(pixel_status[23:12]),.tilt_us(pixel_status[11:0]),
      .ovs(S_hdmi_out_vsync),.ohs(S_hdmi_out_hsync),.ode(S_hdmi_out_de),.orgb(S_hdmi_out_data),
      .result_send(result_send),.result_packet(result_packet));

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_hdmi_out_vsync  ),
        .I_video_in_de      ( S_hdmi_out_de     ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_hdmi_out_data   ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );


    
endmodule
