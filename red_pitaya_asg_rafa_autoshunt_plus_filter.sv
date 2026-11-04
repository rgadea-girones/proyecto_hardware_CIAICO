/**
 * $Id: red_pitaya_asg.v 961 2014-01-21 11:40:39Z matej.oblak $
 *
 * @brief Red Pitaya arbitrary signal generator (ASG).
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
 *   SW --------> | BUF | ------> | kx + o | ---> DAC CHA
 *                \-----/         \--------/
 *                   ^
 *                   |
 *                /-----\
 *   SW --------> |     |
 *                | FSM | ------> trigger notification
 *   trigger ---> |     |
 *                \-----/
 *                   |
 *                   ˇ
 *                /-----\         /--------\
 *   SW --------> | BUF | ------> | kx + o | ---> DAC CHB
 *                \-----/         \--------/ 
 *
 *
 * Buffers are filed with SW. It also sets finite state machine which take control
 * over read pointer. All registers regarding reading from buffer has additional 
 * 16 bits used as decimal points. In this way we can make better ratio betwen 
 * clock cycle and frequency of output signal. 
 *
 * Finite state machine can be set for one time sequence or continously wrapping.
 * Starting trigger can come from outside, notification trigger used to synchronize
 * with other applications (scope) is also available. Both channels are independant.
 *
 * Output data is scaled with linear transmormation.
 * 
 */


module red_pitaya_asg_rafa_autoshunt_plus_filter (
  // DAC
  output     [ 14-1: 0] dac_a_o   ,  // DAC data CHA
  output     [ 14-1: 0] dac_b_o   ,  // DAC data CHB
  input                 dac_clk_i ,  // DAC clock
  input                 dac_rstn_i,  // DAC reset - active low
  input                 adc_clk_i ,  // DAC clock
  input                 adc_rstn_i,  // DAC reset - active low
  input      [ 14-1: 0]  adc_a_i  , //entrada canal 1
  input      [ 14-1: 0]  adc_b_i  , //entrada canal 2  
  input      [7:0]      control  , // control PIO leds
  input                 trig_a_i  ,  // starting trigger CHA
  input                 trig_b_i  ,  // starting trigger CHB
  output                trig_out_o , // notification trigger
  output                fina,
  output    [2:0]       estado_pasos_cero,
  output    [2:0]       estado_pasos_cero_dly,
  //nuevas incorporaciones
  output [31:0] modulo,
  output [31:0] fase,
  output      modulo_valid,
  output      fase_valid,
  // System bus1
  input      [ 32-1: 0] sys_addr  ,  // bus address
  input      [ 32-1: 0] sys_wdata ,  // bus write data
  input                 sys_wen   ,  // bus write enable
  input                 sys_ren   ,  // bus read enable
  output reg [ 32-1: 0] sys_rdata ,  // bus read data
  output reg            sys_err   ,  // bus error indicator
  output reg            sys_ack  ,    // bus acknowledge signal

    // System bus2
  input      [ 32-1: 0] sys_addr2  ,  // bus address
  input      [ 32-1: 0] sys_wdata2 ,  // bus write data
  input                 sys_wen2   ,  // bus write enable
  input                 sys_ren2   ,  // bus read enable
  output reg [ 32-1: 0] sys_rdata2 ,  // bus read data
  output reg            sys_err2   ,  // bus error indicator
  output reg            sys_ack2      // bus acknowledge signal
);

//---------------------------------------------------------------------------------
//
// generating signal from DAC table 

localparam RSZ = 14 ;  // RAM size 2^RSZ

