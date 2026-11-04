module radicador_64_32(
	CLK,
	START,
	RESET,
	X,
	FIN,
	COUNT
);


input wire	CLK;
input wire	START;
input wire	RESET;
input wire	[63:0] X;
output logic	FIN;
output logic	[31:0] COUNT;

enum logic [2:0] {idle,comp,inc,No_inc,finali} state;

logic start;


logic [4:0] Cont;
logic [63:0] a;
logic [31:0] q;
logic [33:0] left,right,r,temp;  

assign start=START;

always_ff @(posedge CLK, negedge RESET)
if (!RESET)
    begin
        left<='0;
        right<='0;
        r<='0;
        q<='0;
        a<='0;
        state<=idle;
        Cont<='0;
    end
else
case (state)
    idle: if (start)
            begin
               // left<='0;
               // right<='0;
                r<='0;
                q<='0;
                a<=X;
                Cont<='0;
                state<=comp;

            end
          else
            state<=idle;

    comp:
        begin
            Cont<=Cont+1;
            right = {q,r[33],1'b1};
            left = {r[31:0],a[63:62]};
            a <= {a[61:0],2'b00};    //left shift by 2 bits.            
            if (r[33] == 1) //add if r is negative
                temp= left + right;
            else    //subtract if r is positive
                temp= left - right;
            r<=temp;
            q <= {q[30:0],!temp[33]};   
            if (Cont==31)
                state<=finali;
            else
                state<=comp;
        end


    finali:
        if (!start)
            state<=idle;  
        else
            state<=finali;     
endcase
assign COUNT=q;
always_comb
case (state)
    finali: FIN=1'b1;
    default: FIN=1'b0;
endcase
endmodule