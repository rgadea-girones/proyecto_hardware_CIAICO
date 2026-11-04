module DDS_rafa (
          input [31:0] phi_inc_i,
          input reset_n,
          input clken,
          output logic [13:0] fsin_o,
          output logic [13:0] fcos_o,
          output logic out_valid,
          output logic pulso, //deteccion de cero
          input clk
          );

logic [31:0] accu;
logic valid;
logic [9:0] addr1,addr2;
logic [13:0] q1,q2;

logic positivo,positivo_reg;

assign positivo=addr1[9];

always_ff @(posedge clk , negedge reset_n)
if (!reset_n)

    begin
        pulso<=1'b0;
        positivo_reg<=1'b0;
        accu<='0;
        valid<=1'b0;
        out_valid<=1'b0;
    end
else
    begin
        accu<=accu+phi_inc_i;
        valid<=clken;
        positivo_reg<=positivo;        
        out_valid<=valid;
        fsin_o<=q1;
        fcos_o<=q2;
        if (positivo_reg==1'b0 && positivo==1'b1)
            pulso<=1'b1;
        else begin
            pulso<=1'b0;
        end
    end




	assign addr1=accu[31:22]; //seno
    assign addr2=addr1+256;  //coseno   
//para coseno 
//assign addr=punt_fijo_divid_pi[46]?punt_fijo_divid_pi[45:36]:(1023-punt_fijo_divid_pi[45:36]);  /
memoria_dual_port #(.DATA_WIDTH(14),.ADDR_WIDTH(10), .FICHERO_INICIAL("sin_total1_red.dat"))  my_memory_sin_cos  //forma parte del ciclo 2
						(   
                              .addr1(addr1),
                              .addr2(addr2),
                              .clk(clk),
			                  .enable(1'b1),
                              .q1(q1), //seno
                              .q2(q2)  //coseno
                              );
                            
                         
							
//assign	fsin_o=clken?q1:'0	;
//assign	fcos_o=clken?q2:'0	;							
  
 
endmodule
