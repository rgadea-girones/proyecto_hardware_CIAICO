module Divisor_Alg2

#(parameter tamanyo=32)

			  


(input CLK,
input RSTa,
input Start,
input [tamanyo-1:0] Num,
input [tamanyo-1:0] Den,

output [tamanyo-1:0] Coc,
output [tamanyo-1:0] Res,
output Done);
localparam size_cont=$clog2(tamanyo-1);
enum  logic [2:0] {D0, D1,D2,D3,D4} state1;
logic [tamanyo-1:0] ACCU, M,Q;
logic [size_cont-1 :0] CONT;
logic fin;

always_ff @(posedge CLK or negedge RSTa) 
begin
if(!RSTa)
	begin
      state1<=D0;
      ACCU<='0;
      CONT<='0;
      Q<='0;
      M<='0;
      fin<=1'b0;
	end
else
	case(state1)
	D0: begin
          state1<=D0;
          ACCU<='0;
          CONT<='0;
          Q<='0;
          M<='0;
          fin<=1'b0;
            if (Start) 
              begin
                 ACCU<='0;
                 CONT<=tamanyo-1;
                 Q<=Num;
                 M<=Den;
                 state1 <= D1;
              end
    end
	D1: begin	
            {ACCU,Q}<={ACCU[tamanyo-2:0],Q,1'b0};
            state1 <= D2;
    end
    D2: begin
            CONT<=CONT-1;
            if (ACCU>=M)
            begin
               Q<=Q+1;
               ACCU<=ACCU-M;
            end
            if (CONT=='0) 
            begin
                fin<=1'b1;
                state1 <= D3;
            end
            else 
                state1<=D1;
    end
	D3: begin 

            fin<=1'b0;
            if (!Start) 
                state1 <= D0;

    end

	endcase

end
			assign Done=fin;
            assign Coc=Q;
            assign Res=ACCU;			
endmodule