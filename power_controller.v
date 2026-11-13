`timescale 1ns / 1ps
module power_controller (
    input wire [4:0] p,
    input wire g_on_current,
    input wire [4:0] c_expected,
    input wire [4:0] p_safe,
    output reg g_on
);
    // Signed and wide enough for 0..31 + 5 - (0..31).
    wire signed [6:0] p_pred_current;
    assign p_pred_current = $signed({2'b00, p})
                          + (g_on_current ? 7'sd5 : 7'sd0)
                          - $signed({2'b00, c_expected});
    always @(*) begin
        g_on = (p_pred_current < $signed({2'b00, p_safe}));
    end
endmodule
