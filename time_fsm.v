
module time_fsm #(parameter [3:0] MAX_LOOPS = 4'd3)
(input wire clk,
 input wire rst,
    input wire start,
    input wire tick,

    input wire [2:0] failure_code,
    input wire all_safe,

    output reg [2:0] time_step,
    output reg [3:0] loop_count,

    output wire plant_step,
    output wire supervisor_commit,
    output wire loop_reset,
    output wire failure_save,

    output wire [2:0] saved_failure_code,
    output wire running,
    output wire done,
    output wire success
);

    localparam IDLE      = 3'd0,
               RESTART   = 3'd1,
               WAIT_TICK = 3'd2,
               APPLY     = 3'd3,
               CHECK     = 3'd4,
               SAVE      = 3'd5,
               ADVANCE   = 3'd6,
               FINISH    = 3'd7;

    reg [2:0] state;
    reg terminal_success;

    reg [2:0] effective_fail;

    // Failure code priority
    always @(*) begin
        if (failure_code == 3'd1)
            effective_fail = 3'd1;
        else if (failure_code == 3'd2)
            effective_fail = 3'd2;
        else if (failure_code == 3'd3)
            effective_fail = 3'd3;
        else if (failure_code == 3'd4)
            effective_fail = 3'd4;
        else if (failure_code == 3'd0) begin
            if (time_step == 3'd7 && !all_safe)
                effective_fail = 3'd5;
            else
                effective_fail = 3'd0;
        end
        else
            effective_fail = 3'd7;
    end

    // Control outputs
    assign plant_step =
        (state == APPLY);

    assign supervisor_commit =
        (state == CHECK);

    assign loop_reset =
        (state == RESTART);

    assign failure_save =
        (state == SAVE);

    assign saved_failure_code = effective_fail;

    assign running =
        (state != IDLE && state != FINISH);

    assign done =
        (state == FINISH);

    assign success =
        (state == FINISH) && terminal_success;

    // State transition
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            time_step <= 3'd0;
            loop_count <= 4'd0;
            terminal_success <= 1'b0;
        end
        else begin
            case (state)

                IDLE: begin
                    if (start) begin
                        loop_count <= 4'd1;
                        time_step <= 3'd0;
                        terminal_success <= 1'b0;
                        state <= RESTART;
                    end
                end

                RESTART: begin
                    state <= WAIT_TICK;
                end

                WAIT_TICK: begin
                    if (tick)
                        state <= APPLY;
                end

                APPLY: begin
                    state <= CHECK;
                end

                CHECK: begin
                    if (effective_fail != 3'd0)
                        state <= SAVE;
                    else if (time_step == 3'd7) begin
                        terminal_success <= 1'b1;
                        state <= FINISH;
                    end
                    else
                        state <= ADVANCE;
                end

                SAVE: begin
                    if (loop_count >= MAX_LOOPS) begin
                        terminal_success <= 1'b0;
                        state <= FINISH;
                    end
                    else begin
                        loop_count <= loop_count + 1'b1;
                        time_step <= 3'd0;
                        state <= RESTART;
                    end
                end

                ADVANCE: begin
                    time_step <= time_step + 1'b1;
                    state <= WAIT_TICK;
                end

                FINISH: begin
                    if (start) begin
                        loop_count <= 4'd1;
                        time_step <= 3'd0;
                        terminal_success <= 1'b0;
                        state <= RESTART;
                    end
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
