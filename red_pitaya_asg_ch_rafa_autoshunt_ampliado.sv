/**
 * $Id: red_pitaya_asg_ch.v 1271 2014-02-25 12:32:34Z matej.oblak $
 *
 * @brief Red Pitaya ASG submodule. Holds table and FSM for one channel.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

/**
 * GENERAL DESCRIPTION:
 *
 * Arbitrary signal generator takes data stored in buffer and sends them to DAC.
 *
 *
 *                /-----\         /--------\
 *   SW --------> | BUF | ------> | kx + o | ---> DAC DAT
 *          |     \-----/         \--------/
 *          |        ^
 *          |        |
 *          |     /-----\
 *          ----> |     |
 *                | FSM | ------> trigger notification
 *   trigger ---> |     |
 *                \-----/
 *
 *
 * Submodule for ASG which hold buffer data and control registers for one channel.
 * 
 */


module red_pitaya_asg_ch_rafa_autoshunt #(
   parameter RSZ = 14
)(
   // DAC
   output reg [ 14-1: 0] dac_o           ,  //!< dac data output
   input                 dac_clk_i       ,  //!< dac clock
   input                 dac_rstn_i      ,  //!< dac reset - active low
   //ADC
   input       [14-1:0]  adc_a_i         , // entradas adc canal1
   input       [14-1:0]  adc_b_i         , // entradas adc canal2
   
   //control
   input        [7:0]    control         ,
   //canal
   input                canal            , // seleccion de modulo ofase
   // trigger
   input                 trig_sw_i       ,  //!< software trigger
   input                 trig_ext_i      ,  //!< external trigger
   input      [  3-1: 0] trig_src_i      ,  //!< trigger source selector
   output                trig_done_o     ,  //!< trigger event
   // buffer ctrl
   input                 buf_we_i        ,  //!< buffer write enable
   input      [ 14-1: 0] buf_addr_i      ,  //!< buffer address
   input      [ 31: 0] buf_wdata_i     ,  //!< buffer write data
   output logic signed [31: 0]    buf_rdata_o     ,  //!< buffer read data
   output reg [RSZ-1: 0] buf_rpnt_o      ,  //!< buffer current read pointer
   
      // buffer ctrl
   input                 bufb_we_i        ,  //!< buffer write enable
   input      [ 14-1: 0] bufb_addr_i      ,  //!< buffer address
   input      [ 31: 0] bufb_wdata_i     ,  //!< buffer write data
   output logic signed [31: 0]    bufb_rdata_o     ,  //!< buffer read data
   output reg [RSZ-1: 0] bufb_rpnt_o      ,  //!< buffer current read pointer
   
   
   output                fin             ,
   output    [2:0]     estado_pasos_cero ,
   output [2:0]     estado_pasos_cero_dly ,
   //nuevas incorporaciones
   output  [31:0] modulo,
   output   [31:0] fase,
   output   modulo_valid,
   output   fase_valid,
   // configuration
   input     [RSZ+15: 0] set_size_i      ,  //!< set table data size
   input     [RSZ+15: 0] set_step_i      ,  //!< set pointer step
   input     [RSZ+15: 0] set_ofs_i       ,  //!< set reset offset
   input                 set_rst_i       ,  //!< set FSM to reset
   input                 set_once_i      ,  //!< set only once  -- not used
   input                 set_wrap_i      ,  //!< set wrap enable
   input     [  14-1: 0] set_amp_i       ,  //!< set amplitude scale
   input     [  14-1: 0] set_dc_i        ,  //!< set output offset output
   input     [  14-1: 0] set_adc_b_i        ,  //!< set output offset input canal 2
   input     [  14-1: 0] set_last_i      ,  //!< set final value in burst
   input                 set_zero_i      ,  //!< set output to zero
   input     [  16-1: 0] set_ncyc_i      ,  //!< set number of cycle
   input     [  16-1: 0] set_rnum_i      ,  //!< set number of frecuencias
   input     [  16-1: 0] setb_ncyc_i      ,  //!< set number of ancho del detector de cero
   input     [  16-1: 0] setb_rnum_i      ,  //!< set number salto frecuencias  
   input     [  32-1: 0] set_rdly_i      ,  //!< set delay between repetitions
   input                 set_rgate_i        //!< set external gated repetition
);

//---------------------------------------------------------------------------------
//
//  DAC buffer RAM

