module Control_path_best_rafa_mejora_correlacion_autoshunt_4p_mejorado

  #(parameter DATA_WIDTH=32, parameter ADDR_WIDTH=8, parameter MAGNITUD_WIDTH=14, parameter pancho_detector=10, parameter pciclos=4, parameter FICHERO_INICIAL="freq_log_ideal.dat", parameter shunt=1000)
   (input clk125,
    input clk65,
    input areset_n,
    input start,
    input test1,
    input test2,
    input test3,
    input [7:0] salto,
    input [8:0] numero_rep,
    input [9:0] num_ciclos,
    input [9:0] numero_anchura,
    input [3:0] n_decimales,
    input logic signed [MAGNITUD_WIDTH-1:0] ADC_A,
    input logic signed [MAGNITUD_WIDTH-1:0] ADC_B,
    input logic signed [MAGNITUD_WIDTH-1:0] ADC_C,
    input wren_sys,
    input [8:0] address_wr_sys,
    input [DATA_WIDTH-1:0]  data_write_sys,
    output logic [DATA_WIDTH-1:0] data_read_sys, //borrar al terminar debug
    output logic fin,
    output logic fin2,
    output logic VALID_M,
    output logic VALID_P,
    
    output logic [DATA_WIDTH-1:0] incrementado,
    output logic signed [MAGNITUD_WIDTH-1:0] DAC_S_registrado,
    output logic signed[31:0] MODULO,

    output logic [8:0] address_mem,
    output logic [8:0] address_mem2,
    output logic [8:0] address_mem3,    

    output logic [2:0] estado_pasos_cero,
    output logic [31:0] MODULOA,MODULOB,
    output logic signed [31:0] PHASE,
    output logic signed [31:0] PHASEA,
    output logic signed [31:0] PHASEB
   );
   localparam relleno=DATA_WIDTH*2-MAGNITUD_WIDTH*2;
   parameter G0=3'b000, G1=3'b001,  G2=3'b010, G2B=3'b101, G3=3'b011, G3B=3'b100, G4=3'b110 ;
   parameter S0=3'b000, S1=3'b001, S4=3'b100,  S3=3'b011;

  localparam EXTENSION=DATA_WIDTH-MAGNITUD_WIDTH;
  logic signed [MAGNITUD_WIDTH-1:0] DAC_A;
  logic signed [MAGNITUD_WIDTH-1:0] DAC_A_cos;
  logic signed [DATA_WIDTH-1:0] DAC_A_ext;
  logic signed [DATA_WIDTH-1:0] DAC_A_cos_ext;
   //generacion
  logic detectado_cero_S;

  logic [7:0] address_mem3_a1,address_mem3_a2;
  logic signed [MAGNITUD_WIDTH-1:0] diferencia;
  // enum  logic [2:0] {G0, G1,G1B, G2,G3} state1;

  // enum logic [2:0] {S0 , S1,  S3,S4} state2;
  
  logic [2:0] state1;

  logic [2:0] state2;
 // logic detectado_cero_S, detectado_cero_Snormal,detectado_cero_Stest;
  logic detectado_cero_S_reg, detectado_cero_S_reg2,detectado_cero_S_reg3,detectado_cero_S_reg4;

  //logic [7:0] address_mem;
  logic [9:0] contador_5_ciclos;
  logic [9:0] ciclos;
  logic [8:0] repeticiones;
  logic [15:0] ancho_detector;
  logic [7:0] paso;
  logic [15:0] anchura_variable;
  
  
  //assign anchura_variable=address_mem<salto?250:(address_mem>numero_anchura?10:30);
  
  //assign ciclos=(incrementado<32'h00eeb476)?0:(incrementado<32'h0176d603)?1:(incrementado<32'h02004b62)?2:3;
