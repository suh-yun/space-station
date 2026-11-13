`timescale 1ns / 1ps
module parameter_updater (
    input wire clk,
    input wire rst_n,
    input wire failure_save,
    input wire [2:0] failure_code,
    output reg [3:0] o_ref,
    output reg [3:0] h_safe,
    output reg [4:0] p_safe,
    output reg [3:0] evac_threshold
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_ref <= 4'd8;
            h_safe <= 4'd8;
            p_safe <= 5'd5;
            // Start evacuation early enough to move crew1 out of A.
            evac_threshold <= 4'd10;
        end else if (failure_save) begin
            case (failure_code)
                3'd1: if (o_ref < 4'd15) o_ref <= o_ref + 1'b1;
                3'd2: if (p_safe < 5'd31) p_safe <= p_safe + 1'b1;
                3'd3: if (h_safe > 4'd1) h_safe <= h_safe - 1'b1;
                3'd4: if (evac_threshold < 4'd15)
                           evac_threshold <= evac_threshold + 1'b1;
                default: ; // 7: internal error, no adaptation
            endcase
        end
    end
endmodule

