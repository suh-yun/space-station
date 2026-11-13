
`timescale 1ns / 1ps

module failure_detector (
    // Plant Model에서 전달받는 현재 상태
    input wire [3:0] O_A,
    input wire [3:0] O_B,
    input wire [3:0] O_C,
    input wire [4:0] P,
    input wire [3:0] H,

    // 승무원 위치
    input wire [1:0] crew1_pos,
    input wire [1:0] crew2_pos,

    // Time FSM에서 전달받는 현재 시간
    input wire [2:0] time_step,

    // 성공 및 실패 판정 결과
    output reg is_failed,
    output reg is_success,
    output reg [2:0] fail_code
);

    // 구역 정의
    localparam ZONE_A = 2'b00,
               ZONE_B = 2'b01,
               ZONE_C = 2'b10;

    // 실패 원인 코드 정의
    localparam FAIL_NONE        = 3'b000,
               FAIL_SUFFOCATION = 3'b001,
               FAIL_BLACKOUT    = 3'b010,
               FAIL_OVERHEAT    = 3'b011,
               FAIL_ISOLATION   = 3'b100,
               FAIL_INVALID     = 3'b111;

    // 승무원 위치 코드가 유효한지 확인
    wire invalid_position;

    assign invalid_position =
        (crew1_pos == 2'b11) ||
        (crew2_pos == 2'b11);

    // 승무원 1이 위치한 구역의 산소 고갈 여부
    wire crew1_no_o2;

    assign crew1_no_o2 =
        ((crew1_pos == ZONE_A) && (O_A == 4'd0)) ||
        ((crew1_pos == ZONE_B) && (O_B == 4'd0)) ||
        ((crew1_pos == ZONE_C) && (O_C == 4'd0));

    // 승무원 2가 위치한 구역의 산소 고갈 여부
    wire crew2_no_o2;

    assign crew2_no_o2 =
        ((crew2_pos == ZONE_A) && (O_A == 4'd0)) ||
        ((crew2_pos == ZONE_B) && (O_B == 4'd0)) ||
        ((crew2_pos == ZONE_C) && (O_C == 4'd0));

    // 두 승무원이 모두 C구역에 도착했는지 확인
    wire all_safe;

    assign all_safe =
        (crew1_pos == ZONE_C) &&
        (crew2_pos == ZONE_C);

    // 조합논리: 현재 Plant 상태를 바탕으로 성공/실패 판정
    always @(*) begin

        // 기본값: 정상 진행
        is_failed = 1'b0;
        is_success = 1'b0;
        fail_code = FAIL_NONE;

        // 1. 잘못된 승무원 위치 코드 확인
        if (invalid_position) begin
            is_failed = 1'b1;
            fail_code = FAIL_INVALID;
        end

        // 2. 질식 판정
        else if (crew1_no_o2 || crew2_no_o2) begin
            is_failed = 1'b1;
            fail_code = FAIL_SUFFOCATION;
        end

        // 3. 정전 판정
        else if (P == 5'd0) begin
            is_failed = 1'b1;
            fail_code = FAIL_BLACKOUT;
        end

        // 4. 발전기 과열 판정
        else if (H >= 4'd12) begin
            is_failed = 1'b1;
            fail_code = FAIL_OVERHEAT;
        end

        // 5. 마지막 시간 단계에서 성공 여부 판정
        else if (time_step == 3'd7) begin

            if (all_safe) begin
                // 두 승무원이 C구역에 도착했고
                // 산소, 전력, 온도 조건도 모두 만족
                is_success = 1'b1;
                fail_code = FAIL_NONE;
            end

            else begin
                // 제한 시간 내 대피하지 못한 경우
                is_failed = 1'b1;
                fail_code = FAIL_ISOLATION;
            end

        end

        // 6. 그 외에는 정상 진행
        else begin
            is_failed = 1'b0;
            is_success = 1'b0;
            fail_code = FAIL_NONE;
        end

    end

endmodule
