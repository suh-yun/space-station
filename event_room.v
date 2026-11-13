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
