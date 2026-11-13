module thermal_controller (
    input  wire [3:0] h,           // 현재 발전기 온도
    input  wire       g_on,        // 발전기 작동 여부
    input  wire [3:0] h_safe,      // 냉각 안전 기준 온도 (Outer Loop에서 전달)
    output reg        u_c          // 냉각 장치 작동 명령 (C_ON)
);
    wire [4:0] h_pred;             // 예측 온도

    // H_pred = H + 3*G_ON - 1 (자연 냉각 -1 반영)
    assign h_pred = {1'b0, h} + (g_on ? 5'd3 : 5'd0) - 5'd1;

    always @(*) begin
        // 예측 온도가 안전 기준 이상이면 냉각 장치 가동
        if (h_pred >= {1'b0, h_safe}) begin
            u_c = 1'b1;
        end else begin
            u_c = 1'b0;
        end
    end
endmodule