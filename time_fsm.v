
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

    // 현재 시뮬레이션 시간 및 루프 번호
    output reg [2:0] time_step,
    output reg [3:0] loop_count,

    // 다른 모듈의 동작 시점을 제어하는 신호
    output wire plant_step,
    output wire supervisor_commit,
    output wire loop_reset,
    output wire failure_save,
    output wire memory_clear,

    // Loop Memory와 Parameter Updater에 전달할 실패 코드
    output wire [2:0] saved_failure_code,

    // 전체 진행 상태
    output wire running,
    output wire done,
    output wire success
);

    // Time FSM 상태 정의
    localparam IDLE      = 3'd0,
               RESTART   = 3'd1,
               WAIT_TICK = 3'd2,
               APPLY     = 3'd3,
               CHECK     = 3'd4,
               SAVE      = 3'd5,
               ADVANCE   = 3'd6,
               FINISH    = 3'd7;

    // 실패 코드 정의
    localparam FAIL_SUFFOCATION = 3'b001,
               FAIL_BLACKOUT    = 3'b010,
               FAIL_OVERHEAT    = 3'b011,
               FAIL_ISOLATION   = 3'b100,
               FAIL_INVALID     = 3'b111;

    // 현재 FSM 상태
    reg [2:0] state;

    // 최종 성공 여부 저장
    reg terminal_success;

    // CHECK 상태에서 확정한 실패 코드 저장
    reg [2:0] pending_fail_code;

    // Plant Model은 APPLY 상태에서만 갱신
    assign plant_step = (state == APPLY);

    // Plant 갱신 후 CHECK에서 Supervisory FSM 상태 전이
    // 실패가 발생한 경우에는 상태 전이하지 않음
    assign supervisor_commit =
        (state == CHECK) && !is_failed && !is_success;

    // 새로운 루프 시작 시 Plant와 Supervisory FSM 초기화
    assign loop_reset = (state == RESTART);

    // SAVE 상태에서 실패 정보 저장 및 파라미터 갱신
    assign failure_save = (state == SAVE);

    // 첫 번째 루프 시작 시 이전 실행의 실패 기록 삭제
    assign memory_clear =
        (state == RESTART && loop_count == 4'd1);

    // CHECK에서 저장한 실패 코드 전달
    assign saved_failure_code = pending_fail_code;

    // 전체 시뮬레이션 진행 여부
    assign running =
        (state != IDLE && state != FINISH);

    // 전체 시뮬레이션 종료 여부
    assign done = (state == FINISH);

    // 최종 성공 여부
    assign success =
        (state == FINISH) && terminal_success;

    // Time FSM 상태 전이 및 시간 관리
    always @(posedge clk) begin

        if (rst) begin
            // 전체 시스템 Reset
            state <= IDLE;
            time_step <= 3'd0;
            loop_count <= 4'd0;
            terminal_success <= 1'b0;
            pending_fail_code <= 3'd0;
        end

        else begin
            case (state)

                // 1. 시뮬레이션 시작 대기
                IDLE: begin
                    if (start) begin
                        loop_count <= 4'd1;
                        time_step <= 3'd0;
                        terminal_success <= 1'b0;
                        pending_fail_code <= 3'd0;
                        state <= RESTART;
                    end
                end

                // 2. 새로운 루프 시작
                RESTART: begin
                    // loop_reset이 1인 동안
                    // Plant와 Supervisory FSM 초기화
                    state <= WAIT_TICK;
                end

                // 3. 다음 시간 단계 진행 신호 대기
                WAIT_TICK: begin
                    if (tick)
                        state <= APPLY;
                end

                // 4. Plant Model 갱신
                APPLY: begin
                    // plant_step = 1
                    // 이 상태에서 다음 클록 상승 에지에
                    // Plant Model이 현재 명령을 적용
                    state <= CHECK;
                end

                // 5. 갱신된 Plant 상태로 성공/실패 판정
                CHECK: begin

                    if (is_failed) begin
                        // Failure Detector에서 전달받은
                        // 실패 코드가 유효한지 확인
                        case (fail_code)

                            FAIL_SUFFOCATION,
                            FAIL_BLACKOUT,
                            FAIL_OVERHEAT,
                            FAIL_ISOLATION,
                            FAIL_INVALID: begin
                                pending_fail_code <= fail_code;
                            end

                            default: begin
                                // 정의되지 않은 실패 코드
                                pending_fail_code <= FAIL_INVALID;
                            end

                        endcase

                        // 실패 기록 저장 단계로 이동
                        state <= SAVE;
                    end

                    else if (time_step == 3'd7) begin

                        // 마지막 시간 단계에서 성공 여부 확인
                        if (is_success) begin
                            terminal_success <= 1'b1;
                            state <= FINISH;
                        end

                        else begin
                            // 마지막 시간에 성공/실패 판정이
                            // 모두 없는 비정상 상황
                            pending_fail_code <= FAIL_INVALID;
                            state <= SAVE;
                        end
                    end

                    else begin
                        // 아직 실패하지 않았으면 다음 시간으로
                        state <= ADVANCE;
                    end
                end

                // 6. 실패 정보 저장 및 다음 루프 준비
                SAVE: begin

                    // 이 상태에서 failure_save = 1
                    // Loop Memory는 실패 정보 저장
                    // Parameter Updater는 제어 파라미터 갱신

                    if (loop_count >= MAX_LOOPS) begin
                        // 최대 루프 횟수 도달
                        // 최종 실패 처리
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

                // 7. 다음 시간 단계로 진행
                ADVANCE: begin
                    time_step <= time_step + 1'b1;
                    state <= WAIT_TICK;
                end

                // 8. 전체 시뮬레이션 종료
                FINISH: begin

                    // START를 다시 누르면 새로운 시뮬레이션 시작
                    if (start) begin
                        loop_count <= 4'd1;
                        time_step <= 3'd0;
                        terminal_success <= 1'b0;
                        pending_fail_code <= 3'd0;
                        state <= RESTART;
                    end
                end

                // 정의되지 않은 상태 처리
                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
