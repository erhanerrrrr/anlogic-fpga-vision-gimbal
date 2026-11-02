// Bundled-data two-phase mailbox. Payload is held from request through ack.
// Both domains must share reset assertion; destination clocks may stop safely.
module f_cdc #(parameter W=32)(
 input sclk,dclk,rst_n,send,input [W-1:0] din,
 output ready,output reg pulse,output reg [W-1:0] dout
);
 reg [W-1:0] hold_data;
 reg req,ack;
 (* async_reg="true" *) reg rq1,rq2,ak1,ak2;
 assign ready=req==ak2;
 always @(posedge sclk or negedge rst_n)
 if(!rst_n) begin req<=0;ak1<=0;ak2<=0;hold_data<=0;end
 else begin
   ak1<=ack;ak2<=ak1;
   if(send && ready) begin hold_data<=din;req<=~req;end
 end
 always @(posedge dclk or negedge rst_n)
 if(!rst_n)begin rq1<=0;rq2<=0;ack<=0;pulse<=0;dout<=0;end
 else begin
   rq1<=req;rq2<=rq1;pulse<=0;
   if(rq2!=ack)begin dout<=hold_data;pulse<=1;ack<=rq2;end
 end
endmodule

// Gray timebase transfer. Timestamp units are source-clock cycles.
module f_gray_time(input sclk,dclk,rst_n,output reg [31:0] tick,
 output reg [31:0] remote_tick,output wire [31:0] gray_tick);
 reg [31:0] gray;
 assign gray_tick=gray;
 (* async_reg="true" *) reg [31:0] g1,g2;
 integer i;
 reg [31:0] decoded;
 always @* begin
   decoded[31]=g2[31];
   for(i=30;i>=0;i=i-1)decoded[i]=decoded[i+1]^g2[i];
 end
 always @(posedge sclk or negedge rst_n)
 if(!rst_n)begin tick<=0;gray<=0;end
 else begin tick<=tick+1'b1;gray<=((tick+32'd1)>>1)^(tick+32'd1);end
 always @(posedge dclk or negedge rst_n)
 if(!rst_n)begin g1<=0;g2<=0;remote_tick<=0;end
 else begin g1<=gray;g2<=g1;remote_tick<=decoded;end
endmodule
