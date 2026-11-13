`timescale 1ns / 1ps

module failure_detector (
    input  wire [3:0] O_A,
    input  wire [3:0] O_B,
    input  wire [3:0] O_C,
    input  wire [4:0] P,
    input  wire [3:0] H,
    input  wire [1:0] crew1_pos,
    input  wire [1:0] crew2_pos,
    input  wire [2:0] time_step,

    output reg        is_failed,    // 1이면 실패 발생
    output reg        is_success,   // 1이면 8시간 생존 및 대피 성공
    output reg  [2:0] fail_code     // 실패 원인 코드 (loop_memory / parameter_updater 전달)
);

    localparam ZONE_A = 2'b00;
    localparam ZONE_B = 2'b01;
    localparam ZONE_C = 2'b10;

    localparam FAIL_NONE        = 3'b000;
    localparam FAIL_SUFFOCATION = 3'b001; // 질식
    localparam FAIL_BLACKOUT    = 3'b010; // 정전
    localparam FAIL_OVERHEAT    = 3'b011; // 과열
    localparam FAIL_ISOLATION   = 3'b100; // 고립 (시간 초과)

    wire crew1_no_o2 = ((crew1_pos == ZONE_A) && (O_A == 4'd0)) ||
                       ((crew1_pos == ZONE_B) && (O_B == 4'd0)) ||
                       ((crew1_pos == ZONE_C) && (O_C == 4'd0));

    wire crew2_no_o2 = ((crew2_pos == ZONE_A) && (O_A == 4'd0)) ||
                       ((crew2_pos == ZONE_B) && (O_B == 4'd0)) ||
                       ((crew2_pos == ZONE_C) && (O_C == 4'd0));

    always @(*) begin
        is_failed  = 1'b0;
        is_success = 1'b0;
        fail_code  = FAIL_NONE;

        // 1. 질식 판정 (승무원이 위치한 구역 산소 고갈)
        if (crew1_no_o2 || crew2_no_o2) begin
            is_failed = 1'b1;
            fail_code = FAIL_SUFFOCATION;
        end
        // 2. 전력 부족 (정전) 판정
        else if (P == 5'd0) begin
            is_failed = 1'b1;
            fail_code = FAIL_BLACKOUT;
        end
        // 3. 발전기 과열 판정 (온도 12 이상)
        else if (H >= 4'd12) begin
            is_failed = 1'b1;
            fail_code = FAIL_OVERHEAT;
        end
        // 4. 최종 시간(time_step == 7) 도달 시 대피 완료 여부 판정
        else if (time_step == 3'd7) begin
            if ((crew1_pos == ZONE_C) && (crew2_pos == ZONE_C)) begin
                is_success = 1'b1; // 전원 C구역 도착 및 생존 성공!
            end else begin
                is_failed  = 1'b1;
                fail_code  = FAIL_ISOLATION; // 시간 내 대피 실패(고립)
            end
        end
    end

endmodule
