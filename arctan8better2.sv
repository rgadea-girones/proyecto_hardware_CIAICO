module arctan8better
#(
    parameter tamanyo=32,
    parameter bit INVERTIR_SIGNOS = 0
)
(
    input CLK,
    input RSTa,
    input Start,
    input [tamanyo-1:0] Num,
    input [tamanyo-1:0] Den,
    output [tamanyo-1:0] Coc,
    output logic [31:0] Arctan2,
    output Done
);

    localparam size_cont=$clog2(tamanyo-1);
    enum  logic [2:0] {D0, D1,D2,D3,D4} state1;
    logic [tamanyo-1:0] ACCU, M, Q;
    logic [size_cont-1 :0] CONT;
    logic fin;
    logic [tamanyo-1:0] magnitud_num, magnitud_den;
    logic [9:0] tabla;
    logic [tamanyo-1:0] magnitud_arctan2;

    // --- Compensación opcional de inversión de signos ---
    logic [tamanyo-1:0] Num_eff;
    logic [tamanyo-1:0] Den_eff;
    
    assign Num_eff = INVERTIR_SIGNOS ? (~Num + 1'b1) : Num;
    assign Den_eff = INVERTIR_SIGNOS ? (~Den + 1'b1) : Den;

    // --- CAMBIO ROBUSTO: Registro de signos originales ---
    logic signo_Num_latched, signo_Den_latched;

    always_ff @(posedge CLK or negedge RSTa) begin
        if (!RSTa) begin
            signo_Num_latched <= 1'b0;
            signo_Den_latched <= 1'b0;
        end else if (Start) begin
            signo_Num_latched <= Num_eff[tamanyo-1];
            signo_Den_latched <= Den_eff[tamanyo-1];
        end
    end

    // --- Lógica original de magnitudes ---
    assign magnitud_num = Num_eff[tamanyo-1] ? (~(Num_eff<<6)+1) : (Num_eff<<6);
    assign magnitud_den = Den_eff[tamanyo-1] ? (~(Den_eff)+1) : Den_eff; 

always_ff @(posedge CLK or negedge RSTa) begin
    if(!RSTa) begin
        state1 <= D0;
        ACCU <= '0;
        CONT <= '0;
        Q <= '0;
        M <= '0;
        fin <= 1'b0;
    end else begin
        case(state1)
            D0: begin
                state1 <= D0;
                ACCU <= '0;
                CONT <= '0;
                Q <= '0;
                M <= '0;
                fin <= 1'b0;
                if (Start) begin
                    ACCU <= '0;
                    CONT <= tamanyo-1;
                    Q <= magnitud_num;
                    M <= magnitud_den;
                    state1 <= D1;
                end
            end
            D1: begin	
                {ACCU, Q} <= {ACCU[tamanyo-2:0], Q, 1'b0};
                state1 <= D2;
            end
            D2: begin
                CONT <= CONT-1;
                if (ACCU >= M) begin
                    Q <= Q + 1;
                    ACCU <= ACCU - M;
                end
                if (CONT == '0) begin
                    fin <= 1'b1;
                    state1 <= D3;
                end else 
                    state1 <= D1;
            end
            D3: begin 
                fin <= 1'b0;
                if (!Start) state1 <= D0;
            end
        endcase
    end
end
// --- NUEVA LÓGICA DE SATURACIÓN PARA EL COCIENTE ---
// Evitamos que la LUT reciba valores fuera de rango que causen el salto brusco
logic [13:0] cociente_saturado;
assign cociente_saturado = (Q[tamanyo-1:14] != 0) ? 14'h3FFF : Q[13:0];
// --- Lógica de la tabla (sin cambios) ---
memoria_single_port_mejorado #(.DATA_WIDTH(10), .ADDR_WIDTH(14),
    .punto_entrada(6), .punto_salida(3)) arco_tangente1
    (.clk(CLK), .addr(cociente_saturado), .q(tabla));


assign magnitud_arctan2= {22'h0, tabla};
// --- CAMBIO ROBUSTO: Reconstrucción de cuadrantes ---
// En lugar de XOR simple, usamos los signos latcheados para reconstruir el ángulo completo
always_comb begin
    case ({signo_Den_latched, signo_Num_latched})
        2'b00: Arctan2 = $signed(magnitud_arctan2);           // Q1 (+,+)
        2'b01: Arctan2 = -$signed(magnitud_arctan2);          // Q4 (+,-)
        2'b10: Arctan2 = $signed(32'd1440) - $signed(magnitud_arctan2); // Q2 (-,+)
        2'b11: Arctan2 = -$signed(32'd1440) + $signed(magnitud_arctan2); // Q3 (-,-)
        default: Arctan2 = 0;
    endcase
end

logic aux_shifter;
always_ff @(posedge CLK or negedge RSTa) 
    if(!RSTa) aux_shifter <= '0;
    else aux_shifter <= fin;

assign Done = aux_shifter;
assign Coc = Q;        

endmodule