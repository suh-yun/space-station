`timescale 1ns / 1ps

module space_station_top (
    input wire clk,
    input wire rst,
    input wire start,
    output wire [15:0] led,
    output wire [7:0] an,
    output wire [6:0] seg,
    output wire dp
);

    // 내부 연결 신호 선언
    wire tick;
    wire [2:0] time_step;
    wire [3:0] loop_count;
    
    wire [3:0] leak_rate;
    wire [4:0] base_load;
    
    wire [1:0] oxygen_cmd;
    wire generator_cmd;
    wire cooling_cmd;
    wire move_crew1;
    wire move_crew2;
    wire door_ab_cmd;
    wire door_bc_cmd;
    
    wire [3:0] O_A, O_B, O_C;
    wire [4:0] P;
    wire [3:0] H;
    wire [1:0] crew1_pos, crew2_pos;
    wire door_AB, door_BC;
    
    wire is_failed, is_success;
    wire [2:0] fail_code;
    wire [2:0] saved_failure_code;
    
    wire plant_step;
    wire supervisor_commit;
    wire loop_reset;
    wire failure_save;
    wire memory_clear;
    
    wire running, done, success;
    
    // 적응형 제어를 위한 파라미터 선언
    wire [3:0] o_ref;
    wire [3:0] h_safe;
    wire [4:0] p_safe;
    wire [4:0] evac_threshold;

    // 1. 1초 클록 생성기 (시뮬레이션 시 DIVISOR를 작게 조절 가능)
    clock_enable #(.DIVISOR(100)) clk_gen (
        .clk(clk),
        .rst(rst),
        .tick(tick)
    );

    // 2. 시간 및 FSM 제어 관리
    time_fsm #(.MAX_LOOPS(4'd3)) u_time_fsm (
        .clk(clk),
        .rst(rst),
        .start(start),
        .tick(tick),
        .is_failed(is_failed),
        .is_success(is_success),
        .fail_code(fail_code),
        .time_step(time_step),
        .loop_count(loop_count),
        .plant_step(plant_step),
        .supervisor_commit(supervisor_commit),
        .loop_reset(loop_reset),
        .failure_save(failure_save),
        .memory_clear(memory_clear),
        .saved_failure_code(saved_failure_code),
        .running(running),
        .done(done),
        .success(success)
    );

    // 3. 외부 환경 (Event ROM)
    event_rom u_event_rom (
        .time_step(time_step),
        .leak_rate(leak_rate),
        .base_load(base_load)
    );

    // 4. 적응형 파라미터 갱신 모듈 (evac_threshold 포트 포함)
    parameter_updater u_param_updater (
        .clk(clk),
        .rst_n(!rst),
        .failure_save(failure_save),
        .failure_code(saved_failure_code),
        .o_ref(o_ref),
        .h_safe(h_safe),
        .p_safe(p_safe),
        .evac_threshold(evac_threshold)
    );

    // 5. 산소 제어기
    oxygen_controller u_o2_ctrl (
        .o_ref(o_ref),
        .o_c(O_C),
        .u_o(oxygen_cmd)
    );

    // 6. 전력 제어기 (발전기 가동 판단)
    power_controller u_pwr_ctrl (
        .p(P),
        .g_on_current(generator_cmd),
        .c_expected(base_load),
        .p_safe(p_safe),
        .g_on(generator_cmd)
    );

    // 7. 관리자 FSM (Supervisory FSM)
    supervisory_fsm u_supervisory_fsm (
        .clk(clk),
        .rst(rst),
        .loop_reset(loop_reset),
        .supervisor_commit(supervisor_commit),
        .crew1_pos(crew1_pos),
        .crew2_pos(crew2_pos),
        .oxygen_a(O_A),
        .oxygen_b(O_B),
        .oxygen_c(O_C),
        .power(P),
        .door_AB(door_AB),
        .door_BC(door_BC),
        .evac_threshold(evac_threshold[3:0]),
        .move_crew1(move_crew1),
        .move_crew2(move_crew2),
        .door_ab_cmd(door_ab_cmd),
        .door_bc_cmd(door_bc_cmd),
        .phase()
    );

    // 냉각장치 가동 조건 (H >= h_safe)
    wire cooling_cmd_sig = (H >= h_safe[3:0]);

    // 8. 우주정거장 본체 물리 엔진 (Plant Model)
    plant_model u_plant_model (
        .clk(clk),
        .rst(rst),
        .loop_reset(loop_reset),
        .update_en(plant_step),
        .leak_rate(leak_rate),
        .base_load(base_load),
        .oxygen_cmd(oxygen_cmd),
        .generator_cmd(generator_cmd),
        .cooling_cmd(cooling_cmd_sig),
        .move_crew1(move_crew1),
        .move_crew2(move_crew2),
        .door_ab_cmd(door_ab_cmd),
        .door_bc_cmd(door_bc_cmd),
        .O_A(O_A),
        .O_B(O_B),
        .O_C(O_C),
        .P(P),
        .H(H),
        .crew1_pos(crew1_pos),
        .crew2_pos(crew2_pos),
        .door_AB(door_AB),
        .door_BC(door_BC)
    );

    // 9. 실패 및 성공 판정기 (Failure Detector)
    failure_detector u_failure_detector (
        .O_A(O_A),
        .O_B(O_B),
        .O_C(O_C),
        .P(P),
        .H(H),
        .crew1_pos(crew1_pos),
        .crew2_pos(crew2_pos),
        .time_step(time_step),
        .is_failed(is_failed),
        .is_success(is_success),
        .fail_code(fail_code)
    );

    // 10. 디스플레이 및 LED 출력 제어기
    display_controller u_display_ctrl (
        .clk(clk),
        .rst(rst),
        .loop_count(loop_count),
        .time_step(time_step),
        .failure_code(fail_code),
        .oxygen_a(O_A),
        .oxygen_b(O_B),
        .oxygen_c(O_C),
        .temperature(H),
        .power(P),
        .crew1_pos(crew1_pos),
        .crew2_pos(crew2_pos),
        .door_ab(door_AB),
        .door_bc(door_BC),
        .generator_on(generator_cmd),
        .cooling_on(cooling_cmd_sig),
        .done(done),
        .success(success),
        .led(led),
        .an(an),
        .seg(seg),
        .dp(dp)
    );

endmodule