// reg   [  14-1: 0] dac_buf [0:(1<<RSZ)-1] ;
reg   [  14-1: 0] dac_rd    ;
reg   [  14-1: 0] dac_rdat  ;
reg   [ RSZ-1: 0] dac_rp    ;
reg   [RSZ+15: 0] dac_pnt   ; // read pointer
reg   [RSZ+15: 0] dac_pntp  ; // previour read pointer
wire  [RSZ+16: 0] dac_npnt  ; // next read pointer
wire  [RSZ+16: 0] dac_npnt_sub ;
wire              dac_npnt_sub_neg;

reg   [  16-1: 0] cyc_cnt   ;
reg   [  28-1: 0] dac_mult  ;
reg   [  15-1: 0] dac_sum   ;
reg               lastval;
wire              not_burst;

assign not_burst = (&(~set_ncyc_i)) && (&(~set_rnum_i));

// read
always @(posedge dac_clk_i)
begin
   buf_rpnt_o <= dac_pnt[RSZ+15:16];
   dac_rp     <= dac_pnt[RSZ+15:16];
   //dac_rd     <= dac_buf[dac_rp] ;
   //dac_rdat   <= dac_rd ;  // improve timing
end





// scale and offset
//always @(posedge dac_clk_i)
//begin
  // dac_mult <= $signed(dac_rdat) * $signed({1'b0,set_amp_i}) ;
   // dac_sum  <= $signed(dac_mult[28-1:13]) + $signed(set_dc_i) ;

   // saturation
  // if (set_zero_i)  
  //    dac_o <= 14'h0;
  // else if (lastval) //on last value in burst send user specified last value
  //    dac_o <= set_last_i;
  // else 
  //    dac_o <= ^dac_sum[15-1:15-2] ? {dac_sum[15-1], {13{~dac_sum[15-1]}}} : dac_sum[13:0];

//end

//---------------------------------------------------------------------------------
//
//  read pointer & state machine

reg              trig_in      ;
wire             ext_trig_p   ;
wire             ext_trig_n   ;

reg  [  16-1: 0] rep_cnt      ;
reg  [  32-1: 0] dly_cnt      ;
reg  [   8-1: 0] dly_tick     ;

reg              dac_do       ;
reg  [   5-1: 0] dac_do_dlysr ;
reg              dac_rep      ;
wire             dac_trig     ;
reg              dac_trigr    ;

always @(posedge dac_clk_i)
begin 
   dac_do_dlysr[0]   <= dac_do;
   dac_do_dlysr[4:1] <= dac_do_dlysr[3:0];
end

