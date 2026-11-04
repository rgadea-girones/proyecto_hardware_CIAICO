module arctan2

#(parameter tamanyo=32)

			  


(input CLK,
input RSTa,
input Start,
input [tamanyo-1:0] Num,
input [tamanyo-1:0] Den,

output [tamanyo-1:0] Coc,
output [31:0] Arctan2,
output Done);
localparam size_cont=$clog2(tamanyo-1);
enum  logic [2:0] {D0, D1,D2,D3,D4} state1;
logic [tamanyo-1:0] ACCU, M,Q;
logic [size_cont-1 :0] CONT;
logic fin;
logic [tamanyo-1:0] magnitud_num,magnitud_den;
logic signo;
logic [7:0] tabla;
logic [tamanyo-1:0] magnitud_arctan2;


assign signo=Num[tamanyo-1]^Den[tamanyo-1];
assign magnitud_num=Num[tamanyo-1]?~(Num<<6)+1:(Num<<6);
assign magnitud_den=Den[tamanyo-1]?~(Den)+1:Den; 
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
                 Q<=magnitud_num;
                 M<=magnitud_den;
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

        //    assign Res=ACCU;
            
assign magnitud_arctan2=(Coc[tamanyo-1:14]=='0)?{24'h0000,tabla}:32'd180;
assign Arctan2=signo?  ~(magnitud_arctan2)+1: magnitud_arctan2;         
memoria_single_port_mejorado #(.DATA_WIDTH(8),.ADDR_WIDTH(14),
.punto_entrada(6),.punto_salida(1))  arco_tangente1
(.clk(CLK),
.addr(Coc[13:0]), 
.q(tabla));

logic aux_shifter;
always_ff @(posedge CLK or negedge RSTa) 
    if(!RSTa)
        aux_shifter<='0;
    else 
        aux_shifter<=fin;

assign Done=aux_shifter;
assign Coc=Q;        
        

endmodule