reg   [RSZ+15: 0] set_a_size   , set_b_size   ;
reg   [RSZ+15: 0] set_a_step   , set_b_step   ;
reg   [RSZ+15: 0] set_a_ofs    , set_b_ofs    ;
reg               set_a_rst    , set_b_rst    ;
reg               set_a_once   , set_b_once   ;
reg               set_a_wrap   , set_b_wrap   ;
reg   [  14-1: 0] set_a_amp    , set_b_amp    ;
reg   [  14-1: 0] set_a_dc     , set_b_dc     ;
reg               set_a_zero   , set_b_zero   ;
reg   [  16-1: 0] set_a_ncyc   , set_b_ncyc   ;
reg   [  16-1: 0] set_a_rnum   , set_b_rnum   ;
reg   [  32-1: 0] set_a_rdly   , set_b_rdly   ;
reg               set_a_rgate  , set_b_rgate  ;
reg               buf_a_we     , buf_b_we     ;
reg   [ RSZ-1: 0] buf_a_addr   , buf_b_addr   ;
wire  [ 31: 0]    buf_b_rdata                 ;
wire  [ 31: 0]    buf_a_rdata                 ;
wire  [ RSZ-1: 0] buf_a_rpnt   , buf_b_rpnt   ;
reg   [  32-1: 0] buf_a_rpnt_rd, buf_b_rpnt_rd;
reg               trig_a_sw    , trig_b_sw    ;
reg   [   3-1: 0] trig_a_src   , trig_b_src   ;
wire              trig_a_done  , trig_b_done  ;
reg   [  14-1: 0] set_a_last   , set_b_last   ;
wire              adc_rd_dv     ;
// wire fina;

wire [ 14-1: 0] adc_a_def      ;
wire [ 14-1: 0] adc_b_def      ;

