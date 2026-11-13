// Nexys A7: an[7:0] and seg[6:0] are active LOW; seg order = abcdefg.
// Eight digits: [loop][time][O_A][O_B][O_C][power tens][power ones][failure]
module display_controller
(input wire clk, rst,
 input wire [3:0] loop_count,
 input wire [2:0] time_step, failure_code,
 input wire [3:0] oxygen_a, oxygen_b, oxygen_c, temperature,
 input wire [4:0] power,
 input wire [1:0] crew1_pos, crew2_pos,
 input wire door_ab, door_bc, generator_on, cooling_on,
 input wire done, success,
 output reg [15:0] led,
 output reg [7:0] an,
 output reg [6:0] seg,
 output wire dp);

reg [16:0] refresh;
reg [3:0] digit;

assign dp=1'b1;

always @(posedge clk or posedge rst)
   if(rst) refresh<=0;
   else refresh<=refresh+1'b1;

always @* begin
   // LED map: [15]success [14]done [13:12]crew1 [11:10]crew2
   // [9]AB [8]BC [7]generator [6]cooling [5:2]temperature [1:0]failure low bits
    led={success,done,crew1_pos,crew2_pos,door_ab,door_bc,
         generator_on,cooling_on,temperature,failure_code[1:0]};

    an=8'b11111111; digit=4'hf;
        case(refresh[16:14])
     	    3'd0: begin an=8'b11111110; digit={1'b0,failure_code}; end
     3'd1: begin an=8'b11111101; digit=power%10; end
     3'd2: begin an=8'b11111011; digit=power/10; end
     3'd3: begin an=8'b11110111; digit=oxygen_c; end
     3'd4: begin an=8'b11101111; digit=oxygen_b; end
     3'd5: begin an=8'b11011111; digit=oxygen_a; end
     3'd6: begin an=8'b10111111; digit={1'b0,time_step}; end
     3'd7: begin an=8'b01111111; digit=loop_count; end
   endcase
   case(digit)
     4'h0: seg=7'b0000001; 4'h1: seg=7'b1001111;
     4'h2: seg=7'b0010010; 4'h3: seg=7'b0000110;
     4'h4: seg=7'b1001100; 4'h5: seg=7'b0100100;
     4'h6: seg=7'b0100000; 4'h7: seg=7'b0001111;
     4'h8: seg=7'b0000000; 4'h9: seg=7'b0000100;
     4'ha: seg=7'b0001000; 4'hb: seg=7'b1100000;
     4'hc: seg=7'b0110001; 4'hd: seg=7'b1000010;
     4'he: seg=7'b0110000; default: seg=7'b0111000;
   endcase
 end
endmodule