always @(posedge dac_clk_i)
begin 
   if (dac_rstn_i == 1'b0)
      lastval <= 1'b0;
   else begin
      if (dac_do_dlysr[4:3] == 2'b10) // negative edge of dly_do, delayed for 4 cycles
         lastval <= 1'b1;
      
      if ((lastval && dly_cnt == 'd0 && |rep_cnt) || set_zero_i || set_rst_i || not_burst) // release from last value when new cycle starts or a set_zero is written. After final cycle, stay on lastval. also resets if reset is set or continous mode is selected.
         lastval <= 1'b0;
   end
end

// state machine
always @(posedge dac_clk_i) begin
   if (dac_rstn_i == 1'b0) begin
      cyc_cnt   <= 16'h0 ;
      rep_cnt   <= 16'h0 ;
      dly_cnt   <= 32'h0 ;
      dly_tick  <=  8'h0 ;
      dac_do    <=  1'b0 ;
      dac_rep   <=  1'b0 ;
      trig_in   <=  1'b0 ;
      dac_pntp  <= {RSZ+16{1'b0}} ;
      dac_trigr <=  1'b0 ;
   end
   else begin
      // make 1us tick
      if (dac_do || (dly_tick == 8'd124))
         dly_tick <= 8'h0 ;
      else
         dly_tick <= dly_tick + 8'h1 ;

      // delay between repetitions 
      if (set_rst_i || dac_do)
         dly_cnt <= set_rdly_i ;
      else if (|dly_cnt && (dly_tick == 8'd124))
         dly_cnt <= dly_cnt - 32'h1 ;

      // repetitions counter
      if (trig_in && !dac_do)
         rep_cnt <= set_rnum_i ;
      else if (!set_rgate_i && (|rep_cnt && dac_rep && (dac_trig && !dac_do)))
         rep_cnt <= rep_cnt - 16'h1 ;
      else if (set_rgate_i && ((!trig_ext_i && trig_src_i==3'd2) || (trig_ext_i && trig_src_i==3'd3)))
         rep_cnt <= 16'h0 ;

      // count number of table read cycles
      dac_pntp  <= dac_pnt;
      dac_trigr <= dac_trig; // ignore trigger when count
      if (dac_trig)
         cyc_cnt <= set_ncyc_i ;
      else if (!dac_trigr && |cyc_cnt && ({1'b0,dac_pntp} > {1'b0,dac_pnt}))
         cyc_cnt <= cyc_cnt - 16'h1 ;

      // trigger arrived
      case (trig_src_i)
          3'd1 : trig_in <= trig_sw_i   ; // sw
          3'd2 : trig_in <= ext_trig_p  ; // external positive edge
          3'd3 : trig_in <= ext_trig_n  ; // external negative edge
       default : trig_in <= 1'b0        ;
      endcase

      // in cycle mode
      if (dac_trig && !set_rst_i)
         dac_do <= 1'b1 ;
      else if (set_rst_i || ((cyc_cnt==16'h1) && ~dac_npnt_sub_neg) )
         dac_do <= 1'b0 ;

      // in repetition mode
      if (dac_trig && !set_rst_i)
         dac_rep <= 1'b1 ;
      else if (set_rst_i || (rep_cnt==16'h0))
         dac_rep <= 1'b0 ;
   end
end

assign dac_trig = (!dac_rep && trig_in) || (dac_rep && |rep_cnt && (dly_cnt == 32'h0)) ;

assign dac_npnt_sub = dac_npnt - {1'b0,set_size_i} - 1;
assign dac_npnt_sub_neg = dac_npnt_sub[RSZ+16];

// read pointer logic
always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   dac_pnt  <= {RSZ+16{1'b0}};
end else begin
   if (set_rst_i || (dac_trig && !dac_do)) // manual reset or start
      dac_pnt <= set_ofs_i;
   else if (dac_do) begin
      if (~dac_npnt_sub_neg)  dac_pnt <= set_wrap_i ? dac_npnt_sub : set_ofs_i; // wrap or go to start
      else                    dac_pnt <= dac_npnt[RSZ+15:0]; // normal increase
   end
end

assign dac_npnt = dac_pnt + set_step_i;
// assign trig_done_o = !dac_rep && trig_in;

//---------------------------------------------------------------------------------
//
//  External trigger

reg  [  3-1: 0] ext_trig_in    ;
reg  [  2-1: 0] ext_trig_dp    ;
reg  [  2-1: 0] ext_trig_dn    ;
reg  [ 20-1: 0] ext_trig_debp  ;
reg  [ 20-1: 0] ext_trig_debn  ;

always @(posedge dac_clk_i) begin
   if (dac_rstn_i == 1'b0) begin
      ext_trig_in   <=  3'h0 ;
      ext_trig_dp   <=  2'h0 ;
      ext_trig_dn   <=  2'h0 ;
      ext_trig_debp <= 20'h0 ;
      ext_trig_debn <= 20'h0 ;
   end
   else begin
      //----------- External trigger
      // synchronize FFs
      ext_trig_in <= {ext_trig_in[1:0],trig_ext_i} ;

      // look for input changes
      if ((ext_trig_debp == 20'h0) && (ext_trig_in[1] && !ext_trig_in[2]))
         ext_trig_debp <= 20'd62500 ; // ~0.5ms
      else if (ext_trig_debp != 20'h0)
         ext_trig_debp <= ext_trig_debp - 20'd1 ;

      if ((ext_trig_debn == 20'h0) && (!ext_trig_in[1] && ext_trig_in[2]))
         ext_trig_debn <= 20'd62500 ; // ~0.5ms
      else if (ext_trig_debn != 20'h0)
         ext_trig_debn <= ext_trig_debn - 20'd1 ;

      // update output values
      ext_trig_dp[1] <= ext_trig_dp[0] ;
      if (ext_trig_debp == 20'h0)
         ext_trig_dp[0] <= ext_trig_in[1] ;

      ext_trig_dn[1] <= ext_trig_dn[0] ;
      if (ext_trig_debn == 20'h0)
         ext_trig_dn[0] <= ext_trig_in[1] ;
   end
end

assign ext_trig_p = (ext_trig_dp == 2'b01) ;
assign ext_trig_n = (ext_trig_dn == 2'b10) ;


///////////////////// empiezo con codigo nuevo


reg		 [13:0]		r_ADC_DA/*synthesis noprune*/;
reg	signed	 [13:0]		r_ADC_DB/*synthesis noprune*/;
reg		 [13:0]		r_DAC_DA/*synthesis noprune*/;

logic    signed   [13:0]     ADC_DA_reg, ADC_DA_reg2,ADC_DA_reg2_fil;
logic   signed   [13:0]     ADC_DB_reg, ADC_DB_reg2,ADC_DB_reg2_fil;
//filtros copiados de scope

/*
red_pitaya_dfilt1 i_dfilt1_cha (
   // ADC
  .adc_clk_i   ( dac_clk_i       ),  // ADC clock
  .adc_rstn_i  ( dac_rstn_i      ),  // ADC reset - active low
  .adc_dat_i   ( ADC_DA_reg2   ),  // ADC data
  .adc_dat_o   ( ),  // ADC data
   // configuration
  .cfg_aa_i    ( 18'h07D93 ),  // config AA coefficient
  .cfg_bb_i    ( 25'h00437C7  ),  // config BB coefficient
  .cfg_kk_i    ( 25'h0002666  ),  // config KK coefficient
  .cfg_pp_i    ( 25'h0D9999A  )   // config PP coefficient
);

red_pitaya_dfilt1 i_dfilt1_chb (
   // ADC
  .adc_clk_i   ( dac_clk_i       ),  // ADC clock
  .adc_rstn_i  ( dac_rstn_i      ),  // ADC reset - active low
  .adc_dat_i   ( ADC_DB_reg2   ),  // ADC data
  .adc_dat_o   (  ),  // ADC data
   // configuration
  .cfg_aa_i    ( 18'h07D93  ),  // config AA coefficient
  .cfg_bb_i    ( 25'h00437C7  ),  // config BB coefficient
  .cfg_kk_i    ( 25'h0002666),  // config KK coefficient
  .cfg_pp_i    ( 25'h0D9999A  )   // config PP coefficient
);

*/
//atencion importante
assign ADC_DA_reg2_fil=ADC_DA_reg2;
// assign ADC_DB_reg2_fil=$signed(ADC_DB_reg2)+ $signed(set_adc_b_i ); para variar el offset del canal de entrada
assign ADC_DB_reg2_fil=ADC_DB_reg2;
/////////////////////////////////////

// para mi bloque


logic [13:0] DAC_DA_rafa;

wire    [13:0]	sin_out;



wire    [31:0]	fasea,faseb;
wire    [13:0]	 moduloA, moduloB;
// wire    [31:0]  modulo;
wire    [31:0] resultado;
wire    [8:0]  direccion,direccion2,direccion3,direccion4;
wire    wren,wren2,wren3;
wire    [21:0] temp1,temp2;



assign  phasinc1 = 32'd34359738;
assign  phasinc2 = phasinc1<<1;



assign  POWER_ON  = 1;            //Disable OSC_SMA


//reg		 [13:0]		r_DAC_DB/*synthesis noprune*/;

/*
assign temp1=(ADC_DA-13'd6702)*8'b01011011;
assign temp2=(ADC_DB-13'd6702)*8'b01011011;

always @ (posedge CLK_65) r_ADC_DA <= 2*temp1[18:6]-13'd4096;
always @ (posedge CLK_65) r_ADC_DB <= 2*temp2[18:6]-13'd4096;

*/

reg   [  28-1: 0] dac_mult_rafa  ;
reg   [  15-1: 0] dac_sum_rafa   ;
//sincronizadores

always_ff @(posedge dac_clk_i )
	begin
			ADC_DA_reg<=adc_a_i;
			ADC_DA_reg2<=ADC_DA_reg;
			ADC_DB_reg<=adc_b_i;
			ADC_DB_reg2<=ADC_DB_reg;
			
	end

localparam DESFASE1=20, DESFASE2=30;

localparam [13:0] cero_magnitud='0;

//logic [(DESFASE2 -1):0][13:0] auxB;

//logic  signed[13:0] LOOP_B_DESFASADO;
/*
always_ff @(posedge adc_clk or negedge adc_rstn)
	if (!adc_rstn)
			  auxB<={(DESFASE2){cero_magnitud}};
	else
			auxB<={r_DAC_DA,auxB[DESFASE2-1:1]};

	assign LOOP_B_DESFASADO=auxB[0];

*/
/*
assign temp1=(ADC_DA_reg2-13'd6690)*8'b10101110;
assign temp2=(ADC_DB_reg2-13'd6690)*8'b10101110;

always @ (posedge dac_clk_i) r_ADC_DA <= temp1[18:6]-13'd4096;
always @ (posedge dac_clk_i) r_ADC_DB <=  temp2[18:6]-13'd4096;


always @ (posedge dac_clk_i) r_DAC_DA <= {sin_out[13],sin_out[13:1]};

always @ (posedge dac_clk_i) DAC_DA_rafa <= {sin_out[13],sin_out[13:1]}+13'd4096;

*/

// scale and offset
always @(posedge dac_clk_i)
begin
   dac_mult_rafa <= $signed(sin_out) * $signed({1'b0,set_amp_i}) ;
   dac_sum_rafa  <= $signed(dac_mult_rafa[28-1:13]) + $signed(set_dc_i) ;

   // saturation
   if (set_zero_i)  
      dac_o <= 14'h0;
   else if (lastval) //on last value in burst send user specified last value
      dac_o <= set_last_i;
   else 
      dac_o <= ^dac_sum_rafa[15-1:15-2] ? {dac_sum_rafa[15-1], {13{~dac_sum_rafa[15-1]}}} : dac_sum_rafa[13:0];
 

end




wire empezar_chirp= set_once_i ;

logic [31:0] debugeo;	
Control_path_best_rafa_mejora_correlacion_autoshunt
#(.DATA_WIDTH(32), .ADDR_WIDTH(9), .MAGNITUD_WIDTH(14), .pancho_detector(30),.pciclos(1), .FICHERO_INICIAL("freq_log_ideal.dat"))

Ucontrol
(.clk125(dac_clk_i),
.clk65(dac_clk_i),
.test1(control[1]),
.test2(control[2]),
.test3(control[3]),
//.test1(1'b0),
//.test2(1'b1),
.areset_n(dac_rstn_i),
//cambio 2026 1, el start viene de control[0] que será controlado por PIN LED0 
//.start(empezar_chirp),
.start(control[0]),
//din cambio
.ADC_A(ADC_DA_reg2_fil),
.ADC_B(ADC_DB_reg2_fil),
.address_mem(direccion),
.address_mem2(direccion2),
.address_mem3(direccion3),
.wren_sys(buf_we_i),
.address_wr_sys(buf_addr_i),
.data_write_sys(buf_wdata_i),
.data_read_sys(debugeo), //borrar al terminar debugeo
.salto(setb_rnum_i),
.numero_rep(set_rnum_i),
.num_ciclos(set_ncyc_i),
.numero_anchura(setb_ncyc_i),
.fin(fin),
.fin2(),
.VALID_M(wren),
.VALID_P(wren2),

.DAC_S_registrado(sin_out),
.MODULO(modulo),
.PHASE(fase),
//.PHASEA(fasea),
//.PHASEB(faseb),
//.MODULOA(moduloA),
//.MODULOB(moduloB),
.estado_pasos_cero_dly(estado_pasos_cero_dly),
.estado_pasos_cero(estado_pasos_cero)
);

// assign resultado=canal?modulo:fase;

// write from system or chirp
// always @(posedge dac_clk_i)
// begin
// if (buf_we_i)  dac_buf[buf_addr_i] <= buf_wdata_i[14-1:0] ;

//if (wren)  dac_buf[{1'b0,direccion}] <= modulo ;
//if (wren)  dac_buf[{1'b1,direccion}] <= fase ;
// end


reg  signed [  31: 0] result_buf [0:(1<<9)-1] ; // buffer de 256 x 32
// write from system or chirp
always @(posedge dac_clk_i)
begin
if (wren)  
    begin
        result_buf[{direccion2}] <= modulo ;
   //     result_buf[{1'b1,direccion}] <= moduloB;
    end
end
assign modulo_valid=wren;
logic signed [31: 0]    buf_rdata;
// read-back
always @(posedge dac_clk_i)
//buf_rdata_o <= control[4]?result_buf[buf_addr_i]:dac_buf[buf_addr_i] ;
    buf_rdata <= result_buf[buf_addr_i] ;
assign    buf_rdata_o= control[2]?debugeo:buf_rdata; //borrar al terminar debugeo    
    
//assign    buf_rdata_o= {buf_rdata};

/*
reg  signed [  31: 0] resultb_buf [0:(1<<9)-1] ; // buffer de 256 x 32
// write from system or chirp
always @(posedge dac_clk_i)
begin
if (wren2)  
    begin
        resultb_buf[{1'b0,direccion3}] <= { fasea} ;
        resultb_buf[{1'b1,direccion3}] <= { faseb} ;
    end
end
*/
reg  signed [  31: 0] resultb_buf [0:(1<<9)-1] ; // buffer de 512 x 32
// write from system or chirp
always @(posedge dac_clk_i)
begin
if (wren2)  
    begin
        resultb_buf[{direccion3}] <= { fase} ;
    end
end

assign fase_valid=wren2;

logic signed [31: 0]    bufb_rdata;
// read-back

 always @(posedge dac_clk_i) 
    bufb_rdata <= resultb_buf[buf_addr_i] ; 
    
    

assign    bufb_rdata_o= bufb_rdata; //restituir al finalizar el debugeo

endmodule
