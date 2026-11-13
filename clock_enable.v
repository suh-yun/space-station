module clock_enable #(parameter integer DIVISOR=100_000_000)
(input wire clk, input wire rst, output reg tick);

reg [31:0] count;

always @(posedge clk or posedge rst) begin

    if (rst) begin 
	count<=0; tick<=0; 
    end

    else if (count==DIVISOR-1) begin 
	count<=0; tick<=1; 
    end

    else begin 
	count<=count+1'b1; 
	tick<=0; 
    end
end

endmodule