assign diferencia=ADC_A-ADC_B;
  assign ciclos=num_ciclos;
  assign repeticiones=test3?numero_rep:225; //numero de puntos que tenemos
  //assign ancho_detector=test3?anchura_variable:pancho_detector;
  // assign ancho_detector=pancho_detector;
  //assign paso=test3?{{5{1'b0}},salto}:8'b00000001;
  // assign paso=1;
  assign paso=8'b00000001;

  //logic [31:0] phase_accumulator;
  logic ovalid;



  localparam [MAGNITUD_WIDTH-1:0] cero_magnitud='0;
  localparam tamanyo_shifter=1;
  logic [MAGNITUD_WIDTH-1:0] auxA;
  logic [MAGNITUD_WIDTH-1:0] auxB;
  logic [MAGNITUD_WIDTH-1:0] auxS;
  
  logic signed [MAGNITUD_WIDTH-1:0] ADC_A_registrado;
  logic signed [MAGNITUD_WIDTH-1:0] ADC_B_registrado;
  logic signed [MAGNITUD_WIDTH-1:0] ADC_C_registrado;
  logic signed [MAGNITUD_WIDTH-1:0] ADC_AminusB_registrado;
   //empezamos cosas nuevas
  //esto es un cambio
  logic signed [MAGNITUD_WIDTH*2-1:0] A_proyeccion_0_prod;
  logic signed [MAGNITUD_WIDTH*2-1:0] A_proyeccion_1_prod;
  logic signed [MAGNITUD_WIDTH*2-1:0] B_proyeccion_0_prod;
  logic signed [MAGNITUD_WIDTH*2-1:0] B_proyeccion_1_prod;

  logic signed [63:0] A_proyeccion_0, A_proyeccion_0_reg, A_proyeccion_0_reg2;
  logic signed [63:0] A_proyeccion_1, A_proyeccion_1_reg, A_proyeccion_1_reg2;
  logic signed [63:0] B_proyeccion_0, B_proyeccion_0_reg,  B_proyeccion_0_reg2;
  logic signed [63:0] B_proyeccion_1,  B_proyeccion_1_reg, B_proyeccion_1_reg2;
  
  logic signed [63:0] A_proyeccion_0_def;
  logic signed [63:0] A_proyeccion_1_def;
  logic signed [63:0] B_proyeccion_0_def;
  logic signed [63:0] B_proyeccion_1_def; 


  
  logic signed[63:0] pre2MODULOA1,pre2MODULOA2,pre2MODULOA;
  logic signed[63:0] pre2MODULOB1,pre2MODULOB2,pre2MODULOB;


   logic signed [31:0] PHASEA_def;
   logic signed [31:0] PHASEB_def;
   

  logic signed[63:0] preMODULOA;
  logic signed[63:0] preMODULOB;


  logic [31:0] moduloA_ampliado;
  

  //vamos a cortar el path desde la entrada: este es el segundo cambio
  always_ff @(posedge clk125 or negedge areset_n)
  begin
    if(!areset_n)
    begin
        ADC_A_registrado<='0;
        ADC_B_registrado<='0;
        ADC_AminusB_registrado<='0;
     end
     else
         begin
        ADC_A_registrado<=ADC_A;
        ADC_B_registrado<=ADC_B;
        ADC_C_registrado<=ADC_C;
        ADC_AminusB_registrado<=ADC_A-ADC_B;
     end
   end



  always_ff @(posedge clk125 or negedge areset_n)
  begin
    if(!areset_n)
    begin
      address_mem<=0;  //cambiado para verificacion hardware
      contador_5_ciclos<='0;
      state1<=G0;
      fin<=1'b0;
      fin2<=1'b0;
      A_proyeccion_0<='0;
      A_proyeccion_1<='0;
      B_proyeccion_0<='0;
      B_proyeccion_1<='0;
      A_proyeccion_0_reg<='0;
      A_proyeccion_1_reg<='0;
      B_proyeccion_0_reg<='0;
      B_proyeccion_1_reg<='0; 
      A_proyeccion_0_reg2<='0;
      A_proyeccion_1_reg2<='0;
      B_proyeccion_0_reg2<='0;
      B_proyeccion_1_reg2<='0;                    
      A_proyeccion_0_prod<='0;
      A_proyeccion_1_prod<='0;
      B_proyeccion_0_prod<='0;
      B_proyeccion_1_prod<='0;
      /*
      pre2MODULOA1<='0;
      pre2MODULOA2<='0;
      pre2MODULOA<='0;
      pre2MODULOB1<='0;
      pre2MODULOB2<='0;
      pre2MODULOB<='0;
      */
      A_proyeccion_0_def<='0;
      A_proyeccion_1_def<='0;
      B_proyeccion_0_def<='0;
      B_proyeccion_1_def<='0;        
    end
    else
    case(state1)
      G0:
      begin
        fin<=1'b0;
        fin2<=1'b0;

        if (start)
        begin
          address_mem<=0; 
          state1 <= G1;
        end

      end
      G1:
   //     if (ovalid)
          state1<=G2B;
      G2B:
      if (detectado_cero_S==1'b1)
          state1<=G2;

      G2:
      begin
        if (detectado_cero_S==1'b1)
          if (contador_5_ciclos==ciclos+1)
          begin 
            contador_5_ciclos<='0;
            if (address_mem<repeticiones-1)
              address_mem<=address_mem+1;
            else
              begin
              state1<=G3B;
              address_mem<=address_mem+1;            
              end        
          end
          else
            begin
            contador_5_ciclos<=contador_5_ciclos+1;
            A_proyeccion_0<='0;
            A_proyeccion_1<='0;
            B_proyeccion_0<='0;
            B_proyeccion_1<='0;
            A_proyeccion_0_reg<='0;
            A_proyeccion_1_reg<='0;
            B_proyeccion_0_reg<='0;
            B_proyeccion_1_reg<='0; 
            A_proyeccion_0_reg2<='0;
            A_proyeccion_1_reg2<='0;
            B_proyeccion_0_reg2<='0;
            B_proyeccion_1_reg2<='0;                    
            A_proyeccion_0_prod<='0;
            A_proyeccion_1_prod<='0;
            B_proyeccion_0_prod<='0;
            B_proyeccion_1_prod<='0;
/*            
            pre2MODULOA1<='0;
            pre2MODULOA2<='0;
            pre2MODULOA<='0;
            pre2MODULOB1<='0;
            pre2MODULOB2<='0;
            pre2MODULOB<='0;  
            */          
            end
        if (contador_5_ciclos>=numero_anchura)
        begin
          A_proyeccion_0_prod<=(ADC_AminusB_registrado)*DAC_A;
          A_proyeccion_1_prod<=(ADC_AminusB_registrado)*DAC_A_cos;
          B_proyeccion_0_prod<=(ADC_C_registrado)*DAC_A;
          B_proyeccion_1_prod<=(ADC_C_registrado)*DAC_A_cos;
          A_proyeccion_0<=A_proyeccion_0_prod+ A_proyeccion_0;
          A_proyeccion_1<=A_proyeccion_1_prod+ A_proyeccion_1;
          B_proyeccion_0<=B_proyeccion_0_prod+ B_proyeccion_0; 
          B_proyeccion_1<=B_proyeccion_1_prod+ B_proyeccion_1;  
            A_proyeccion_0_reg<=A_proyeccion_0;
            A_proyeccion_1_reg<=A_proyeccion_1;
            B_proyeccion_0_reg<=B_proyeccion_0;
            B_proyeccion_1_reg<=B_proyeccion_1; 
            A_proyeccion_0_reg2<=A_proyeccion_0_reg;
            A_proyeccion_1_reg2<=A_proyeccion_1_reg;
            B_proyeccion_0_reg2<=B_proyeccion_0_reg;
            B_proyeccion_1_reg2<=B_proyeccion_1_reg;  
            /*
            pre2MODULOA1<=$signed(A_proyeccion_0[51:20])*$signed(A_proyeccion_0[51:20]);
            pre2MODULOA2<=$signed(A_proyeccion_1[51:20])*$signed(A_proyeccion_1[51:20]);
            pre2MODULOB1<=$signed(B_proyeccion_0[51:20])*$signed(B_proyeccion_0[51:20]);
            pre2MODULOB2<=$signed(B_proyeccion_1[51:20])*$signed(B_proyeccion_1[51:20]);
            pre2MODULOA<=pre2MODULOA1+pre2MODULOA2;
            pre2MODULOB<=pre2MODULOB1+pre2MODULOB2;
            */
        end
        if ((contador_5_ciclos==0)&&(address_mem!=0)&&((detectado_cero_S_reg==1'b1)||(detectado_cero_S_reg2==1'b1)||(detectado_cero_S_reg3==1'b1)))
        begin
          A_proyeccion_0_prod<=(ADC_AminusB_registrado)*DAC_A;
          A_proyeccion_1_prod<=(ADC_AminusB_registrado)*DAC_A_cos;
          B_proyeccion_0_prod<=(ADC_C_registrado)*DAC_A;
          B_proyeccion_1_prod<=(ADC_C_registrado)*DAC_A_cos;
          A_proyeccion_0<=A_proyeccion_0_prod+ A_proyeccion_0;
          A_proyeccion_1<=A_proyeccion_1_prod+ A_proyeccion_1;
          B_proyeccion_0<=B_proyeccion_0_prod+ B_proyeccion_0; 
          B_proyeccion_1<=B_proyeccion_1_prod+ B_proyeccion_1;            A_proyeccion_0_reg<=A_proyeccion_0;
            A_proyeccion_1_reg<=A_proyeccion_1;
            B_proyeccion_0_reg<=B_proyeccion_0;
            B_proyeccion_1_reg<=B_proyeccion_1; 
            A_proyeccion_0_reg2<=A_proyeccion_0_reg;
            A_proyeccion_1_reg2<=A_proyeccion_1_reg;
            B_proyeccion_0_reg2<=B_proyeccion_0_reg;
            B_proyeccion_1_reg2<=B_proyeccion_1_reg;  
/*            
            pre2MODULOA1<=$signed(A_proyeccion_0[51:20])*$signed(A_proyeccion_0[51:20]);
            pre2MODULOA2<=$signed(A_proyeccion_1[51:20])*$signed(A_proyeccion_1[51:20]);
            pre2MODULOB1<=$signed(B_proyeccion_0[51:20])*$signed(B_proyeccion_0[51:20]);
            pre2MODULOB2<=$signed(B_proyeccion_1[51:20])*$signed(B_proyeccion_1[51:20]);
            pre2MODULOA<=pre2MODULOA1+pre2MODULOA2;
            pre2MODULOB<=pre2MODULOB1+pre2MODULOB2;
            */
        end           
        if ((contador_5_ciclos==0)&&(address_mem!=0)&&(detectado_cero_S_reg4==1'b1))
        begin
  //          preMODULOA<=pre2MODULOA;//>>(32-numero_anchu);
    //        preMODULOB<=pre2MODULOB;//>>(32-numero_anchura);
            A_proyeccion_0_def<=A_proyeccion_0_reg2;
            A_proyeccion_1_def<=A_proyeccion_1_reg2;
            B_proyeccion_0_def<=B_proyeccion_0_reg2;
            B_proyeccion_1_def<=B_proyeccion_1_reg2; 
            fin2<=1'b1;
        end
        else begin
          fin2<=1'b0;
        end

      end
      G3B:
      begin
      if ((contador_5_ciclos==0)&&(address_mem!=0)&&(detectado_cero_S_reg4==1'b1))
      begin
   //       preMODULOA<=pre2MODULOA;//>>(32-numero_anchura);
     //     preMODULOB<=pre2MODULOB;//>>(32-numero_anchura);
          A_proyeccion_0_def<=A_proyeccion_0_reg2;
          A_proyeccion_1_def<=A_proyeccion_1_reg2;
          B_proyeccion_0_def<=B_proyeccion_0_reg2;
          B_proyeccion_1_def<=B_proyeccion_1_reg2; 
          fin2<=1'b1;
          state1<=G4;
          //fin<=1'b1;
      end
      else begin
        fin2<=1'b0;
      end     
      if ((contador_5_ciclos==0)&&((detectado_cero_S_reg==1'b1)||(detectado_cero_S_reg2==1'b1)||(detectado_cero_S_reg3==1'b1)))
      begin
        A_proyeccion_0_prod<=(ADC_AminusB_registrado)*DAC_A;
        A_proyeccion_1_prod<=(ADC_AminusB_registrado)*DAC_A_cos;
        B_proyeccion_0_prod<=(ADC_C_registrado)*DAC_A;
        B_proyeccion_1_prod<=(ADC_C_registrado)*DAC_A_cos;
        A_proyeccion_0<=A_proyeccion_0_prod+ A_proyeccion_0;
        A_proyeccion_1<=A_proyeccion_1_prod+ A_proyeccion_1;
        B_proyeccion_0<=B_proyeccion_0_prod+ B_proyeccion_0; 
        B_proyeccion_1<=B_proyeccion_1_prod+ B_proyeccion_1; 
          A_proyeccion_0_reg<=A_proyeccion_0;
          A_proyeccion_1_reg<=A_proyeccion_1;
          B_proyeccion_0_reg<=B_proyeccion_0;
          B_proyeccion_1_reg<=B_proyeccion_1; 
          A_proyeccion_0_reg2<=A_proyeccion_0_reg;
          A_proyeccion_1_reg2<=A_proyeccion_1_reg;
          B_proyeccion_0_reg2<=B_proyeccion_0_reg;
          B_proyeccion_1_reg2<=B_proyeccion_1_reg; 
/*           
            pre2MODULOA1<=$signed(A_proyeccion_0[51:20])*$signed(A_proyeccion_0[51:20]);
            pre2MODULOA2<=$signed(A_proyeccion_1[51:20])*$signed(A_proyeccion_1[51:20]);
            pre2MODULOB1<=$signed(B_proyeccion_0[51:20])*$signed(B_proyeccion_0[51:20]);
            pre2MODULOB2<=$signed(B_proyeccion_1[51:20])*$signed(B_proyeccion_1[51:20]);
          pre2MODULOA<=pre2MODULOA1+pre2MODULOA2;
          pre2MODULOB<=pre2MODULOB1+pre2MODULOB2;
          */
      end     
    end
      G4:
      if (VALID_P==1'b1)
      begin
      state1<=G3;
      fin2<=1'b0;
      end
      else  
        fin2<=1'b0;
      
      G3:
      begin
        fin<=1'b1;
        if (!start)
          state1 <= G0;
      end



    endcase

  end


  //recepcion
/*
  logic [ancho_detector-1:0] shifterS;
  logic [ancho_detector-1:0] shifterA;
  logic [ancho_detector-1:0] shifterB;
  */
  

  //logic signed [MAGNITUD_WIDTH-1:0] DAC_S_registrado;


/*
  always_ff @(posedge clk125 or negedge areset_n)
    if (!areset_n)
      auxA<={{cero_magnitud}};
    else
      auxA<={ADC_A};

  assign ADC_A_registrado={{18{auxA[13]}},auxA};

  always_ff @(posedge clk125 or negedge areset_n)
    if (!areset_n)
      auxB<={{cero_magnitud}};
    else
      auxB<={ADC_B};

  assign ADC_B_registrado={{18{auxB[13]}},auxB};

  always_ff @(posedge clk125 or negedge areset_n)
    if (!areset_n)
      auxS<={{cero_magnitud}};
    else
      auxS<={DAC_A};
*/
assign DAC_S_registrado=DAC_A; //DAC_A>>>1;//divido entre 2 para no saturar en la multiplicacion, es un cambio importante, antes era DAC_A sin registrar ni nada

  always_ff @(posedge clk125 or negedge areset_n)
  begin
    if(!areset_n)
    begin
     detectado_cero_S_reg<=1'b0;
     detectado_cero_S_reg2<=1'b0;
     detectado_cero_S_reg3<=1'b0;
     detectado_cero_S_reg4<=1'b0;    
    end
    else begin
     detectado_cero_S_reg<=detectado_cero_S;
     detectado_cero_S_reg2<=detectado_cero_S_reg;
     detectado_cero_S_reg3<=detectado_cero_S_reg2; 
     detectado_cero_S_reg4<=detectado_cero_S_reg3;           
   
    end
   end

  
 

  logic [63:0] cociente;
  logic findiv;
  logic finarctan;
  logic signed [31:0] fasea;
  logic signed [31:0] faseb;
  logic  signed  [31:0] PHASE_alternativa1, PHASE_alternativa2;
  
  logic pulso_fases, pulso_fases_reg,pulsito;
  logic valid_p_alternativa1, valid_p_alternativa2;

  logic fin2plus12;
  premodulo_best  preA //A*B+C*D
    (.clk(clk125),
    .areset_n(areset_n),
    .start(fin2),
    .done(fin2plus12),
    .A(A_proyeccion_0_def[51:20]),
    .B(A_proyeccion_0_def[51:20]),
    .C(A_proyeccion_1_def[51:20]),
    .D(A_proyeccion_1_def[51:20]),
    .SALIDA(preMODULOA));

  radicador_64_32  rad0(
	.CLK(clk125),
	.START(fin2plus12),
	.RESET(areset_n),
	.X(preMODULOA),
	.FIN(fin_radicador),
	.COUNT(MODULOA)
);

premodulo_best  preB
    (.clk(clk125),
    .areset_n(areset_n),
    .start(fin2),
    .done(),
    .A(B_proyeccion_0_def[51:20]),
    .B(B_proyeccion_0_def[51:20]),
    .C(B_proyeccion_1_def[51:20]),
    .D(B_proyeccion_1_def[51:20]),
    .SALIDA(preMODULOB));

radicador_64_32  rad1(
	.CLK(clk125),
	.START(fin2plus12),
	.RESET(areset_n),
	.X(preMODULOB),
	.FIN(),
	.COUNT(MODULOB)
);

assign moduloA_ampliado=MODULOA<<4; //esto es un cambio importante, antes era MODULOA sin ampliar ni nada, lo amplío para tener más precisión en la división, que es el siguiente paso, es un cambio importante porque afecta a toda la parte de la división y a la fase resultante, antes no tenía esta ampliación y el resultado era bastante malo, con esta ampliación el resultado mejora mucho, aunque sigue sin ser perfecto, es un cambio importante que afecta a toda la parte de la división y a la fase resultante, antes no tenía esta ampliación y el resultado era bastante malo, con esta ampliación el resultado mejora mucho, aunque sigue sin ser perfecto
  Divisor_Alg_ali #(.tamanyo(64))
               divisor_modulos
               (
                 .CLK(clk125),
                 .RSTa(areset_n),
                 .Start(fin_radicador),
                 .n_decimales(n_decimales),

                 .Num({{32{1'b0}}, MODULOA}), //antes estaba (moduloA_ampliado), lo cambio por MODULOA sin ampliar para ver si mejora o empeora el resultado, es un cambio importante porque afecta a toda la parte de la división y a la fase resultante, antes no tenía esta ampliación y el resultado era bastante malo, con esta ampliación el resultado mejora mucho, aunque sigue sin ser perfecto, lo cambio para ver si mejora o empeora el resultado, es un cambio importante porque afecta a toda la parte de la división y a la fase resultante, antes no tenía esta ampliación y el resultado era bastante malo, con esta ampliación el resultado mejora mucho, aunque sigue sin ser perfecto
                 .Den({{32{1'b0}}, MODULOB}),

                 .Coc(cociente),
                 //.Res(),
                 .Done(findiv)

               );
  //alternativa que funcionaba con shunt constante
  /*
  Divisor_Alg2 #(.tamanyo(32))
               divisor0
               (
                 .CLK(clk125),
                 .RSTa(areset_n),
                 .Start(fin_radicador),

                 .Num(moduloA_ampliado), //antes estaba (moduloA_ampliado), lo cambio por MODULOA sin ampliar para ver si mejora o empeora el resultado, es un cambio importante porque afecta a toda la parte de la división y a la fase resultante, antes no tenía esta ampliación y el resultado era bastante malo, con esta ampliación el resultado mejora mucho, aunque sigue sin ser perfecto, lo cambio para ver si mejora o empeora el resultado, es un cambio importante porque afecta a toda la parte de la división y a la fase resultante, antes no tenía esta ampliación y el resultado era bastante malo, con esta ampliación el resultado mejora mucho, aunque sigue sin ser perfecto
                 .Den({32{1'b0}}, MODULOB),

                 .Coc(cociente),
                 .Res(),
                 .Done(findiv)

               );
  */     
`ifdef ALTAS_FRECUENCIAS       
  arctan8best #(.tamanyo(64), .INVERTIR_SIGNOS(0))
               divisor_fa
               (
                 .CLK(clk125),
                 .RSTa(areset_n),
                 .Start(fin2),

                 .Num(A_proyeccion_1_def),
                 .Den(A_proyeccion_0_def),

                 .Coc(),
                 .Arctan2(fasea),
                 .Done(finarctan)

               );
 arctan8best #(.tamanyo(64), .INVERTIR_SIGNOS(0))
               divisor_fb
               (
                 .CLK(clk125),
                 .RSTa(areset_n),
                 .Start(fin2),

                 .Num(B_proyeccion_1_def),
                 .Den(B_proyeccion_0_def),

                 .Coc(),
                 .Arctan2(faseb),
                 .Done()

               );             
               
`else
  arctan8b #(.tamanyo(64))
               divisor_fa
               (
                 .CLK(clk125),
                 .RSTa(areset_n),
                 .Start(fin2),

                 .Num(A_proyeccion_1_def),
                 .Den(A_proyeccion_0_def),

                 .Coc(),
                 .Arctan2(fasea),
                 .Done(finarctan)

               );
 arctan8b #(.tamanyo(64))
               divisor_fb
               (
                 .CLK(clk125),
                 .RSTa(areset_n),
                 .Start(fin2),

                 .Num(B_proyeccion_1_def),
                 .Den(B_proyeccion_0_def),

                 .Coc(),
                 .Arctan2(faseb),
                 .Done()

               );   
`endif              
  /*  

  fifo_un_fichero #(.LENGTH(2), .SIZE(8))  FIFO_M (.CLOCK(clk125),
                  .RESET_N(areset_n),
                  .DATA_IN(address_mem-1),
                  .READ(findiv),
                  .WRITE(fin2),
                  .CLEAR_N(1'b1),
                  .F_FULL_N(),
                  .F_EMPTY_N(),
                  .USE_DW(),
                  .DATA_OUT(address_mem3_a1));
                  
  fifo_un_fichero #(.LENGTH(2), .SIZE(8))  FIFO_Pa (.CLOCK(clk125),
                  .RESET_N(areset_n),
                  .DATA_IN(address_mem-1),
                  .READ(finarctan),
                 // .READ(pulsito),
                  .WRITE(fin2),
                  .CLEAR_N(1'b1),
                  .F_FULL_N(),
                  .F_EMPTY_N(),
                  .USE_DW(),
                  .DATA_OUT(address_mem3_a2));
              
   */

  
 
  always_ff@(posedge clk125 or negedge areset_n)

    if(!areset_n)
	begin
		PHASE<='0;
	end
    else
    begin
        VALID_P<=finarctan;
      if (finarctan)
      begin
        PHASEA<=fasea;
        PHASEB<=faseb;
        PHASE <=fasea-faseb;        
      end
    end    

  always_ff@(posedge clk125 or negedge areset_n)

    if(!areset_n)
	begin
      		MODULO<='0;
	end
    else
    begin
      VALID_M<=findiv;
      valid_p_alternativa1<=findiv;
      if (findiv)
      begin
        MODULO<=cociente[31:0];//cuidado con este recorte, quiza deba quitarlo en el futuro  

    
      end
    end
 
 //assign address_mem2=address_mem3_a1;
 //assign address_mem3=address_mem3_a2;

             
  DDS_rafa_cuarto sin2_source (
                       .clk       (clk125),       // clk.clk
                       .reset_n   (areset_n),   // rst.reset_n
                       .phi_inc_i (incrementado), //    .phi_inc_i
                       .fsin_o    (DAC_A),    // out.fsin_o
                       .fcos_o    (DAC_A_cos),
					   .pulso     (detectado_cero_S)

                     );
/*				 
  DDS_rafa sin2_source (
                       .clk       (clk125),       // clk.clk
                       .reset_n   (areset_n),   // rst.reset_n
                       .clken     (1'b1),     //  in.clken
                       .phi_inc_i (incrementado), //    .phi_inc_i
                       .fsin_o    (DAC_A),    // out.fsin_o
                       .fcos_o    (DAC_A_cos),
                       .pulso     (detectado_cero_S),
                       .out_valid (ovalid)  //    .out_valid
                     );					 
*/
assign DAC_A_ext={{EXTENSION{DAC_A[MAGNITUD_WIDTH-1]}},DAC_A};
assign DAC_A_cos_ext={{EXTENSION{DAC_A_cos[MAGNITUD_WIDTH-1]}},DAC_A_cos};
  // Declare the ROM variable
  logic [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

  // Initialize the ROM with $readmemb.  Put the memory contents
  // in the file single_port_rom_init.txt.  Without this file,
  // this design will not compile.
  // See Verilog LRM 1364-2001 Section 17.2.8 for details on the
  // format of this file.

  initial
  begin
    $readmemh(FICHERO_INICIAL, ram);
  end
  always @(posedge clk125)
  begin
    if (wren_sys)
        ram[address_wr_sys]<=data_write_sys;
     data_read_sys<=ram[address_wr_sys];
    end
   always_ff@(posedge clk125 )
        if (address_mem<repeticiones)
           incrementado =ram[address_mem];  //borrar al terminar el debuf




always_comb
begin
if (test1==1'b0)
    estado_pasos_cero=address_mem<20? 3'b000: (address_mem<70?3'b001: (address_mem<120?3'b010:(address_mem<170?3'b011:3'b100)));
else
    if (address_mem<20 || address_mem > 419)
        estado_pasos_cero=3'b000;
    else if    (address_mem<70 || address_mem>   369)
        estado_pasos_cero=3'b001;
    else if    (address_mem<120 || address_mem>   319)
        estado_pasos_cero=3'b010;
    else if    (address_mem<170 || address_mem >  269 )
        estado_pasos_cero=3'b011;
    else
        estado_pasos_cero=3'b100;        
 end            
 
assign address_mem2=address_mem-1;
assign address_mem3=address_mem-1;

endmodule


