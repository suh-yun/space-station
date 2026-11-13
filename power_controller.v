`timescale 1ns / 1ps
module power_controller (
    input wire [4:0] p,
    input wire g_on_current, // kept for compatibility; not used in decision
    input wire [4:0] c_expected,
    input wire [4:0] p_safe,
    output reg g_on
);
    // Evaluate the next step WITHOUT generation. If it falls below the
    // safety reserve, enable generation for this step (+5 in plant_model).
    // Do not connect g_on_current to g_on to form a combinational loop.
    wire signed [6:0] p_without_gen;
    assign p_without_gen = $signed({2'b00,p}) - $signed({2'b00,c_expected});
    always @(*) begin
        g_on = (p_without_gen < $signed({2'b00,p_safe}));
    end
endmodule
