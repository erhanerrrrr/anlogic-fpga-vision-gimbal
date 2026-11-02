`timescale 1ns/1ps
module tb_f2_panel;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,dual=0,page=0,enabled=0,strobe=0,ok=1,valid=1,cal=0,cal_ok=0;
 reg [2:0] state=0;reg [31:0] id=0;reg [10:0] x=640,y=360;
 wire [3:0] led;wire [7:0] dig,sel;wire buzz,live,tv,new_result;
 f2_panel #(.CLK_HZ(1000000),.FRESH_MS(20)) dut(
 .clk(clk),.rst_n(rst),.dual_mode(dual),.page(page),.enabled(enabled),.state(state),
 .result_strobe(strobe),.source_ok(ok),.target_valid(valid),.source_id(id),.cx(x),.cy(y),.pan_us(12'd1500),.tilt_us(12'd1500),
 .cal_event(cal),.cal_ok(cal_ok),.led(led),.dig(dig),.sel(sel),.buzzer_n(buzz),.source_live(live),.target_live(tv),.result_new(new_result));
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task result(input integer n);begin id=n;strobe=1;cycles(1);strobe=0;cycles(3);end endtask
 integer scan_seen=0;reg [7:0] olddig=255,oldsel=255;integer idx;
 // Check real pins: one active digit, digit data only changes with all selects off.
 always @(negedge clk)if(rst && !dual)begin
   if(sel!=255 && ((~sel & 8'hff)&((~sel & 8'hff)-1))!=0)$fatal(1,"multiple selected digits");
   if(dig!=olddig && sel!=255)$fatal(1,"segments changed with digit selected");
   if(!page && sel!=255)begin
     for(idx=0;idx<8;idx=idx+1)if(!sel[idx])begin
       if(dig!==(idx%4==0?8'hf9:idx%4==1?8'h92:8'hc0))$fatal(1,"decimal 1500 mapping idx=%d dig=%h",idx,dig);
       scan_seen=scan_seen | (1<<idx);
     end
   end
   olddig=dig;oldsel=sel;
 end
 initial begin
   cycles(5);rst=1;cycles(9000);
   if(live || tv || !buzz || scan_seen!=255)$fatal(1,"default or scan");
   result(1);if(!live || !tv || !led[1] || !led[2])$fatal(1,"new result missing");
   cycles(11000);result(1);cycles(10000);
   if(live || tv || led[1] || led[2])$fatal(1,"duplicate refreshed age");
   page=1;cycles(17000);if(dig!=8'hbf && dig!=255)$fatal(1,"stale coordinates not blank");
   dual=1;cycles(2000);x=400;y=600;result(2);cycles(2000);
   if(sel!=8'hf0 || dig!=8'h0f)$fatal(1,"dual signs/magnitudes %h %h",sel,dig);
   x=640;y=360;result(3);cycles(2000);
   if(sel!=255 || dig!=8'hee)$fatal(1,"center deadzone indication");
   // Clear loss sounds, then count each requested tone envelope at output.
   cycles(260000);cal_ok=1;cal=1;cycles(1);cal=0;cycles(1000);
   if(dut.sound_ms==0)$fatal(1,"success tone missing");
   cycles(81000);if(!buzz || dut.sound_ms!=0)$fatal(1,"success tone did not finish");
   cal_ok=0;cal=1;cycles(1);cal=0;cycles(90000);
   if(!buzz)$fatal(1,"failure inter-tone gap missing");
   cycles(80000);if(dut.sound_ms==0)$fatal(1,"failure second tone missing");
   cycles(80000);if(!buzz || dut.sound_ms!=0)$fatal(1,"event repeatedly retriggered");
   $display("PASS F2 panel: decimal digits, scan blanking, duplicate timeout, stale blank, dual sign/deadzone, event sounds");$finish;
 end
endmodule
