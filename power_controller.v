다음 시간 단계의 전력을 미리 예측하여, 정전 위험이 있으면 발전기를 미리 가동
module power_controller (
    input  wire [4:0] p,           // 현재 전력 잔량
    input  wire       g_on_current,// 현재 발전기 작동 상태
    input  wire [4:0] c_expected,  // 예상 전력 소비량 (기본 생명유지+장치 등)
    input  wire [4:0] p_safe,      // 안전 전력 기준값 (Outer Loop에서 전달)
    output reg        g_on         // 발전기 가동 명령
);
    wire [4:0] g_val;
    wire [5:0] p_pred;             // 다음 시간 예측 전력 (오버플로우 방지 6비트)

    assign g_val = g_on_current ? 5'd5 : 5'd0; // 발전기 켜면 한 단계당 +5
    assign p_pred = {1'b0, p} + {1'b0, g_val} - {1'b0, c_expected};

    always @(*) begin
        // 예측 전력이 안전 기준보다 낮으면 미리 발전기를 켬
        if (p_pred < {1'b0, p_safe}) begin
            g_on = 1'b1;
        end else begin
            g_on = 1'b0;
        end
    end
endmodule
