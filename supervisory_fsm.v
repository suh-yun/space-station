
`timescale 1ns / 1ps

module supervisory_fsm(
    input wire clk,
    input wire rst,
    input wire loop_reset,
    input wire supervisor_commit,

    // Plant Model에서 전달받는 현재 상태
    input wire [1:0] crew1_pos,
    input wire [1:0] crew2_pos,
    input wire [3:0] oxygen_a,
    input wire [3:0] oxygen_b,
    input wire [3:0] oxygen_c,
    input wire [4:0] power,
    input wire door_AB,
    input wire door_BC,

    // Parameter Updater에서 전달받는 대피 기준
    input wire [3:0] evac_threshold,

    // Plant Model에 전달하는 제어 명령
    output reg move_crew1,
    output reg move_crew2,
    output reg door_ab_cmd,
    output reg door_bc_cmd,

    // 현재 Supervisory FSM 상태
    output reg [2:0] phase
);

    // 구역 정의
    localparam ZONE_A = 2'd0,
               ZONE_B = 2'd1,
               ZONE_C = 2'd2;

    // Supervisory FSM 상태 정의
    localparam MONITOR = 3'd0,
               OPEN_AB = 3'd1,
               EVAC_A  = 3'd2,
               SEAL_A  = 3'd3,
               OPEN_BC = 3'd4,
               EVAC_B  = 3'd5,
               SEAL_BC = 3'd6,
               SAFE    = 3'd7;

    // 다음 FSM 상태 저장 변수
    reg [2:0] next_phase;

    // 조합논리: 현재 상태를 확인하고 제어 명령 및 다음 상태 결정
    always @(*) begin

        // 기본값 설정 (Latch 발생 방지)
        next_phase = phase;

        // 기본적으로 승무원 이동 명령 없음
        move_crew1 = 1'b0;
        move_crew2 = 1'b0;

        // 격벽은 별도 명령이 없으면 현재 상태 유지
        // Plant Model 기준: 1=열림, 0=닫힘
        door_ab_cmd = door_AB;
        door_bc_cmd = door_BC;

        case (phase)

            // 1. A구역 산소량 감시
            MONITOR: begin
                if (crew1_pos == ZONE_A) begin
                    // 산소량이 대피 기준 이하이면 구조 시작
                    if (oxygen_a <= evac_threshold)
                        next_phase = OPEN_AB;
                end
                else if (crew1_pos == ZONE_B ||
                         crew1_pos == ZONE_C) begin
                    // 승무원 1이 이미 A구역을 벗어났으면
                    // A-B 격벽 폐쇄 단계로 이동
                    next_phase = SEAL_A;
                end
                else begin
                    // 정의되지 않은 위치라면 MONITOR 유지
                    next_phase = MONITOR;
                end
            end

            // 2. A-B 격벽 개방
            OPEN_AB: begin
                if (door_AB == 1'b0) begin
                    // 격벽이 닫혀 있고 전력이 충분하면 개방
                    if (power >= 5'd2)
                        door_ab_cmd = 1'b1;
                end
                else begin
                    // 실제 격벽 개방 확인 후 이동 단계로 전이
                    next_phase = EVAC_A;
                end
            end

            // 3. 승무원 1을 A구역에서 B구역으로 이동
            EVAC_A: begin
                if (crew1_pos == ZONE_B) begin
                    // 실제 이동 완료 확인
                    next_phase = SEAL_A;
                end
                else if (crew1_pos == ZONE_A) begin
                    // 격벽이 열려 있고 산소 및 전력이 충분하면 이동
                    if (door_AB == 1'b1 &&
                        oxygen_a > 4'd0 &&
                        power >= 5'd3)
                        move_crew1 = 1'b1;
                end
                else begin
                    // 예상하지 못한 위치라면 감시 단계로 복귀
                    next_phase = MONITOR;
                end
            end

            // 4. A-B 격벽 폐쇄
            SEAL_A: begin
                if (crew1_pos == ZONE_A) begin
                    // 승무원 1이 아직 A구역에 있으면 다시 구조 시도
                    next_phase = OPEN_AB;
                end
                else if (door_AB == 1'b1) begin
                    // 승무원 1이 A구역을 벗어났고 격벽이 열려 있다면 폐쇄
                    if (power >= 5'd2)
                        door_ab_cmd = 1'b0;
                end
                else begin
                    // 격벽이 닫힌 것을 확인하면 B-C 격벽 개방 단계
                    next_phase = OPEN_BC;
                end
            end

            // 5. B-C 격벽 개방
            OPEN_BC: begin
                if (door_BC == 1'b0) begin
                    // 격벽이 닫혀 있고 전력이 충분하면 개방
                    if (power >= 5'd2)
                        door_bc_cmd = 1'b1;
                end
                else begin
                    // 실제 격벽 개방 확인 후 대피 단계로 전이
                    next_phase = EVAC_B;
                end
            end

            // 6. 승무원들을 B구역에서 C구역으로 이동
            EVAC_B: begin
                if (crew1_pos == ZONE_C &&
                    crew2_pos == ZONE_C) begin
                    // 두 승무원 모두 C구역에 도착하면 격벽 폐쇄 단계
                    next_phase = SEAL_BC;
                end
                else if (door_BC == 1'b0) begin
                    // B-C 격벽이 닫혀 있다면 다시 개방
                    next_phase = OPEN_BC;
                end
                else if (oxygen_b > 4'd0 &&
                         power >= 5'd3) begin

                    // 승무원 1이 B구역에 있으면 먼저 이동
                    if (crew1_pos == ZONE_B)
                        move_crew1 = 1'b1;

                    // 승무원 1이 C구역에 도착한 후 승무원 2 이동
                    else if (crew1_pos == ZONE_C &&
                             crew2_pos == ZONE_B)
                        move_crew2 = 1'b1;
                end
            end

            // 7. B-C 격벽 폐쇄
            SEAL_BC: begin
                if (crew1_pos == ZONE_C &&
                    crew2_pos == ZONE_C) begin

                    if (door_BC == 1'b1) begin
                        // 두 승무원이 안전 구역에 도착한 후 격벽 폐쇄
                        if (power >= 5'd2)
                            door_bc_cmd = 1'b0;
                    end
                    else begin
                        // 격벽까지 닫힌 것을 확인하면 구조 완료
                        next_phase = SAFE;
                    end
                end
                else begin
                    // 승무원이 아직 남아 있다면 대피 단계로 복귀
                    next_phase = EVAC_B;
                end
            end

            // 8. 구조 완료
            SAFE: begin
                // 두 승무원 모두 C구역에 도착한 상태
                // 현재 격벽 상태를 유지하고 추가 이동 명령 없음
                next_phase = SAFE;
            end

            // 정의되지 않은 상태 처리
            default: begin
                next_phase = MONITOR;
            end

        endcase
    end

    // 순차논리: FSM 상태 레지스터 갱신
    always @(posedge clk) begin
        if (rst) begin
            // 전체 Reset
            phase <= MONITOR;
        end
        else if (loop_reset) begin
            // 새로운 타임 루프 시작 시 구조 단계 초기화
            phase <= MONITOR;
        end
        else if (supervisor_commit) begin
            // Plant Model이 갱신된 이후 실제 상태를 확인하고 전이
            phase <= next_phase;
        end
    end

endmodule