red_pitaya_asg_ch  #(.RSZ (RSZ)) ch_b (
  // DAC
 // .dac_o           ({dac_b_o            }),  // dac data output
  .dac_o           (),  // dac data output
  .dac_clk_i       ({1'b0         }),  // dac clock
  .dac_rstn_i      ({1'b0        }),  // dac reset - active low

  // trigger
  .trig_sw_i       ({trig_b_sw          }),  // software trigger
  .trig_ext_i      ({trig_b_i           }),  // external trigger
  .trig_src_i      ({trig_b_src         }),  // trigger source selector
  .trig_done_o     ({trig_b_done        }),  // trigger event
  // buffer ctrl
  .buf_we_i        ({buf_b_we           }),  // buffer buffer write
  .buf_addr_i      ({buf_b_addr         }),  // buffer address
  .buf_wdata_i     ({sys_wdata}),  // buffer write data
 // .buf_rdata_o     ({buf_b_rdata        }),  // buffer read data
 // .buf_rpnt_o      ({buf_b_rpnt         }),  // buffer current read pointer
  .buf_rdata_o     (),  // buffer read data
  .buf_rpnt_o      (),  // buffer current read pointer
  // configuration

  .set_size_i      ({set_b_size         }),  // set table data size
  .set_step_i      ({set_b_step         }),  // set pointer step
  .set_ofs_i       ({set_b_ofs          }),  // set reset offset
  .set_rst_i       ({set_b_rst          }),  // set FMS to reset
  .set_once_i      ({set_b_once        }),  // set only once
  .set_wrap_i      ({set_b_wrap            }),  // set wrap pointer
  .set_amp_i       ({set_b_amp           }),  // set amplitude scale
  .set_dc_i        ({set_b_dc           }),  // set output offset
  .set_last_i      ({set_b_last          }),  // set last value
  .set_zero_i      ({set_b_zero          }),  // set output to zero
  .set_ncyc_i      ({set_b_ncyc          }),  // set number of cycle
  .set_rnum_i      ({set_b_rnum          }),  // set number of repetitions
  .set_rdly_i      ({set_b_rdly         }),  // set delay between repetitions
  .set_rgate_i     ({set_b_rgate        })   // set external gated repetition
);

red_pitaya_asg_ch_rafa_autoshunt  #(.RSZ (RSZ)) ch_a (
  // DAC
  .dac_o           ({ dac_a_o          }),  // dac data output
  .dac_clk_i       ({ dac_clk_i        }),  // dac clock
  .dac_rstn_i      ({dac_rstn_i        }),  // dac reset - active low
  //ADC
  .adc_a_i         ({adc_a_def           }),  //adc entradas
  .adc_b_i         ({ adc_b_def          }),  //adc entradas  
  //control
  .control          ({ control         }),  //adc entradas
  .canal            ({1'b1             }),   //modulo o fase
  // trigger
  .trig_sw_i       ({trig_a_sw         }),  // software trigger
  .trig_ext_i      ({trig_a_i          }),  // external trigger
  .trig_src_i      ({trig_a_src        }),  // trigger source selector
  .trig_done_o     ({ trig_a_done      }),  // trigger event
  // buffer ctrl
  .buf_we_i        ({ buf_a_we         }),  // buffer buffer write
  .buf_addr_i      ({ buf_a_addr       }),  // buffer address
  .buf_wdata_i     ({sys_wdata}),  // buffer write data
  .buf_rdata_o     ({buf_a_rdata       }),  // buffer read data
  .buf_rpnt_o      ({ buf_a_rpnt       }),  // buffer current read pointer
  
  //nuevas incorporaciones
  .modulo(modulo)                          ,
  .fase(fase)                              ,
  .modulo_valid(modulo_valid)              ,
  .fase_valid(fase_valid)                   ,
  //
  .bufb_we_i        ({buf_b_we           }),  // buffer buffer write
  .bufb_addr_i      ({buf_b_addr         }),  // buffer address
  .bufb_wdata_i     ({sys_wdata  }),  // buffer write data
  .bufb_rdata_o     ({buf_b_rdata        }),  // buffer read data
  .bufb_rpnt_o      ({buf_b_rpnt         }),  // buffer current read pointer

  // configuration
   .fin            ({    fina          }),  // set table data size
   .estado_pasos_cero( estado_pasos_cero),
.estado_pasos_cero_dly( estado_pasos_cero_dly),
  .set_size_i      ({ set_a_size       }),  // set table data size
  .set_step_i      ({set_a_step        }),  // set pointer step
  .set_ofs_i       ({ set_a_ofs        }),  // set reset offset
  .set_rst_i       ({ set_a_rst        }),  // set FMS to reset
  .set_once_i      ({ set_a_once       }),  // set only once
  .set_wrap_i      ({ set_a_wrap       }),  // set wrap pointer
  .set_amp_i       ({ set_a_amp        }),  // set amplitude scale
  .set_dc_i        ({ set_a_dc         }),  // set output offset
  .set_adc_b_i     (set_b_dc)            ,  //offset canal b in
  .set_last_i      ({ set_a_last       }),  // set last value
  .set_zero_i      ({ set_a_zero       }),  // set output to zero
  .set_ncyc_i      ({set_a_ncyc        }),  // set number of cycle
  .set_rnum_i      ({set_a_rnum        }),  // set number of repetitions
  .setb_ncyc_i      ({set_b_ncyc        }),  // set number of cycle
  .setb_rnum_i      ({set_b_rnum        }),  // set number of repetitions
  .set_rdly_i      ({ set_a_rdly       }),  // set delay between repetitions
  .set_rgate_i     ({ set_a_rgate      })   // set external gated repetition
);

always @(posedge dac_clk_i)
begin
   buf_a_we   <= sys_wen && (sys_addr[19:RSZ+2] == 'h1);
   buf_b_we   <= sys_wen && (sys_addr[19:RSZ+2] == 'h2);
   buf_a_addr <= sys_addr[RSZ+1:2] ;  // address timing violation
   buf_b_addr <= sys_addr[RSZ+1:2] ;  // can change only synchronous to write clock
end

assign trig_out_o = trig_a_done ;

//---------------------------------------------------------------------------------
//
//  System bus connection

reg  [3-1: 0] ren_dly ;
reg           ack_dly ;

always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   trig_a_sw   <=  1'b0    ;
   trig_a_src  <=  3'h0    ;
   set_a_amp   <= 14'h2000 ;
   set_a_dc    <= 14'h0    ;
   set_a_zero  <=  1'b0    ;
   set_a_rst   <=  1'b0    ;
   set_a_once  <=  1'b0    ;
   set_a_wrap  <=  1'b0    ;
   set_a_size  <= {RSZ+16{1'b1}} ;
   set_a_ofs   <= {RSZ+16{1'b0}} ;
   set_a_step  <={{RSZ+15{1'b0}},1'b0} ;
   set_a_ncyc  <= 16'h0    ;
   set_a_rnum  <= 16'h0    ;
   set_a_rdly  <= 32'h0    ;
   set_a_rgate <=  1'b0    ;
   trig_b_sw   <=  1'b0    ;
   trig_b_src  <=  3'h0    ;
   set_b_amp   <= 14'h2000 ;
   set_b_dc    <= 14'h0    ;
   set_b_zero  <=  1'b0    ;
   set_b_rst   <=  1'b0    ;
   set_b_once  <=  1'b0    ;
   set_b_wrap  <=  1'b0    ;
   set_b_size  <= {RSZ+16{1'b1}} ;
   set_b_ofs   <= {RSZ+16{1'b0}} ;
   set_b_step  <={{RSZ+15{1'b0}},1'b0} ;
   set_b_ncyc  <= 16'h0    ;
   set_b_rnum  <= 16'h0    ;
   set_b_rdly  <= 32'h0    ;
   set_b_rgate <=  1'b0    ;
   set_a_last  <= 14'h0    ;
   set_b_last  <= 14'h0    ;
   ren_dly     <=  3'h0    ;
   ack_dly     <=  1'b0    ;
end else begin
   trig_a_sw  <= sys_wen && (sys_addr[19:0]==20'h0) && sys_wdata[0]  ;
   if (sys_wen && (sys_addr[19:0]==20'h0))
      trig_a_src <= sys_wdata[2:0] ;

   trig_b_sw  <= sys_wen && (sys_addr[19:0]==20'h0) && sys_wdata[16]  ;
   if (sys_wen && (sys_addr[19:0]==20'h0))
      trig_b_src <= sys_wdata[19:16] ;

   if (sys_wen) begin
      if (sys_addr[19:0]==20'h0)   {set_a_rgate, set_a_zero, set_a_rst, set_a_once, set_a_wrap} <= sys_wdata[ 8: 4] ;
      if (sys_addr[19:0]==20'h0)   {set_b_rgate, set_b_zero, set_b_rst, set_b_once, set_b_wrap} <= sys_wdata[24:20] ;

      if (sys_addr[19:0]==20'h4)   set_a_amp  <= sys_wdata[  0+13: 0] ;
      if (sys_addr[19:0]==20'h4)   set_a_dc   <= sys_wdata[ 16+13:16] ;
      if (sys_addr[19:0]==20'h8)   set_a_size <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'hC)   set_a_ofs  <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h10)  set_a_step <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h18)  set_a_ncyc <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h1C)  set_a_rnum <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h20)  set_a_rdly <= sys_wdata[  32-1: 0] ;

      if (sys_addr[19:0]==20'h24)  set_b_amp  <= sys_wdata[  0+13: 0] ;
      if (sys_addr[19:0]==20'h24)  set_b_dc   <= sys_wdata[ 16+13:16] ;
      if (sys_addr[19:0]==20'h28)  set_b_size <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h2C)  set_b_ofs  <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h30)  set_b_step <= sys_wdata[RSZ+15: 0] ;
      if (sys_addr[19:0]==20'h38)  set_b_ncyc <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h3C)  set_b_rnum <= sys_wdata[  16-1: 0] ;
      if (sys_addr[19:0]==20'h40)  set_b_rdly <= sys_wdata[  32-1: 0] ;

      if (sys_addr[19:0]==20'h44)  set_a_last <= sys_wdata[  14-1: 0] ;
      if (sys_addr[19:0]==20'h48)  set_b_last <= sys_wdata[  14-1: 0] ;
   end

   if (sys_ren) begin
      buf_a_rpnt_rd <= {{32-RSZ-2{1'b0}},buf_a_rpnt,2'h0};
      buf_b_rpnt_rd <= {{32-RSZ-2{1'b0}},buf_b_rpnt,2'h0};
   end

   ren_dly <= {ren_dly[3-2:0], sys_ren};
   ack_dly <=  ren_dly[3-1] || sys_wen ;
end

wire [32-1: 0] r0_rd = {7'h0,set_b_rgate, set_b_zero,set_b_rst,fina,set_b_wrap, 1'b0,trig_b_src,
                        7'h0,set_a_rgate, set_a_zero,set_a_rst,set_a_once,set_a_wrap, 1'b0,trig_a_src };

wire sys_en;
assign sys_en = sys_wen | sys_ren;

always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   sys_err <= 1'b0 ;
   sys_ack <= 1'b0 ;
end else begin
   sys_err <= 1'b0 ;

   casez (sys_addr[19:0])
     20'h00000 : begin sys_ack <= sys_en;          sys_rdata <= r0_rd                              ; end

     20'h00004 : begin sys_ack <= sys_en;          sys_rdata <= {2'h0, set_a_dc, 2'h0, set_a_amp}  ; end
     20'h00008 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_a_size}     ; end
     20'h0000C : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_a_ofs}      ; end
     20'h00010 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_a_step}     ; end
     20'h00014 : begin sys_ack <= sys_en;          sys_rdata <= buf_a_rpnt_rd                      ; end
     20'h00018 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_a_ncyc}         ; end
     20'h0001C : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_a_rnum}         ; end
     20'h00020 : begin sys_ack <= sys_en;          sys_rdata <= set_a_rdly                         ; end

     20'h00024 : begin sys_ack <= sys_en;          sys_rdata <= {2'h0, set_b_dc, 2'h0, set_b_amp}  ; end
     20'h00028 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_b_size}     ; end
     20'h0002C : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_b_ofs}      ; end
     20'h00030 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ-16{1'b0}},set_b_step}     ; end
     20'h00034 : begin sys_ack <= sys_en;          sys_rdata <= buf_b_rpnt_rd                      ; end
     20'h00038 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_b_ncyc}         ; end
     20'h0003C : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},set_b_rnum}         ; end
     20'h00040 : begin sys_ack <= sys_en;          sys_rdata <= set_b_rdly                         ; end

     20'h00044 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}},set_a_last}         ; end
     20'h00048 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}},set_b_last}         ; end

     20'h1zzzz : begin sys_ack <= ack_dly;         sys_rdata <= {buf_a_rdata}                      ; end
     20'h2zzzz : begin sys_ack <= ack_dly;         sys_rdata <= {buf_b_rdata}                      ; end

       default : begin sys_ack <= sys_en;          sys_rdata <=  32'h0                             ; end
   endcase
end



//incorporaciones de scope
//---------------------------------------------------------------------------------
//  Input filtering

wire [ 14-1: 0] adc_a_filt_in  ;
wire [ 14-1: 0] adc_a_filt_out ;
wire [ 14-1: 0] adc_b_filt_in  ;
wire [ 14-1: 0] adc_b_filt_out ;

reg  [ 18-1: 0] set_a_filt_aa  ;
reg  [ 25-1: 0] set_a_filt_bb  ;
reg  [ 25-1: 0] set_a_filt_kk  ;
reg  [ 25-1: 0] set_a_filt_pp  ;
reg  [ 18-1: 0] set_b_filt_aa  ;
reg  [ 25-1: 0] set_b_filt_bb  ;
reg  [ 25-1: 0] set_b_filt_kk  ;
reg  [ 25-1: 0] set_b_filt_pp  ;

assign adc_a_filt_in = adc_a_i ;
assign adc_b_filt_in = adc_b_i ;

//quito los filtros
//assign adc_a_def = control[4]?adc_a_filt_out : adc_a_i ;
//assign adc_b_def = control[4]?adc_b_filt_out : adc_b_i ;

assign adc_a_def = adc_a_i ;
assign adc_b_def = adc_b_i ;

red_pitaya_dfilt1 i_dfilt1_cha (
   // ADC
  .adc_clk_i   ( adc_clk_i       ),  // ADC clock
  .adc_rstn_i  ( adc_rstn_i      ),  // ADC reset - active low
  .adc_dat_i   ( adc_a_filt_in   ),  // ADC data
  .adc_dat_o   ( adc_a_filt_out  ),  // ADC data
   // configuration
  .cfg_aa_i    ( set_a_filt_aa   ),  // config AA coefficient
  .cfg_bb_i    ( set_a_filt_bb   ),  // config BB coefficient
  .cfg_kk_i    ( set_a_filt_kk   ),  // config KK coefficient
  .cfg_pp_i    ( set_a_filt_pp   )   // config PP coefficient
);

red_pitaya_dfilt1 i_dfilt1_chb (
   // ADC
  .adc_clk_i   ( adc_clk_i       ),  // ADC clock
  .adc_rstn_i  ( adc_rstn_i      ),  // ADC reset - active low
  .adc_dat_i   ( adc_b_filt_in   ),  // ADC data
  .adc_dat_o   ( adc_b_filt_out  ),  // ADC data
   // configuration
  .cfg_aa_i    ( set_b_filt_aa   ),  // config AA coefficient
  .cfg_bb_i    ( set_b_filt_bb   ),  // config BB coefficient
  .cfg_kk_i    ( set_b_filt_kk   ),  // config KK coefficient
  .cfg_pp_i    ( set_b_filt_pp   )   // config PP coefficient
);

//declaraciones de senyales
reg               adc_we_keep   ;
reg             set_avg_en    ;
reg   [  32-1: 0] set_dly       ;
reg  [ 14-1: 0] set_a_tresh  ;
reg  [ 14-1: 0] set_b_tresh  ;
reg  [ 17-1: 0] set_dec       ;
reg  [ 14-1: 0] set_a_hyst   ;
reg  [ 14-1: 0] set_b_hyst   ;
reg    [ 20-1: 0] set_deb_len   ; // debouncing length (glitch free time after a posedge)

reg             set_a_axi_en       ;
reg             set_b_axi_en       ;
reg  [ 32-1: 0] set_a_axi_start    ;
reg  [ 32-1: 0] set_a_axi_stop     ;
reg  [ 32-1: 0] set_a_axi_dly      ;
reg  [ 32-1: 0] set_b_axi_start    ;
reg  [ 32-1: 0] set_b_axi_stop     ;
reg  [ 32-1: 0] set_b_axi_dly      ;
reg               adc_dly_end   ;
reg               adc_we        ;
reg               adc_trg_rd    ;
reg   [   4-1: 0] set_trig_src     ;
reg   [ RSZ-1: 0] adc_wp_cur    ;
reg   [ RSZ-1: 0] adc_wp_trig   ;
reg   [  32-1: 0] adc_we_cnt    ;
reg   [  14-1: 0] adc_a_rd      ;
reg   [  14-1: 0] adc_b_rd      ;
reg  [ 32-1: 0] set_a_axi_trig     ;
reg  [ 32-1: 0] set_a_axi_cur      ;
reg  [ 32-1: 0] set_b_axi_trig     ;
reg  [ 32-1: 0] set_b_axi_cur      ;
//---------------------------------------------------------------------------------
//  System bus connection

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_we_keep   <=   1'b0      ;
   set_a_tresh   <=  14'd5000   ;
   set_b_tresh   <= -14'd5000   ;
   set_dly       <=  32'd0      ;
   set_dec       <=  17'd1      ;
   set_a_hyst    <=  14'd20     ;
   set_b_hyst    <=  14'd20     ;
   set_avg_en    <=   1'b1      ;
   set_a_filt_aa <=  18'h0      ;
   set_a_filt_bb <=  25'h0      ;
   set_a_filt_kk <=  25'hFFFFFF ;
   set_a_filt_pp <=  25'h0      ;
   set_b_filt_aa <=  18'h0      ;
   set_b_filt_bb <=  25'h0      ;
   set_b_filt_kk <=  25'hFFFFFF ;
   set_b_filt_pp <=  25'h0      ;
   set_deb_len   <=  20'd62500  ;
   set_a_axi_en  <=   1'b0      ;
   set_b_axi_en  <=   1'b0      ;
end else begin
   if (sys_wen2) begin
      if (sys_addr2[19:0]==20'h00)   adc_we_keep   <= sys_wdata2[     3] ;

      if (sys_addr2[19:0]==20'h08)   set_a_tresh   <= sys_wdata2[14-1:0] ;
      if (sys_addr2[19:0]==20'h0C)   set_b_tresh   <= sys_wdata2[14-1:0] ;
      if (sys_addr2[19:0]==20'h10)   set_dly       <= sys_wdata2[32-1:0] ;
      if (sys_addr2[19:0]==20'h14)   set_dec       <= sys_wdata2[17-1:0] ;
      if (sys_addr2[19:0]==20'h20)   set_a_hyst    <= sys_wdata2[14-1:0] ;
      if (sys_addr2[19:0]==20'h24)   set_b_hyst    <= sys_wdata2[14-1:0] ;
      if (sys_addr2[19:0]==20'h28)   set_avg_en    <= sys_wdata2[     0] ;

      if (sys_addr2[19:0]==20'h30)   set_a_filt_aa <= sys_wdata2[18-1:0] ;
      if (sys_addr2[19:0]==20'h34)   set_a_filt_bb <= sys_wdata2[25-1:0] ;
      if (sys_addr2[19:0]==20'h38)   set_a_filt_kk <= sys_wdata2[25-1:0] ;
      if (sys_addr2[19:0]==20'h3C)   set_a_filt_pp <= sys_wdata2[25-1:0] ;
      if (sys_addr2[19:0]==20'h40)   set_b_filt_aa <= sys_wdata2[18-1:0] ;
      if (sys_addr2[19:0]==20'h44)   set_b_filt_bb <= sys_wdata2[25-1:0] ;
      if (sys_addr2[19:0]==20'h48)   set_b_filt_kk <= sys_wdata2[25-1:0] ;
      if (sys_addr2[19:0]==20'h4C)   set_b_filt_pp <= sys_wdata2[25-1:0] ;

      if (sys_addr2[19:0]==20'h50)   set_a_axi_start <= sys_wdata2[32-1:0] ;
      if (sys_addr2[19:0]==20'h54)   set_a_axi_stop  <= sys_wdata2[32-1:0] ;
      if (sys_addr2[19:0]==20'h58)   set_a_axi_dly   <= sys_wdata2[32-1:0] ;
      if (sys_addr2[19:0]==20'h5C)   set_a_axi_en    <= sys_wdata2[     0] ;

      if (sys_addr2[19:0]==20'h70)   set_b_axi_start <= sys_wdata2[32-1:0] ;
      if (sys_addr2[19:0]==20'h74)   set_b_axi_stop  <= sys_wdata2[32-1:0] ;
      if (sys_addr2[19:0]==20'h78)   set_b_axi_dly   <= sys_wdata2[32-1:0] ;
      if (sys_addr2[19:0]==20'h7C)   set_b_axi_en    <= sys_wdata2[     0] ;

      if (sys_addr2[19:0]==20'h90)   set_deb_len <= sys_wdata2[20-1:0] ;
   end
end

wire sys_en2;
assign sys_en2 = sys_wen2 | sys_ren2;

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   sys_err2 <= 1'b0 ;
   sys_ack2 <= 1'b0 ;
end else begin
   sys_err2 <= 1'b0 ;

   casez (sys_addr2[19:0])
     20'h00000 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32- 5{1'b0}}, adc_dly_end               // acquisition delay is over
                                                                              , adc_we_keep               // do not disarm on 
                                                                              , adc_trg_rd                // trigger status
                                                                              , 1'b0                      // reset
                                                                              , adc_we}             ; end // arm

     20'h0000   : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32- 4{1'b0}}, set_trig_src}       ; end 

     20'h00008 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-14{1'b0}}, set_a_tresh}        ; end
     20'h0000C : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-14{1'b0}}, set_b_tresh}        ; end
     20'h00010 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {               set_dly}            ; end
     20'h00014 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-17{1'b0}}, set_dec}            ; end

     20'h00018 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-RSZ{1'b0}}, adc_wp_cur}        ; end
     20'h0001C : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-RSZ{1'b0}}, adc_wp_trig}       ; end

     20'h00020 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-14{1'b0}}, set_a_hyst}         ; end
     20'h00024 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-14{1'b0}}, set_b_hyst}         ; end

     20'h00028 : begin sys_ack2 <= sys_en2  ;          sys_rdata2 <= {{32- 1{1'b0}}, set_avg_en}         ; end

     20'h0002C : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 adc_we_cnt          ; end 
     20'h00030 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-18{1'b0}}, set_a_filt_aa}      ; end
     20'h00034 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-25{1'b0}}, set_a_filt_bb}      ; end
     20'h00038 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-25{1'b0}}, set_a_filt_kk}      ; end
     20'h0003C : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-25{1'b0}}, set_a_filt_pp}      ; end
     20'h00040 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-18{1'b0}}, set_b_filt_aa}      ; end
     20'h00044 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-25{1'b0}}, set_b_filt_bb}      ; end
     20'h00048 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-25{1'b0}}, set_b_filt_kk}      ; end
     20'h0004C : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-25{1'b0}}, set_b_filt_pp}      ; end

     20'h00050 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_a_axi_start     ; end
     20'h00054 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_a_axi_stop      ; end
     20'h00058 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_a_axi_dly       ; end
     20'h0005C : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32- 1{1'b0}}, set_a_axi_en}       ; end
     20'h00060 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_a_axi_trig      ; end
     20'h00064 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_a_axi_cur       ; end
     20'h00070 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_b_axi_start     ; end
     20'h00074 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_b_axi_stop      ; end
     20'h00078 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_b_axi_dly       ; end
     20'h0007C : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32- 1{1'b0}}, set_b_axi_en}       ; end
     20'h00080 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_b_axi_trig      ; end
     20'h00084 : begin sys_ack2 <= sys_en2;          sys_rdata2 <=                 set_b_axi_cur       ; end

     20'h00090 : begin sys_ack2 <= sys_en2;          sys_rdata2 <= {{32-20{1'b0}}, set_deb_len}        ; end

     20'h1???? : begin sys_ack2 <= adc_rd_dv;       sys_rdata2 <= {16'h0, 2'h0,adc_a_rd}              ; end
     20'h2???? : begin sys_ack2 <= adc_rd_dv;       sys_rdata2 <= {16'h0, 2'h0,adc_b_rd}              ; end

       default : begin sys_ack2 <= sys_en2;          sys_rdata2 <=  32'h0                              ; end
   endcase
