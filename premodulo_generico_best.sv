`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/26/2024 02:24:15 PM
// Design Name: 
// Module Name: premodulo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module premodulo_best(
    input signed [31:0] A,
    input signed [31:0] B,
    input signed [31:0] C,
    input signed [31:0] D,
    input clk,
    input areset_n,
    input start,
    output logic signed [63:0] SALIDA,
    output logic done
    );

    logic [31:0] A_mag, B_mag, C_mag, D_mag;
    logic  [17:0] A1, A0, B1, B0, C1, C0, D1, D0;
    logic  [35:0] P1, P2, P3, P4, P5, P6, P7, P8;
    logic  [63:0] partial_sum1, partial_sum2, result;
    logic [2:0] state;

    typedef enum logic [2:0] {
        IDLE_SPLIT = 3'b000,
        MULTIPLY = 3'b001,
        ADD1 = 3'b010,
        ADD2 = 3'b011,
        DONE = 3'b100
    } state_t;

    state_t current_state, next_state;

    always_ff @(posedge clk or negedge areset_n) begin
        if (!areset_n) begin
            current_state <= IDLE_SPLIT;
            done <= 0;
            SALIDA <= 0;
        end else begin
            case (current_state)
            IDLE_SPLIT: begin
                if(A[31]) A_mag = ~A + 1; else A_mag = A;
                if(B[31]) B_mag = ~B + 1; else B_mag = B;
                if(C[31]) C_mag = ~C + 1; else C_mag = C;
                if(D[31]) D_mag = ~D + 1; else D_mag = D;
                if (start) begin
                    // Split inputs into 18-bit parts
                    A1 <= A_mag[31:14];
                    A0 <= A_mag[13:0];
                    B1 <= B_mag[31:14];
                    B0 <= B_mag[13:0];
                    C1 <= C_mag[31:14];
                    C0 <= C_mag[13:0];
                    D1 <= D_mag[31:14];
                    D0 <= D_mag[13:0];
                    current_state <= MULTIPLY;
                end else begin
                    current_state <= IDLE_SPLIT;
                end
            end
            MULTIPLY: begin
                // Perform partial multiplications
                P1 <= A0 * B0;
                P2 <= A0 * B1;
                P3 <= A1 * B0;
                P4 <= A1 * B1;
                P5 <= C0 * D0;
                P6 <= C0 * D1;
                P7 <= C1 * D0;
                P8 <= C1 * D1;
                current_state <= ADD1;
            end
            ADD1: begin
                // Combine partial products for A*B
                partial_sum1 <= P1 + (P2 << 14) + (P3 << 14) + (P4 << 28);
                // Combine partial products for C*D
                partial_sum2 <= P5 + (P6 << 14) + (P7 << 14) + (P8 << 28);
                current_state <= ADD2;
            end
            ADD2: begin
                // Final addition
                SALIDA <= partial_sum1 + partial_sum2;
                done <= 1;
                current_state <= DONE;
            end
            DONE: begin
                if (!start) begin
                    done <= 0;
                    current_state <= IDLE_SPLIT;
                end else begin
                    current_state <= DONE;
                end
            end
        endcase
    end

    end



endmodule