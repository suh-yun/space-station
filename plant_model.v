`timescale 1ns / 1ps

module plant_model (
    input  wire       clk,
    input  wire       rst,           // 비동기/동기 리셋 (루프 초기화 겸용)
    input  wire       loop_reset,    // 타임루프 실패 시 초기 상태로 복귀 신호
    input  wire       update_en,     // 1시간 단계 상태 갱신 클록 인에이블 (UPDATE PLANT 단계)

    // 외부 사건 입력 (from event_rom)
    input  wire [3:0] leak_rate,     // L_A(t)
    input  wire [4:0] base_load,     // 기본 전력 소비

    // 실제 실행 승인된 제어 명령 (from Supervisory Check)
    input  wire [1:0] oxygen_cmd,    // S_C(t): 산소 공급량 (0, 1, 2)
    input  wire       generator_cmd, // G_ON: 발전기 가동 (1: ON, 0: OFF)
    input  wire       cooling_cmd,   // C_ON: 냉각장치 가동 (1: ON, 0: OFF)
    input  wire       move_crew1,    // 승무원 1 다음 구역 이동 명령 (1: 이동)
    input  wire       move_crew2,    // 승무원 2 다음 구역 이동 명령 (1: 이동)
    input  wire       door_ab_cmd,   // A-B 격벽 목표 상태 (1: 열림, 0: 닫힘)
    input  wire       door_bc_cmd,   // B-C 격벽 목표 상태 (1: 열림, 0: 닫힘)

    // 현재 우주정거장 상태 레지스터 출력
    output reg  [3:0] O_A,           // A구역 산소 (0~15)
    output reg  [3:0] O_B,           // B구역 산소 (0~15)
    output reg  [3:0] O_C,           // C구역 산소 (0~15)
    output reg  [4:0] P,             // 사용 가능 전력 (0~31)
    output reg  [3:0] H,             // 발전기 온도 (0~15)
    output reg  [1:0] crew1_pos,     // 00:A, 01:B, 10:C
    output reg  [1:0] crew2_pos,     // 00:A, 01:B, 10:C
    output reg        door_AB,       // 0:닫힘, 1:열림
    output reg        door_BC        // 0:닫힘, 1:열림
);

    // 구역 정의 상수
    localparam ZONE_A = 2'b00;
    localparam ZONE_B = 2'b01;
    localparam ZONE_C = 2'b10;

    // 내부 조합 계산용 부호 있는 정수 (오버플로우/언더플로우 클램핑용)
    reg signed [6:0] next_OA, next_OB, next_OC;
    reg signed [7:0] next_P;
    reg signed [6:0] next_H;

    // 승무원 산소 소비량 및 격벽 이동량 계산 변수
    reg [1:0] crew_cons_A, crew_cons_B, crew_cons_C;
    reg signed [2:0] flow_AB, flow_BC;
    reg [4:0] total_power_cons;
    reg [4:0] power_gen;

    always @(*) begin
        // 1. 각 구역별 승무원 산소 소비량 (1명당 1 소비)
        crew_cons_A = (crew1_pos == ZONE_A) + (crew2_pos == ZONE_A);
        crew_cons_B = (crew1_pos == ZONE_B) + (crew2_pos == ZONE_B);
        crew_cons_C = (crew1_pos == ZONE_C) + (crew2_pos == ZONE_C);

        // 2. 격벽 개방 시 산소 이동량 F_i(t) (높은 곳 -> 낮은 곳 1단위 이동)
        // 현재 열려있는 격벽 기준 확산
        if (door_AB) begin
            if (O_A > O_B)      flow_AB = -3'sd1; // A에서 B로 1 이동
            else if (O_B > O_A) flow_AB =  3'sd1; // B에서 A로 1 이동
            else                flow_AB =  3'sd0;
        end else begin
            flow_AB = 3'sd0;
        end

        if (door_BC) begin
            if (O_B > O_C)      flow_BC = -3'sd1; // B에서 C로 1 이동
            else if (O_C > O_B) flow_BC =  3'sd1; // C에서 B로 1 이동
            else                flow_BC =  3'sd0;
        end else begin
            flow_BC = 3'sd0;
        end

        // 3. 다음 산소량 계산: O_i(t+1) = O_i(t) - L_i(t) - C_i(t) + S_i(t) + F_i(t)
        next_OA = $signed({1'b0, O_A}) - $signed({1'b0, leak_rate}) - $signed({1'b0, crew_cons_A}) + flow_AB;
        next_OB = $signed({1'b0, O_B}) - $signed({1'b0, crew_cons_B}) - flow_AB + flow_BC;
        next_OC = $signed({1'b0, O_C}) - $signed({1'b0, crew_cons_C}) + $signed({1'b0, oxygen_cmd}) - flow_BC;

        // 4. 총 전력 소비량 C_total(t) 계산
        // 기본(1) + 이동(각 2) + 산소공급(2, 작동 시) + 냉각(2) + 격벽작동(상태 변경 시 각 1)
        total_power_cons = base_load 
                         + (move_crew1 ? 5'd2 : 5'd0)
                         + (move_crew2 ? 5'd2 : 5'd0)
                         + ((oxygen_cmd != 2'd0) ? 5'd2 : 5'd0)
                         + (cooling_cmd ? 5'd2 : 5'd0)
                         + ((door_ab_cmd != door_AB) ? 5'd1 : 5'd0)
                         + ((door_bc_cmd != door_BC) ? 5'd1 : 5'd0);

        power_gen = generator_cmd ? 5'd5 : 5'd0;
        next_P    = $signed({1'b0, P}) + $signed({1'b0, power_gen}) - $signed({1'b0, total_power_cons});

        // 5. 다음 발전기 온도 계산: H(t+1) = H(t) + 3*G_ON - 4*C_ON - 1
        next_H = $signed({1'b0, H}) 
               + (generator_cmd ? 7'sd3 : 7'sd0) 
               - (cooling_cmd   ? 7'sd4 : 7'sd0) 
               - 7'sd1;
    end

    // 순차 논리: 상태 레지스터 갱신 및 0~15 / 0~31 클램핑
    always @(posedge clk or posedge rst) begin
        if (rst || loop_reset) begin
            // 초기 상태 설정 (팀원과 상의 후 변경 가능)
            O_A       <= 4'd10;
            O_B       <= 4'd10;
            O_C       <= 4'd7;
            P         <= 5'd8;
            H         <= 4'd5;
            crew1_pos <= ZONE_A;
            crew2_pos <= ZONE_B;
            door_AB   <= 1'b0; // 초기 격벽 닫힘
            door_BC   <= 1'b0;
        end else if (update_en) begin
            // 산소 클램핑 (0 ~ 15)
            O_A <= (next_OA < 0) ? 4'd0 : (next_OA > 15) ? 4'd15 : next_OA[3:0];
            O_B <= (next_OB < 0) ? 4'd0 : (next_OB > 15) ? 4'd15 : next_OB[3:0];
            O_C <= (next_OC < 0) ? 4'd0 : (next_OC > 15) ? 4'd15 : next_OC[3:0];

            // 전력 클램핑 (0 ~ 31)
            P   <= (next_P < 0)  ? 5'd0 : (next_P > 31)  ? 5'd31 : next_P[4:0];

            // 온도 클램핑 (0 ~ 15)
            H   <= (next_H < 0)  ? 4'd0 : (next_H > 15)  ? 4'd15 : next_H[3:0];

            // 격벽 상태 갱신
            door_AB <= door_ab_cmd;
            door_BC <= door_bc_cmd;

            // 승무원 1 이동 갱신 (A -> B -> C)
            if (move_crew1) begin
                if (crew1_pos == ZONE_A && door_AB)      crew1_pos <= ZONE_B;
                else if (crew1_pos == ZONE_B && door_BC) crew1_pos <= ZONE_C;
            end

            // 승무원 2 이동 갱신 (A -> B -> C)
            if (move_crew2) begin
                if (crew2_pos == ZONE_A && door_AB)      crew2_pos <= ZONE_B;
                else if (crew2_pos == ZONE_B && door_BC) crew2_pos <= ZONE_C;
            end
        end
    end

endmodule
