// Quartus II Verilog Template
// Single Port ROM

module memoria_dual_port
#(parameter DATA_WIDTH=20, parameter ADDR_WIDTH=12, parameter FICHERO_INICIAL="freq_log.dat")
(
	input [(ADDR_WIDTH-1):0] addr1,
    input [(ADDR_WIDTH-1):0] addr2,
	input clk, 
	input enable,
	output reg [(DATA_WIDTH-1):0] q1,
    output reg [(DATA_WIDTH-1):0] q2
);

	// Declare the ROM variable
	(*rom_style ="block" *) reg [DATA_WIDTH-1:0] rom[2**ADDR_WIDTH-1:0];

	// Initialize the ROM with $readmemb.  Put the memory contents
	// in the file single_port_rom_init.txt.  Without this file,
	// this design will not compile.
	// See Verilog LRM 1364-2001 Section 17.2.8 for details on the
	// format of this file.

	initial
	begin
		$readmemh(FICHERO_INICIAL, rom);
	end

	always @ (posedge clk)
	if (enable==1'b1)
    begin
		q1 <= rom[addr1];
        q2 <= rom[addr2];
    end
	

endmodule
