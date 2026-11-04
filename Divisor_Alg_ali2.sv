module Divisor_Alg_ali #(
    parameter tamanyo = 64 ,    
    parameter n_decimales_maximo = 15  
)(
    input logic CLK,
    input logic RSTa,
    input logic Start,
    input logic [tamanyo-1:0] Num,    
    input logic [tamanyo-1:0] Den,    
    // Aumentado a 5 bits para que pueda contener el valor 16 sin hacer overflow
    input logic [3:0] n_decimales, 
   
    output logic [tamanyo-1:0] Coc,
    output logic Done
);

    typedef enum logic [1:0] {IDLE, DIVIDE, FINISH} state_t;
    state_t state;

    logic [tamanyo-1:0] ACCU, M, Q;
    logic [$clog2(tamanyo):0] CONT; // Solo necesita llegar a 64
    
    // Variable auxiliar para el pre-desplazamiento de 128 bits
    logic [2*tamanyo-1:0] num_shifted;

    always_ff @(posedge CLK or negedge RSTa) begin
        if (!RSTa) begin
            state <= IDLE;
            Done <= 0;
            CONT <= '0;
            {ACCU, M, Q, Coc} <= '0;
        end else begin
            case (state)
                IDLE: begin
                    Done <= 0;
                    if (Start) begin
                        // 1. Alineación Matemática para Punto Fijo
                        // Calculamos (Num << n_decimales) en un bus de doble ancho
                        num_shifted = { {tamanyo{1'b0}}, Num } << n_decimales;
                        
                        // Cargamos la parte alta en ACCU y la baja en Q
                        ACCU <= num_shifted[2*tamanyo-1 : tamanyo];
                        Q    <= num_shifted[tamanyo-1 : 0];
                        
                        M    <= Den;
                        CONT <= tamanyo; // Siempre exactamente 64 iteraciones
                        state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    if (CONT == 0) begin
                        state <= FINISH;
                    end else begin
                        // 2. Algoritmo estándar Restoring Division
                        if ({ACCU[tamanyo-2:0], Q[tamanyo-1]} >= M) begin
                            ACCU <= {ACCU[tamanyo-2:0], Q[tamanyo-1]} - M;
                            Q <= {Q[tamanyo-2:0], 1'b1};
                        end else begin
                            ACCU <= {ACCU[tamanyo-2:0], Q[tamanyo-1]};
                            Q <= {Q[tamanyo-2:0], 1'b0};
                        end
                        CONT <= CONT - 1;
                    end
                end

                FINISH: begin
                    Coc <= Q;
                    Done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule