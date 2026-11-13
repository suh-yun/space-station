`timescale 1ns/1ns

module tb_feedback_adaptive_control;

    // --- Signals for Oxygen Controller ---
    reg  [3:0] tb_o_ref;
    reg  [3:0] tb_o_c;
    wire [1:0] tb_u_o;

    // --- Signals for Power Controller ---
    reg  [4:0] tb_p;
    reg        tb_g_on_current;
    reg  [4:0] tb_c_expected;
    reg  [4:0] tb_p_safe;
    wire       tb_g_on;

    // --- Signals for Thermal Controller ---
    reg  [3:0] tb_h;
    reg        tb_h_g_on;
    reg  [3:0] tb_h_safe;
    wire       tb_u_c;

    // --- Signals for Parameter Updater ---
    reg        tb_clk;
    reg        tb_rst_n;
    reg        tb_sim_done;
    reg        tb_sim_fail;
    reg  [2:0] tb_failure_code;
    wire [3:0] updated_o_ref;
    wire [3:0] updated_h_safe;
    wire [4:0] updated_p_safe;

    // -------------------------------------------------------------
    // Module Instantiations (DUT)
    // -------------------------------------------------------------
    oxygen_controller u_oxy (
        .o_ref(tb_o_ref),
        .o_c(tb_o_c),
        .u_o(tb_u_o)
    );

    power_controller u_pwr (
        .p(tb_p),
        .g_on_current(tb_g_on_current),
        .c_expected(tb_c_expected),
        .p_safe(tb_p_safe),
        .g_on(tb_g_on)
    );

    thermal_controller u_thm (
        .h(tb_h),
        .g_on(tb_h_g_on),
        .h_safe(tb_h_safe),
        .u_c(tb_u_c)
    );

    parameter_updater u_updater (
        .clk(tb_clk),
        .rst_n(tb_rst_n),
        .sim_done(tb_sim_done),
        .sim_fail(tb_sim_fail),
        .failure_code(tb_failure_code),
        .o_ref(updated_o_ref),
        .h_safe(updated_h_safe),
        .p_safe(updated_p_safe)
    );

    // -------------------------------------------------------------
    // Clock Generation (10ns period)
    // -------------------------------------------------------------
    always #5 tb_clk = ~tb_clk;

    // -------------------------------------------------------------
    // Test Stimulus & Verification
    // -------------------------------------------------------------
    initial begin
        // Waveform dump setup
        $dumpfile("tb_feedback_adaptive_control.vcd");
        $dumpvars(0, tb_feedback_adaptive_control);

        // Initialize signals
        tb_clk          = 0;
        tb_rst_n        = 0;
        tb_o_ref        = 4'd8;
        tb_o_c          = 4'd8;
        tb_p            = 5'd10;
        tb_g_on_current = 0;
        tb_c_expected   = 5'd3;
        tb_p_safe       = 5'd6;
        tb_h            = 4'd4;
        tb_h_g_on       = 0;
        tb_h_safe       = 4'd8;
        tb_sim_done     = 0;
        tb_sim_fail     = 0;
        tb_failure_code = 3'd0;

        // Reset release
        #12 tb_rst_n = 1;
        #20;

        // --- 1. Test Oxygen Controller ---
        $display("=== [Test 1] Oxygen Controller Test ==->");
        tb_o_ref = 4'd8;
        tb_o_c   = 4'd7; #10; // 오차 1 (0 < e < 4) -> u_o = 1 기대
        tb_o_c   = 4'd3; #10; // 오차 5 (e >= 4)  -> u_o = 2 기대
        tb_o_c   = 4'd9; #10; // 오차 -1 (e <= 0) -> u_o = 0 기대

        // --- 2. Test Power Controller ---
        $display("=== [Test 2] Power Controller Test ==->");
        tb_p          = 5'd8;
        tb_c_expected = 5'd4;
        tb_p_safe     = 5'd6;
        tb_g_on_current = 0; #10; // 예측 전력 = 8 + 0 - 4 = 4 (< p_safe 6) -> g_on = 1 기대
        
        tb_p          = 5'd10;
        tb_c_expected = 5'd3;
        tb_p_safe     = 5'd6; #10; // 예측 전력 = 10 + 0 - 3 = 7 (>= p_safe 6) -> g_on = 0 기대

        // --- 3. Test Thermal Controller ---
        $display("=== [Test 3] Thermal Controller Test ==->");
        tb_h      = 4'd7;
        tb_h_safe = 4'd8;
        tb_h_g_on = 1; #10; // 예측 온도 = 7 + 3 - 1 = 9 (>= h_safe 8) -> u_c = 1 기대
        
        tb_h      = 4'd4;
        tb_h_g_on = 0; #10; // 예측 온도 = 4 + 0 - 1 = 3 (< h_safe 8)  -> u_c = 0 기대

        // --- 4. Test Parameter Updater (Outer Loop) ---
        $display("=== [Test 4] Parameter Updater (Outer Loop) Test ==->");
        // 초기값 확인 (o_ref: 8, h_safe: 8, p_safe: 5)
        
        // 4-1. 질식 실패 발생 (failure_code = 1) -> o_ref 증가 확인
        @(posedge tb_clk);
        tb_sim_done     = 1;
        tb_sim_fail     = 1;
        tb_failure_code = 3'd1; 
        @(posedge tb_clk);
        tb_sim_done     = 0;
        tb_sim_fail     = 0;
        #10;

        // 4-2. 과열 실패 발생 (failure_code = 2) -> h_safe 감소 확인
        @(posedge tb_clk);
        tb_sim_done     = 1;
        tb_sim_fail     = 1;
        tb_failure_code = 3'd2; 
        @(posedge tb_clk);
        tb_sim_done     = 0;
        tb_sim_fail     = 0;
        #10;

        // 4-3. 정전 실패 발생 (failure_code = 3) -> p_safe 증가 확인
        @(posedge tb_clk);
        tb_sim_done     = 1;
        tb_sim_fail     = 1;
        tb_failure_code = 3'd3; 
        @(posedge tb_clk);
        tb_sim_done     = 0;
        tb_sim_fail     = 0;
        #20;

        $display("=== All Unit Tests Completed ==->");
        $finish;
    end

endmodule