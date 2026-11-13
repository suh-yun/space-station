// 시간 흐름에 따라 우주정거장에 닥치는 외부 환경 악화 데이터를 저장해 두고 꺼내는 모듈
// 입력: 현재 몇 시작쨰인지 (time step)
// 하는 일: 현재 시간에 A구역에서 산소가 얼마나 새어 나가는지
// 정거장 유지에 기본적으로 드는 전력 ( base_load:1)을 출력

`timescale 1ns / 1ps

module event_rom (
    input  wire [2:0] time_step,   // 0 ~ 7 시간 단계
    output reg  [3:0] leak_rate,   // A구역 산소 누출량 (0 ~ 15)
    output reg  [4:0] base_load    // 기본 전력 소비량 (기본 생명유지장치 = 1)
);

    always @(*) begin
        base_load = 5'd1; // 기본 생명유지장치 소비 전력 고정 1
        
        case (time_step)
            3'd0: leak_rate = 4'd0;
            3'd1: leak_rate = 4'd1;
            3'd2: leak_rate = 4'd2;
            3'd3: leak_rate = 4'd3;
            3'd4: leak_rate = 4'd3;
            3'd5: leak_rate = 4'd4;
            3'd6: leak_rate = 4'd4;
            3'd7: leak_rate = 4'd5;
            default: leak_rate = 4'd0;
        endcase
    end

endmodule
