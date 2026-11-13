// Plant updates on plant_step pulse. The following CHECK cycle sees registered new state.
module time_fsm #(parameter [3:0] MAX_LOOPS=4'd3)
(input wire clk, rst, start, tick,
 input wire [2:0] failure_code, // 0=normal, 1=suffocation, 2=trapped, 3=blackout, 4=overheat
 input wire all_safe, // both crew in C; used at the end of step 7
 output reg [2:0] time_step,
 output reg [3:0] loop_count,
 output reg plant_step, loop_reset, failure_save,
 output reg [2:0] saved_failure_code,
 output reg running, done, success);

localparam IDLE=3'd0, WAIT_TICK=3'd1, APPLY=3'd2,
            CHECK=3'd3, ADVANCE=3'd4, RESTART=3'd5, FINISH=3'd6;

reg [2:0] state;
reg [2:0] effective_fail;

always @* begin
    effective_fail = failure_code;

    if (failure_code==3'd0 && time_step==3'd7 && !all_safe)
        effective_fail=3'd2;
end

always @* begin
    plant_step=0; loop_reset=0; failure_save=0;
    saved_failure_code=effective_fail;
    running=0; done=0; success=0;

   case(state)
     WAIT_TICK: running=1;

     APPLY: 
	begin 
	running=1; 
	plant_step=1; 
 	end

     CHECK: 
	begin 
	running=1; 
	if(effective_fail!=0) 
	    failure_save=1; 
	end

     ADVANCE: 
	running=1;

     RESTART: 
	begin 
	running=1; 
	loop_reset=1; 
	end

     FINISH: 
	begin 
	done=1; 
	success=terminal_success; 
	end

     default: ;
   endcase
end

reg terminal_success;

always @(posedge clk or posedge rst) begin
    if(rst) begin 
	state<=IDLE; 
	time_step<=0; 
	loop_count<=0; 
	terminal_success<=0; 
    end
    else begin
        case(state)
       	    IDLE: 
	        if(start) begin 
		    loop_count<=1; 
		    time_step<=0; 
		    state<=RESTART; 
		end

       	    RESTART: state<=WAIT_TICK;

       	    WAIT_TICK: 
		if(tick) 
		    state<=APPLY;

      	    APPLY: state<=CHECK;

       	    CHECK: 
		begin
         	    if(effective_fail!=0) begin
           	        if(loop_count>=MAX_LOOPS) begin 
			    terminal_success<=0; 
		  	    state<=FINISH; 
			end
          	    	else begin 
			    loop_count<=loop_count+1'b1; 
			    time_step<=0; 
			    state<=RESTART; 
			end
         	    end 
		    else if(time_step==7) begin 
			terminal_success<=all_safe; 
			state<=FINISH; 
		    end
         	    else state<=ADVANCE;
       		end

            ADVANCE: 
		begin 
		    time_step<=time_step+1'b1; 
		    state<=WAIT_TICK; 
		end

            FINISH: 
		if(start) begin 
		    loop_count<=1; 
		    time_step<=0; 
	    	    state<=RESTART; 
		end

            default: state<=IDLE;
        endcase
    end
end

endmodule
