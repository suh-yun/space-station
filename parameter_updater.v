module parameter_updater (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sim_done,     // 시뮬레이션 종료 신호
    input  wire        sim_fail,     // 실패 발생 여부 신호
    input  wire [2:0]  failure_code, // 실패 원인 코드 (1:질식, 2:과열, 3:정전)
    output reg  [3:0]  o_ref,        // 갱신된 목표 산소량
    output reg  [3:0]  h_safe,       // 갱신된 냉각 기준 온도
    output reg  [4:0]  p_safe        // 갱신된 안전 전력 기준
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 초기 기본 기준값 설정
            o_ref  <= 4'd8;
            h_safe <= 4'd8;
            p_safe <= 5'd5;
        end else if (sim_done && sim_fail) begin
            // 실패 원인에 따른 적응형 파라미터 보정 (Outer Loop Rule)
            
            case (failure_code)
                3'd1: begin // 질식 발생 (FAIL_SUFFOCATION) -> 목표 산소량 상향
                        if (o_ref < 4'd15) o_ref <= o_ref + 1'b1;
                      end
                3'd2: begin // 정전 발생 (FAIL_BLACKOUT) -> 안전 전력 기준 상향
                         p_safe <= p_safe + 1'b1;
                      end
                3'd3: begin // 과열 발생 (FAIL_OVERHEAT) -> 냉각 기준 온도 하향
                        if (h_safe > 4'd1) h_safe <= h_safe - 1'b1;
                      end
                3'd4: begin // 고립 발생 (FAIL_ISOLATION) -> 대피 임계값 조정 등 필요 시 추가
                       if (evac_threshold < 4'd15) evac_threshold <= evac_threshold + 1'b1;
                      end
                default: ;
            endcase
        end
    end

endmodule
