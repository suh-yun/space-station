// Records the most recent failure. History count saturates at 15.
// Parameter changes are intentionally owned by Team B's parameter_updater.
module loop_memory
(input wire clk, rst, failure_save,
 input wire [2:0] failure_code, time_step,
 input wire [3:0] loop_count,
 output reg [2:0] last_failure_code, last_failure_time,
 output reg [3:0] last_failure_loop, failure_count);

always @(posedge clk or posedge rst) begin
    if(rst) begin
        last_failure_code<=0; 
	last_failure_time<=0;
        last_failure_loop<=0; 
	failure_count<=0;
    end 
    else if(failure_save && failure_code!=0) begin
        last_failure_code<=failure_code;
        last_failure_time<=time_step;
        last_failure_loop<=loop_count;
            if(failure_count!=15) 
		failure_count<=failure_count+1'b1;
    end
end
endmodule
