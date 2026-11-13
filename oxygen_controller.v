module oxygen_controller (
    input  wire [3:0] o_ref,       // 목표 산소량 (Outer Loop에서 전달)
    input  wire [3:0] o_c,         // 현재 C구역 산소량
    output reg  [1:0] u_o          // 산소 공급량 제어 입력 (0, 1, 2)
);
    wire signed [4:0] e_o;         // 산소 오차 (음수 표현을 위해 signed 선언)
    
    assign e_o = {1'b0, o_ref} - {1'b0, o_c};

    always @(*) begin
        if (e_o >= 5'sd4) begin
            u_o = 2'd2;            // 부족함이 심하면 대량 공급
        end else if (e_o > 5'sd0) begin
            u_o = 2'd1;            // 조금 부족하면 소량 공급
        end else begin
            u_o = 2'd0;            // 충분하면 공급 중단
        end
    end
endmodule