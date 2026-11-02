`timescale 1ns/1ps
// Exhaustive dump of the original contest assets, not a video compositor.
module tb_osd_assets;
    reg [14:0] addr;
    wire [24:0] pixel;
    reg [7:0] char_code;
    reg [3:0] row;
    wire [15:0] row_bits;
    reg test_done=0, test_passed=0;
    integer logo_file,font_file,i,j,errors;
    anlogic_logo_rom logo (.I_addr(addr),.O_pixel(pixel));
    osd_char_lib font (.I_char(char_code),.I_row(row),.O_row_bits(row_bits));
    initial begin
        addr=0; char_code=0; row=0; errors=0;
        logo_file=$fopen("logo.csv","w");
        font_file=$fopen("font.csv","w");
        if (!logo_file || !font_file) begin
            $display("FAIL: cannot open asset CSV"); $finish;
        end
        $fdisplay(logo_file,"addr,pixel");
        $fdisplay(font_file,"char,row,bits");
        for (i=0;i<32768;i=i+1) begin
            addr=i; #1;
            if ((^pixel) === 1'bx) errors=errors+1;
            $fdisplay(logo_file,"%0d,%07h",i,pixel);
        end
        for (i=0;i<256;i=i+1)
            for (j=0;j<16;j=j+1) begin
                char_code=i; row=j; #1;
                if ((^row_bits) === 1'bx) errors=errors+1;
                $fdisplay(font_file,"%0d,%0d,%04h",i,j,row_bits);
            end
        $fclose(logo_file); $fclose(font_file);
        test_done=1; test_passed=(errors==0);
        $display("LogoAddresses=32768 FontRows=4096 UnknownErrors=%0d",errors);
        if (test_passed) $display("PASS: OSD asset RTL dump completed.");
        else $display("FAIL: unknown asset values");
        $finish;
    end
    initial begin
        #100000;
        $display("FAIL: OSD asset watchdog timeout"); $finish;
    end
endmodule
