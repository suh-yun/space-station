
`timescale 1ns / 1ps

module supervisory_fsm(
    input wire clk,
    input wire rst,
    input wire loop_reset,
    input wire supervisor_commit,

    // Plant Model의 현재 상태
    input wire [1:0] crew1_pos,
    input wire [1:0] crew2_pos,
    input wire [3:0] oxygen_a,
    input wire [3:0] oxygen_b,
    input wire [3:0] oxygen_c,
    input wire [4:0] power,
    input wire door_AB,
    input wire door_BC,

    // Parameter Updater에서 전달하는 대피 기준
    input wire [3:0] evac_threshold,

    // Plant Model로 전달할 명령
    output reg move_crew1,
    output reg move_crew2,
    output reg door_ab_cmd,
    output reg door_bc_cmd,

    // Supervisory FSM의 현재 상태
    output reg [2:0] phase
);

    localparam ZONE_A = 2'd0,
               ZONE_B = 2'd1,
               ZONE_C = 2'd2;

    // 기존 8개 상태를 6개로 축소
    localparam MONITOR  = 3'd0,
               OPEN_AB  = 3'd1,
               EVAC_A   = 3'd2,
               TRANSFER = 3'd3,
               EVAC_B   = 3'd4,
               SAFE     = 3'd5;

    reg [2:0] next_phase;

    // 현재 상태에 따라 다음 상태와 제어 명령 결정
    always @(*) begin

        // 기본값: 상태 유지, 승무원 이동 없음
        next_phase = phase;
        move_crew1 = 1'b0;
        move_crew2 = 1'b0;

        // 기본적으로 격벽의 현재 상태 유지
        door_ab_cmd = door_AB;
        door_bc_cmd = door_BC;

        case (phase)

            MONITOR: begin
                // A구역 산소가 기준 이하이면 대피 시작
                if (crew1_pos == ZONE_A) begin
                    if (oxygen_a <= evac_threshold)
                        next_phase = OPEN_AB;
                end
                else if (crew1_pos == ZONE_B) begin
                    next_phase = TRANSFER;
                end
                else if (crew1_pos == ZONE_C) begin
                    next_phase = EVAC_B;
                end
            end

            OPEN_AB: begin
                // AB 격벽이 열려 있지 않으면 개방
                if (!door_AB) begin
                    if (power >= 5'd2)
                        door_ab_cmd = 1'b1;
                end
                else begin
                    // 실제 개방 확인
                    next_phase = EVAC_A;
                end
            end

            EVAC_A: begin
                if (crew1_pos == ZONE_B) begin
                    // A -> B 이동이 완료되면 다음 단계
                    next_phase = TRANSFER;
                end
                else if (crew1_pos == ZONE_A) begin
                    // AB가 열린 경우에만 이동 가능
                    if (door_AB &&
                        oxygen_a > 4'd0 &&
                        power >= 5'd3)
                        move_crew1 = 1'b1;
                end
                else if (crew1_pos == ZONE_C) begin
                    next_phase = EVAC_B;
                end
            end

            TRANSFER: begin
                // 승무원 1이 B구역에 도착했을 때
                if (crew1_pos == ZONE_B) begin

                    // AB 격벽 폐쇄
                    if (door_AB && power >= 5'd2)
                        door_ab_cmd = 1'b0;

                    // BC 격벽 개방
                    if (!door_BC && power >= 5'd2)
                        door_bc_cmd = 1'b1;

                    // AB 폐쇄 및 BC 개방이 확인되면 다음 단계
                    if (!door_AB && door_BC)
                        next_phase = EVAC_B;
                end
                else if (crew1_pos == ZONE_A) begin
                    next_phase = OPEN_AB;
                end
                else if (crew1_pos == ZONE_C) begin
                    next_phase = EVAC_B;
                end
            end

            EVAC_B: begin
                // 두 승무원이 모두 C에 도착했다면 완료
                if (crew1_pos == ZONE_C &&
                    crew2_pos == ZONE_C) begin
                    next_phase = SAFE;
                end
                else if (!door_BC) begin
                    // BC 격벽이 닫혔다면 다시 개방
                    if (power >= 5'd2)
                        door_bc_cmd = 1'b1;
                end
                else if (oxygen_b > 4'd0 &&
                         power >= 5'd5) begin

                    // B구역에 있는 승무원을 동시에 이동
                    if (crew1_pos == ZONE_B)
                        move_crew1 = 1'b1;

                    if (crew2_pos == ZONE_B)
                        move_crew2 = 1'b1;
                end
            end

            SAFE: begin
                // C구역에 모두 도착한 후 BC 격벽 폐쇄
                if (door_BC && power >= 5'd2)
                    door_bc_cmd = 1'b0;

                // 추가 이동 없음
                next_phase = SAFE;
            end

            default: begin
                next_phase = MONITOR;
            end

        endcase
    end

    // Plant Model 갱신 이후 Supervisory 상태 전이
    always @(posedge clk) begin
        if (rst)
            phase <= MONITOR;
        else if (loop_reset)
            phase <= MONITOR;
        else if (supervisor_commit)
            phase <= next_phase;
    end

endmodule
