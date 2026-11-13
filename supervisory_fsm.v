
module supervisory_fsm(
    input wire clk,
    input wire rst,
    input wire loop_reset,
    input wire supervisor_commit,

    input wire [1:0] crew1_pos,
    input wire [1:0] crew2_pos,

    input wire [3:0] oxygen_a,
    input wire [3:0] oxygen_b,
    input wire [3:0] oxygen_c,

    input wire [4:0] power,

    input wire door_ab,
    input wire door_bc,

    input wire [3:0] evac_threshold,

    output reg [1:0] move_cmd,
    output reg [1:0] close_cmd,
    output reg [2:0] phase
);

    localparam MONITOR = 3'd0,
               EVAC_A  = 3'd1,
               SEAL_A  = 3'd2,
               EVAC_B  = 3'd3,
               SAFE    = 3'd4;

    reg [2:0] next_phase;

    // Combinational logic
    always @(*) begin

        next_phase = phase;
        move_cmd = 2'b00;
        close_cmd = 2'b00;

        case (phase)

            MONITOR: begin
                if (crew1_pos == 2'd0) begin
                    if (oxygen_a <= evac_threshold)
                        next_phase = EVAC_A;
                end
                else if (crew1_pos == 2'd1 ||
                         crew1_pos == 2'd2) begin
                    next_phase = SEAL_A;
                end
                else begin
                    next_phase = MONITOR;
                end
            end

            EVAC_A: begin
                if (crew1_pos == 2'd1) begin
                    next_phase = SEAL_A;
                end
                else if (crew1_pos == 2'd0) begin
                    if (!door_ab &&
                        oxygen_a > 4'd2 &&
                        power >= 5'd3)
                        move_cmd = 2'b01;
                end
                else begin
                    next_phase = MONITOR;
                end
            end

            SEAL_A: begin
                if (crew1_pos == 2'd0) begin
                    next_phase = EVAC_A;
                end
                else if (door_ab) begin
                    next_phase = EVAC_B;
                end
                else if (power >= 5'd2) begin
                    close_cmd[0] = 1'b1;
                end
            end

            EVAC_B: begin
                if (crew1_pos == 2'd2 &&
                    crew2_pos == 2'd2) begin
                    next_phase = SAFE;
                end

                else if (!door_bc &&
                         oxygen_b > 4'd2 &&
                         power >= 5'd3) begin

                    if (crew1_pos == 2'd1)
                        move_cmd = 2'b01;

                    else if (crew1_pos == 2'd2 &&
                             crew2_pos == 2'd1)
                        move_cmd = 2'b10;
                end
            end

            SAFE: begin
                if (crew1_pos == 2'd2 &&
                    crew2_pos == 2'd2 &&
                    !door_bc &&
                    power >= 5'd2)
                    close_cmd[1] = 1'b1;
            end

            default: begin
                next_phase = MONITOR;
            end

        endcase
    end

    // Sequential state update
    always @(posedge clk) begin
        if (rst)
            phase <= MONITOR;
        else if (loop_reset)
            phase <= MONITOR;
        else if (supervisor_commit)
            phase <= next_phase;
    end

endmodule