end


//buffers de memoria que utilizaba el scope
//---------------------------------------------------------------------------------
//  ADC buffer RAM

reg   [  14-1: 0] adc_a_buf [0:(1<<RSZ)-1] ;
reg   [  14-1: 0] adc_b_buf [0:(1<<RSZ)-1] ;
reg buf_a_we2;
reg buf_b_we2;
reg   [ RSZ-1: 0] adc_raddr     ;
reg   [ RSZ-1: 0] adc_a_raddr   ;
reg   [ RSZ-1: 0] adc_b_raddr   ;

always @(posedge adc_clk_i) begin
   buf_a_we2   <= sys_wen2 && (sys_addr2[19:RSZ+2] == 'h1);
   buf_b_we2   <= sys_wen2 && (sys_addr2[19:RSZ+2] == 'h2);
   adc_raddr   <= sys_addr2[RSZ+1:2] ; // address synchronous to clock
   adc_a_raddr <= adc_raddr     ; // double register 
   adc_b_raddr <= adc_raddr     ; // otherwise memory corruption at reading
   adc_a_rd    <= adc_a_buf[adc_a_raddr] ;
   adc_b_rd    <= adc_b_buf[adc_b_raddr] ;
end
  always @(posedge adc_clk_i)
  begin
    if (buf_a_we2)
        adc_a_buf[sys_addr2[RSZ+1:2]]<=sys_wdata2[32-1:0];
    if (buf_b_we2)
        adc_b_buf[sys_addr2[RSZ+1:2]]<=sys_wdata2[32-1:0]; 
   end       
endmodule
