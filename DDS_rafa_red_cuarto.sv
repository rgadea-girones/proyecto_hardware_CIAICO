module DDS_rafa_cuarto (
          input [31:0] phi_inc_i,
          input reset_n,
          output reg signed [13:0] fsin_o,
          output reg signed [13:0] fcos_o,
          output reg pulso, //deteccion de cero
          input clk
          );

reg [31:0] accu;
wire [9:0] addr1,addr2;
wire [13:0] q1,q2;
wire signed [14:0] q1_signed,q2_signed;
reg signed [13:0] fsin,fcos;
reg [1:0] selector;

localparam uno=2'b00, dos=2'b01, tres=2'b10, cuatro=2'b11;



assign q1_signed={1'b0,q1};
assign q2_signed={1'b0,q2};

always  @(posedge clk , negedge reset_n)
if (!reset_n)
begin
    fsin<=14'b0;
    fcos<=14'b0;
    selector<=0;

end
else
    begin
        selector<=accu[31:30];
    case (selector)
        uno: begin
            fsin=q1_signed[14:1];
            fcos=q2_signed[14:1];
        end
        dos: begin
            fsin=q2_signed[14:1];
            fcos=-q1_signed[14:1];
        end
        tres: begin
            fsin=-q1_signed[14:1];
            fcos=-q2_signed[14:1];
        end
        cuatro: begin
            fsin=-q2_signed[14:1];
            fcos=q1_signed[14:1];
        end
    endcase
    end

//generación de detector de paso por cero y registro de señales generadas
wire positivo;
reg positivo_reg;
assign positivo=accu[31] ;

always @(posedge clk , negedge reset_n)
if (!reset_n)

    begin
        pulso<=1'b0;
        positivo_reg<=1'b0;
        fsin_o<='0;
        fcos_o<='0;
    end
else
    begin
        positivo_reg<=positivo;        
        fsin_o<=fsin;
        fcos_o<=fcos;
        if (positivo_reg==1'b0 && positivo==1'b1)
            pulso<=1'b1;
        else begin
            pulso<=1'b0;
        end
    end

//acumulador
always @(posedge clk , negedge reset_n)
if (!reset_n)

        accu<=0;
else
        accu<=accu+phi_inc_i;



assign addr1=accu[29:20]; //seno
assign addr2=1023-addr1;  //coseno   

memoria_dual_port #(.DATA_WIDTH(14),.ADDR_WIDTH(10), .FICHERO_INICIAL("sin_cuarto_2e10x14.dat"))  my_memory_sin_cos  //forma parte del ciclo 2
						(   
                              .addr1(addr1),
                              .addr2(addr2),
                              .clk(clk),
			                  .enable(1'b1),
                              .q1(q1), //seno
                              .q2(q2)  //coseno
                              );
                            

endmodule
