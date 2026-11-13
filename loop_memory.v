
`timescale 1ns / 1ps

module loop_memory(
    input wire clk,
    input wire rst,

    // 새로운 시뮬레이션 시작 시 기록 초기화
    input wire memory_clear,

    // Time FSM에서 전달받는 실패 저장 신호
    input wire failure_save,

    // 저장할 실패 정보
    input wire [2:0] failure_code,
    input wire [2:0] time_step,
    input wire [3:0] loop_count,

    // 가장 최근에 발생한 실패 기록
    output reg [2:0] last_failure_code,
    output reg [2:0] last_failure_time,
    output reg [3:0] last_failure_loop,

    // 누적 실패 횟수
    output reg [3:0] failure_count
);

    always @(posedge clk) begin

        if (rst || memory_clear) begin
            // 전체 Reset 또는 새 실행 시작 시 기록 삭제
            last_failure_code <= 3'd0;
            last_failure_time <= 3'd0;
            last_failure_loop <= 4'd0;
            failure_count <= 4'd0;
        end

        else if (failure_save &&
                 failure_code != 3'd0) begin

            // 실패 원인과 발생 시점 저장
            last_failure_code <= failure_code;
            last_failure_time <= time_step;
            last_failure_loop <= loop_count;

            // 4비트 카운터의 오버플로 방지
            if (failure_count < 4'd15)
                failure_count <= failure_count + 1'b1;
        end

    end

endmodule
