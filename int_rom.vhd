library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity int_rom is
port(
		clk      : in  std_logic;
		rst      : in  std_logic;
		rd       : in  std_logic;
		addr     : in  std_logic_vector (15 downto 0);
		data     : out std_logic_vector (7 downto 0)
);
end int_rom;

architecture Behavioral of int_rom is
	type rom_type is array (0 to 4095) of STD_LOGIC_VECTOR (7 downto 0);
	constant PROGRAM : ROM_TYPE := (
--	"00101000", --ADD A,R0
--	"10010000", --MOV DPTR, "FFAA"
--	"11111111",
--	"10101010",
--	"11010011", --SETB C
--	"11010010", --SETB 0EH
--	"00001110",
--	"10010010", --MOV 78H, C
--	"01111000",
--	"11000011", --CLR C
--	"10100010", --MOV C, 0EH
--	"00001110",
--	"11000010", --CLR 78H
--	"01111000",
	
	"01110100", --MOV A, #08
	"10101010",							-- ACC = #08
--	"11000100", --SWAP A
--	"11111101", --MOV R5, A			-- Band 2 - ram[21] = #08
--	"00100100",	--ADD A, #03		
--	"00000011",							-- ACC = #0B
--	"11110101", --MOV x70, A
--	"01110000",							-- ram[112] = #0B
--	"10101111", --MOV R7, x70
--	"01110000",							-- ram[23] = #0B
--	"10001101", --MOV x71, R5
--	"01110001",							-- ram[113] = #08
--	"10000101", --MOV x72, x71
--	"01110001",
--	"01110010",							-- ram[114] = #08
--	"01110101", --MOV xF0, #09
--	"11110000",
--	"00001001",							-- ram[115] = #90
	"01110101", --MOV x71, #F0
	"01110001",
	"11110000",	
--	"10101111", --MOV R7, x71
--	"01110001",
--	"10100100",	--MUL AB
--	"01110101", --MOV xF0, #09
--	"11110000",
--	"00001001",
--	"10000100", --DIV AB
--	"11010000", --PUSH x70
--	"01110000"
--	"01111000", --MOV R0, #70
--	"01110000",							-- ram[16] = #70
--	"10000110", --MOV x72, @R0
--	"01110010",							-- ram[114] = #0B
	"10100110", --MOV @R0, x71		
	"01110001",							-- ram[112] = #08
--	"11110110", --MOV @R0, A		-- ram[112] = #0B
--	"01110110", --MOV @R0, #11		-- ram[112] = #11
--	"00010001",
--	"11001000", --XCH A,R0
--	"01110100", --MOV A, #08		
--	"00001000",							-- ACC = #08
--	"11110101", --MOV x70, A
--	"01110000",							-- ram[112] = #08
--	"00100100",	--ADD A, #03
--	"00000011",							-- ACC = #0B
--	"01111000", --MOV R0, #70
--	"01110000",							-- ram[16] = #70
--	"11100110", --MOV A, @R0		-- ACC = #08
	
--	"00100100",	--ADD A, #03 		-- using band 2 register
--	"00000011",							-- ACC = #03
--	"11110101", --MOV x78, A
--	"01111000",							-- ram[120] = #03
--	"01111010", --MOV R2, #05
--	"00000101",							-- ram[18] = #05
--	"00101010", --ADD A, R2			-- ACC = #08
--	"11101010", --MOV A, R2			-- ACC = #05
--	"11100101", --MOV A, x78		-- ACC = #03
--	"01111000",
--	"11000110", --XCH A,@R0
--	"11000101", --XCH A,x71
--	"11001111", --XCH A,R7
--	"01010110", --ANL A,@R0
--	"01010100", --ANL A,#data
--	"11110000",
--	"01000100", --ORL A,#data
--	"10101010",
--	"01000110", --ORL A,@R0
	"01100110", --XRL A,@R0
--	"01110001",
--	"11010110", --XCHD @R0
--	"00101001", --ADD A,R1
--	"11101001", --LABEL1: MOV A,R1
--	"00100100", --ADD A,#01H
--	"00000001",
--	"11111001", --MOV R1,A
--	"10111001", --CJNE R1,#04H,LABEL1
--	"00000100",
--	"11111001",
--	"10001001", --MOV 90H,R1
--	"10010000",
	others => "00000000"
);

	begin

	process (rst, rd, addr)
	begin
		if( rst = '1' ) then
			data <= "--------";
		elsif( rd = '1' ) then
			data <= PROGRAM(conv_integer(addr));
		else
			data <= "--------";
		end if;
	end process;
end Behavioral;
