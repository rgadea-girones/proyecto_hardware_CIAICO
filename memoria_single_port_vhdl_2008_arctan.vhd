LIBRARY ieee;
USE ieee.std_logic_1164.all; 
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
--use ieee.fixed_float_types.all;
--library ieee_proposed;
use work.fixed_pkg.all;

--library ieee_proposed;
--use ieee_proposed.math_utility_pkg.all;
--use ieee_proposed.fixed_pkg.all;
--use ieee_proposed.float_pkg.all;

USE ieee.math_real.all;
entity memoria_single_port_mejorado is
	 generic (DATA_WIDTH: integer:=9;
				 ADDR_WIDTH: integer:=10;
				 
				 punto_entrada: integer:=4;
				 punto_salida: integer:=4
				 );
    port (clk:          in std_logic;
          addr:       in  std_logic_vector (ADDR_WIDTH-1 downto 0); 
          q:		       out std_logic_vector (DATA_WIDTH-1 downto 0)
          );
end memoria_single_port_mejorado;
ARCHITECTURE inferencia OF memoria_single_port_mejorado IS
CONSTANT TAMANYO:integer :=2**ADDR_WIDTH-1;
TYPE ROM IS ARRAY(0 TO TAMANYO) OF STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
FUNCTION INIT_ROM RETURN ROM IS
VARIABLE romvar: ROM;
VARIABLE x: real;
VARIABLE temp: real;
constant idea: real :=57.2957;
begin
 for I in 0 TO TAMANYO loop
         x:= ARCTAN(to_real(to_ufixed(CONV_STD_LOGIC_VECTOR(i,ADDR_WIDTH),ADDR_WIDTH-1-punto_entrada,-punto_entrada)));
			temp:=x*idea;
         romvar(i):=to_slv(to_ufixed(temp,DATA_WIDTH-1-punto_salida,-punto_salida));	 	 
  end loop;
  return romvar;
end;

CONSTANT memoria: ROM := INIT_ROM;
attribute rom_style: string;
attribute rom_style of memoria: constant is "block";



BEGIN
memory:process(clk)
begin
    if clk'event and clk='1' then
        q<=memoria(conv_integer(addr));
    end if;
end process;
END inferencia;

