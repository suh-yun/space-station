`timescale 1ns / 1ps
module supervisory_fsm (
    input wire clk, rst, loop_reset, supervisor_commit,
    input wire [1:0] crew1_pos, crew2_pos,
    input wire [3:0] oxygen_a, oxygen_b, oxygen_c,
    input wire [4:0] power,
    input wire door_AB, door_BC,
    input wire [3:0] evac_threshold,
    output reg move_crew1, move_crew2,
    output reg door_ab_cmd, door_bc_cmd,
    output reg [2:0] phase
);
    localparam A = 2'd0, B = 2'd1, C = 2'd2;
    localparam MONITOR=3'd0, OPEN_AB=3'd1, EVAC_A=3'd2,
               TRANSFER=3'd3, EVAC_B=3'd4, SAFE=3'd5;
    reg [2:0] next_phase;

    always @(*) begin
        next_phase = phase;
        move_crew1 = 1'b0;
        move_crew2 = 1'b0;
        door_ab_cmd = door_AB;
        door_bc_cmd = door_BC;
        case (phase)
            MONITOR: begin
                if (crew1_pos == A && oxygen_a <= evac_threshold)
                    next_phase = OPEN_AB;
                else if (crew1_pos == B)
                    next_phase = TRANSFER;
                else if (crew1_pos == C)
                    next_phase = EVAC_B;
            end
            OPEN_AB: begin
                if (crew1_pos != A) next_phase = TRANSFER;
                else if (door_AB) next_phase = EVAC_A;
                else if (power >= 5'd2) door_ab_cmd = 1'b1;
            end
            EVAC_A: begin
                if (crew1_pos == B || crew1_pos == C)
                    next_phase = TRANSFER;
                else if (crew1_pos == A && door_AB && oxygen_a != 0
                         && power >= 5'd3)
                    move_crew1 = 1'b1;
                else if (!door_AB) next_phase = OPEN_AB;
            end
            TRANSFER: begin
                // When both doors need switching, reserve at least base load + 2 doors.
                if (door_AB && !door_BC) begin
                    if (power >= 5'd3) begin
                        door_ab_cmd = 1'b0;
                        door_bc_cmd = 1'b1;
                    end else if (power >= 5'd2) begin
                        door_ab_cmd = 1'b0;
                    end
                end else begin
                    if (door_AB && power >= 5'd2) door_ab_cmd = 1'b0;
                    if (!door_BC && power >= 5'd2) door_bc_cmd = 1'b1;
                end
                if (!door_AB && door_BC) next_phase = EVAC_B;
                if (crew1_pos == A) next_phase = OPEN_AB;
            end
            EVAC_B: begin
                if (crew1_pos == C && crew2_pos == C)
                    next_phase = SAFE;
                else if (!door_BC) begin
                    if (power >= 5'd2) door_bc_cmd = 1'b1;
                end else if (oxygen_b != 0) begin
                    // A single move costs 2, two moves cost 4, plus base load 1.
                    if (crew1_pos == B && crew2_pos == B) begin
                        if (power >= 5'd5) begin
                            move_crew1 = 1'b1;
                            move_crew2 = 1'b1;
                        end else if (power >= 5'd3)
                            move_crew1 = 1'b1;
                    end else if (crew1_pos == B && power >= 5'd3)
                        move_crew1 = 1'b1;
                    else if (crew2_pos == B && power >= 5'd3)
                        move_crew2 = 1'b1;
                end
            end
            SAFE: begin
                if (door_BC && power >= 5'd2) door_bc_cmd = 1'b0;
            end
            default: next_phase = MONITOR;
        endcase
    end

    always @(posedge clk) begin
        if (rst || loop_reset) phase <= MONITOR;
        else if (supervisor_commit) phase <= next_phase;
    end
endmodule
