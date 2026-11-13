// Position encoding: 0=A, 1=B, 2=C. Door bits: 0=open, 1=closed.
// move_cmd: 0=none, 1=move crew1 one zone forward, 2=move crew2 forward.
// close_cmd[0]=close AB, close_cmd[1]=close BC (pulses, never auto-open).
module supervisory_fsm
(input wire clk, rst, loop_reset, plant_step,
 input wire [1:0] crew1_pos, crew2_pos,
 input wire [3:0] oxygen_a, oxygen_b, oxygen_c,
 input wire [4:0] power,
 input wire door_ab, door_bc,
 input wire [3:0] evac_threshold,
 output reg [1:0] move_cmd, close_cmd,
 output reg [2:0] phase);

localparam MONITOR=3'd0, EVAC_A=3'd1, SEAL_A=3'd2, EVAC_B=3'd3, SAFE=3'd4;
 
reg [2:0] next_phase;

always @* begin
    next_phase=phase;
    move_cmd=0; 
    close_cmd=0;
    case(phase)
        MONITOR: 
	    if(crew1_pos==0 && oxygen_a<=evac_threshold) 
		next_phase=EVAC_A;
            else if(crew1_pos!=0) 
		next_phase=SEAL_A;

        EVAC_A: 
	    begin
       	    if(crew1_pos!=0) 
		next_phase=SEAL_A;
            else if(!door_ab && oxygen_a>2 && power>=3) 
		move_cmd=2'd1;
     	    end

       SEAL_A: 
	    begin
            if(crew1_pos==0) 
	        next_phase=EVAC_A;
       	    else if(!door_ab && power>=2) 
	        close_cmd[0]=1;
      	    else if(door_ab) 
	        next_phase=EVAC_B;
    	    end

       EVAC_B: 
	    begin
       	    if(crew1_pos==1 && !door_bc && oxygen_b>2 && power>=3) 
		move_cmd=2'd1;
            else if(crew2_pos==1 && !door_bc && oxygen_b>2 && power>=3) 
		move_cmd=2'd2;
            if(crew1_pos==2 && crew2_pos==2) 
		next_phase=SAFE;
       	    end

       SAFE: 
	    begin
            if(crew1_pos==2 && crew2_pos==2 && !door_bc && power>=2) 
		close_cmd[1]=1;
     	    end

       default: next_phase=MONITOR;

   endcase
end

always @(posedge clk or posedge rst) begin
    if(rst) phase<=MONITOR;
    else if(loop_reset) phase<=MONITOR;
    else if(plant_step) phase<=next_phase;
end

endmodule
