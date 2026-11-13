
`timescale 1ns / 1ps

module time_fsm #(
    parameter [3:0] MAX_LOOPS = 4'd3
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire tick,

    // Failure Detector에서 전달받는 판정 결과
    input wire is_failed,
    input wire is_success,
    input wire [2:0] fail_code,

    // 현재 시뮬레이션 시간과 루프 번호
    output reg [2:0] time_step,
    output reg [3:0] loop_count,

    // 다른 모듈의 동작 시점을 제어하는 신호
    output wire plant_step,
    output wire supervisor_commit,
    output wire loop_reset,
    output wire failure_save,
    output wire memory_clear,

    // Loop Memory로 전달할 실패 코드
    output wire [2:0] saved_failure_code,

    // 전체 진행 상태
    output wire running,
    output wire done,
    output wire success
);

    // FSM 상태 정의
    localparam IDLE      = 3'd0,
               RESTART   = 3'd1,
               WAIT_TICK = 3'd2,
               APPLY     = 3'd3,
               CHECK     = 3'd4,
               SAVE      = 3'd5,
               ADVANCE   = 3'd6,
               FINISH    = 3'd7;

    // 현재 FSM 상태
    reg [2:0] state;

    // 최종 성공 여부를 저장하는 레지스터
    reg terminal_success;

    // CHECK에서 확인한 실패 코드를 저장
    reg [2:0] pending_fail_code;

    // Plant Model은 APPLY 상태에서만 갱신
    assign plant_step = (state == APPLY);

    // Supervisory FSM은 Plant 갱신 후 CHECK에서 전이
    assign supervisor_commit = (state == CHECK);

    // 새로운 루프가 시작될 때 Plant 상태 초기화
    assign loop_reset = (state == RESTART);

    // SAVE 상태에서 이전 루프의 실패 정보 저장
    assign failure_save = (state == SAVE);

    // 첫 번째 루프 시작 시 이전 실행의 실패 기록 삭제
    assign memory_clear =
        (state == RESTART && loop_count == 4'd1);

    // CHECK에서 저장한 실패 코드를 Memory로 전달
    assign saved_failure_code = pending_fail_code;

    // 현재 진행 여부
    assign running =
        (state != IDLE && state != FINISH);

    // 종료 여부
    assign done = (state == FINISH);

    // 성공적으로 종료했는지 표시
    assign success =
        (state == FINISH) && terminal_success;

    // FSM 상태 전이 및 시간 관리
    always @(posedge clk) begin

        if (rst) begin
            // 전체 시스템 초기화
            state <= IDLE;
            time_step <= 3'd0;
            loop_count <= 4'd0;
            terminal_success <= 1'b0;
            pending_fail_code <= 3'd0;
        end

        else begin
            case (state)

                IDLE: begin
                    // START 입력 시 첫 번째 루프 시작
                    if (start) begin
                        loop_count <= 4'd1;
                        time_step <= 3'd0;
                        terminal_success <= 1'b0;
                        pending_fail_code <= 3'd0;
                        state <= RESTART;
                    end
                end

                RESTART: begin
                    // Plant와 Supervisory FSM 초기화 후 대기
                    state <= WAIT_TICK;
                end

                WAIT_TICK: begin
                    // 다음 시간 진행 신호가 올 때까지 대기
                    if (tick)
                        state <= APPLY;
                end

                APPLY: begin
                    // 이 상태에서 Plant Model이 갱신됨
                    // 다음 클록에서 CHECK 상태로 이동
                    state <= CHECK;
                end

                CHECK: begin
                    // Plant 갱신 결과를 Failure Detector로 확인

                    if (is_failed) begin
                        // 실패 코드가 유효하지 않으면 오류 코드 7 저장
                        if (fail_code >= 3'd1 &&
                            fail_code <= 3'd4)
                            pending_fail_code <= fail_code;
                        else
                            pending_fail_code <= 3'd7;

                        state <= SAVE;
                    end

                    else if (time_step == 3'd7) begin
                        // 마지막 시간 단계에서 성공 여부 확인
                        if (is_success) begin
                            terminal_success <= 1'b1;
                            state <= FINISH;
                        end
                        else begin
                            // 마지막 시간인데 성공도 실패도 아니면
                            // 판정기 인터페이스 오류로 처리
                            pending_fail_code <= 3'd7;
                            state <= SAVE;
                        end
                    end

                    else begin
                        // 아직 실패하지 않았으면 다음 시간으로
                        state <= ADVANCE;
                    end
                end

                SAVE: begin
                    // 현재 루프의 실패 정보를 저장한 후 진행

                    if (loop_count >= MAX_LOOPS) begin
                        // 최대 반복 횟수 도달: 최종 실패
                        terminal_success <= 1'b0;
                        state <= FINISH;
                    end

                    else begin
                        // 다음 루프로 이동
                        loop_count <= loop_count + 1'b1;
                        time_step <= 3'd0;
                        state <= RESTART;
                    end
                end

                ADVANCE: begin
                    // 다음 시간 단계로 진행
                    time_step <= time_step + 1'b1;
                    state <= WAIT_TICK;
                end

                FINISH: begin
                    // START를 다시 누르면 새로운 실행 시작
                    if (start) begin
                        loop_count <= 4'd1;
                        time_step <= 3'd0;
                        terminal_success <= 1'b0;
                        pending_fail_code <= 3'd0;
                        state <= RESTART;
                    end
                end

                default: begin
                    // 정의되지 않은 FSM 상태는 IDLE로 복귀
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
