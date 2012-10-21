library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.constants.all;

entity sequencer2 is
    port(
		rst                : in  std_logic;
		clk              	 : in  std_logic;
		ale		  	 : out std_logic;
		psen		 	 : out std_logic;

		alu_op_code	 	 : out  std_logic_vector (3 downto 0);
		alu_src_1L		 : out  std_logic_vector (7 downto 0);
		alu_src_1H		 : out  std_logic_vector (7 downto 0);
		alu_src_2L		 : out  std_logic_vector (7 downto 0);
		alu_src_2H		 : out  std_logic_vector (7 downto 0);
		alu_by_wd		 : out  std_logic;             -- byte(0)/word(1) instruction
		alu_cy_bw		 : out  std_logic;             -- carry/borrow bit
		alu_ans_L		 : in std_logic_vector (7 downto 0);
		alu_ans_H		 : in std_logic_vector (7 downto 0);
		alu_cy		 	 : in std_logic;             -- carry out of bit 7/15
		alu_ac		 	 : in std_logic;		    -- carry out of bit 3/7
		alu_ov		 	 : in std_logic;		    -- overflow

		dividend_i		 : out  std_logic_vector(15 downto 0);
		divisor_i		 : out  std_logic_vector(15 downto 0);
		quotient_o		 : in std_logic_vector(15 downto 0); 
		remainder_o	 	 : in std_logic_vector(15 downto 0);
		div_done		 : in std_logic ;

		mul_a_i		 	 : out  std_logic_vector(15 downto 0);  -- Multiplicand
		mul_b_i		 	 : out  std_logic_vector(15 downto 0);  -- Multiplicator
		mul_prod_o 	 	 : in std_logic_vector(31 downto 0) ;-- Product

		i_ram_wrByte   	 : out std_logic; 
		i_ram_wrBit   	 : out std_logic; 
		i_ram_rdByte   	 : out std_logic; 
		i_ram_rdBit   	 : out std_logic; 
		i_ram_addr 	 	 : out std_logic_vector(7 downto 0); 
		i_ram_diByte  	 : out std_logic_vector(7 downto 0); 
		i_ram_diBit   	 : out std_logic; 
		i_ram_doByte   	 : in std_logic_vector(7 downto 0); 
		i_ram_doBit   	 : in std_logic; 
		
		i_rom_addr       : out std_logic_vector (15 downto 0);
		i_rom_data       : in  std_logic_vector (7 downto 0);
		i_rom_rd         : out std_logic;
		
		pc_debug	 	 : out std_logic_vector (15 downto 0);
		interrupt_flag	 : in  std_logic_vector (2 downto 0);
		erase_flag	 : out std_logic);

end sequencer2;

-------------------------------------------------------------------------------

architecture seq_arch of sequencer2 is
	
	type t_machine_cycle is (M1, M2, M3, M4); --determine which machine cycles the processor is in
   type t_cpu_state is (T0, T1, S1, S2, S3, S4, S5, S6, I0); --these determine whether you are in initialisation, state, normal execution state, etc
   type t_exe_state is (P1, P2, E0, E1, E2, E3, E4, E5, E6, E7, E8, E9, E10); --these are the equivalence T0, T1 in the lecture
    
	signal cpu_state 		: t_cpu_state;
   signal exe_state 		: t_exe_state;
	signal machine_cycle : t_machine_cycle;
   
	signal IR				: std_logic_vector(7 downto 0);		-- Instruction Register
	
	signal PC				: std_logic_vector(15 downto 0);		-- Program Counter
	signal AR				: std_logic_vector(7 downto 0);		-- Address Register
	signal DR				: std_logic_vector(7 downto 0);		-- Data Register
	signal ACC				: std_logic_vector(7 downto 0);		-- Accummulator
	signal PSW				: std_logic_vector(7 downto 0);
	signal int_hold		: std_logic;
	
	
	
begin

   process(rst, clk)
	
		variable tmp		: std_logic_vector(7 downto 0);	-- temporary data storage
		variable tmp2		: std_logic_vector(7 downto 0);
		
	
		procedure ROM_RD_START (addr: std_logic_vector(15 downto 0)) is
		begin
			i_rom_addr 	<= addr;
			i_rom_rd 	<= '1';
		end ROM_RD_START;

		procedure ROM_STOP is
		begin
			i_rom_rd <= '0';
		end ROM_STOP;
		
		procedure RAM_RD_BYTE_START (addr: std_logic_vector(7 downto 0)) is
		begin
			i_ram_rdByte 	<= '1';
			i_ram_wrByte 	<= '0';
			i_ram_rdBit 	<= '0';
			i_ram_wrBit 	<= '0';
			i_ram_addr 		<= addr;
		end RAM_RD_BYTE_START;
		
		procedure RAM_RD_BIT_START (addr: std_logic_vector(7 downto 0)) is
		begin
			i_ram_rdByte 	<= '0';
			i_ram_wrByte 	<= '0';
			i_ram_rdBit 	<= '1';
			i_ram_wrBit 	<= '0';
			i_ram_addr 		<= addr;
		end RAM_RD_BIT_START;
		
		procedure RAM_WR_BYTE_START (addr, data: std_logic_vector(7 downto 0)) is
		begin
			i_ram_rdByte 	<= '0';
			i_ram_wrByte 	<= '1';
			i_ram_rdBit 	<= '0';
			i_ram_wrBit 	<= '0';
			i_ram_addr 		<= addr;
			i_ram_diByte	<= data;
		end RAM_WR_BYTE_START;
		
		procedure RAM_WR_BIT_START (addr: std_logic_vector(7 downto 0); data: std_logic) is
		begin
			i_ram_rdByte 	<= '0';
			i_ram_wrByte 	<= '0';
			i_ram_rdBit 	<= '0';
			i_ram_wrBit 	<= '1';
			i_ram_addr 		<= addr;
			i_ram_diBit		<= data;
		end RAM_WR_BIT_START;
		
		procedure RAM_STOP is
		begin
			i_ram_rdByte 	<= '0';
			i_ram_wrByte 	<= '0';
			i_ram_rdBit 	<= '0';
			i_ram_wrBit 	<= '0';
		end RAM_STOP;
			
		procedure UPDATE_PSW is
		begin
			PSW(2) <= alu_ov;
			PSW(6) <= alu_ac;
			PSW(7) <= alu_cy;
		end UPDATE_PSW;
	
    begin
    if( rst = '1' ) then
   	--cpu_state <= T0;
		--exe_state <= E0;
		cpu_state <= S1;
		exe_state <= P1;
		machine_cycle <= M1;
		ale <= '0'; psen <= '0';
		mul_a_i <= (others => '0'); mul_b_i <= (others => '0');
		dividend_i <= (others => '0'); divisor_i <= (others => '1');
		i_ram_wrByte <= '0'; i_ram_rdByte <= '0'; i_ram_wrBit <= '0'; i_ram_rdBit <= '0';
		IR <= (others => '0');
		PC <= (others => '0');
		--PC <= "0000000000100111";
		AR <= (others => '0');
		DR <= (others => '0');
		pc_debug <= (others => '1');
		int_hold <= '0';
		erase_flag <= '0';	
    elsif (clk'event and clk = '1') then
	 ----------------------------------------------------------
	 --			NEW CODE													--
	 ----------------------------------------------------------
	 if (machine_cycle = M1 and cpu_state = S1) then -- This is the same for every instruction
			case exe_state is
				when P1	=>
					ROM_RD_START(PC);
					exe_state <= P2;	
							
				when P2	=> 	
					IR <= i_rom_data;
					PC <= PC + 1;
					ROM_STOP;
					exe_state <= P1;
					cpu_state <= S2;

				when others =>	  
			end case;  
	 else 
			case IR is
			
				-- NOP
				when "00000000"  =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
					
				-- ADD A,Rn
				-- 1 byte, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when  "00101000" | 
						"00101001" | 
						"00101010" | 
						"00101011" | 
						"00101100" | 
						"00101101" | 
						"00101110" | 
						"00101111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START("000" & i_ram_doByte(4 downto 3) & IR(2 downto 0));
											PSW <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"E0");
											DR <= i_ram_doByte;
											exe_state <= P2;
										
										when P2	=>
											alu_src_1L <= i_ram_doByte;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_ADD;
											alu_by_wd <= '0';
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											UPDATE_PSW;
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_STOP;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- ADD A, #data
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "00100100" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START(x"E0");
											PSW <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											ACC <= i_ram_doByte;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => 
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_ADD;
											alu_by_wd <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											UPDATE_PSW;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV A, Rn
				-- 1 byte, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when  "11101000" | 
						"11101001" | 
						"11101010" | 
						"11101011" | 
						"11101100" | 
						"11101101" | 
						"11101110" | 
						"11101111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START("000" & i_ram_doByte(4 downto 3) & IR(2 downto 0));
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"E0", i_ram_doByte);
											DR <= i_ram_doByte;
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV A, direct
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11100101" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"E0", DR);
											exe_state <= P2;
										
										when P2	=>
										   RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV A, @Ri
				-- 1 byte, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11100110" | "11100111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START("000" & i_ram_doByte(4 downto 3) & "00" & IR(0));
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(i_ram_doByte);
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", i_ram_doByte);
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_STOP;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
				
				-- MOV A, #data
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "01110100" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"E0", DR);
											exe_state <= P2;
										
										when P2	=>
										   RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV Rn, A
				-- 1 byte, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when  "11111000" | 
						"11111001" | 
						"11111010" | 
						"11111011" | 
						"11111100" | 
						"11111101" | 
						"11111110" | 
						"11111111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START(x"D0");
											ACC <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START("000" & i_ram_doByte(4 downto 3) & IR(2 downto 0), ACC);
											DR <= i_ram_doByte;
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV Rn, direct
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when  "10101000" | 
						"10101001" | 
						"10101010" | 
						"10101011" | 
						"10101100" | 
						"10101101" | 
						"10101110" | 
						"10101111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0), DR);
											exe_state <= P2;
										
										when P2	=>
										   RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											exe_state <= P2;
											
										when P2 =>
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV Rn, #data
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when  "01111000" |  
						"01111001" |  
						"01111010" |  
						"01111011" |  
						"01111100" |  
						"01111101" |  
						"01111110" | 
						"01111111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => 
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0), DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
				
				-- MOV direct, A
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11110101" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P2;
										
										when P2	=>
											ACC <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => 
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(AR, ACC);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
				
				-- MOV direct, Rn
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when  "10001000" | 
						"10001001" | 
						"10001010" | 
						"10001011" | 
						"10001100" | 
						"10001101" | 
						"10001110" | 
						"10001111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0));
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(AR, DR);
											exe_state <= P2;
										
										when P2	=>
										   RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											exe_state <= P2;
											
										when P2 =>
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV direct, direct
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "10000101" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											ROM_RD_START(PC);
											exe_state <= P2;
											
										when P2 =>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(AR, DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV direct, @Ri
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "10000110" | "10000111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START("000" & PSW(4 downto 0) & IR(2 downto 0));
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											exe_state <= P2;
											
										when P2 =>
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(DR); -- read the value stored in the address specified by Ri
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(AR, DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV direct, #data
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "01110101" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											ROM_RD_START(PC);
											exe_state <= P2;
											
										when P2 =>
											PC <= PC + 1;
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(AR, DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV @Ri, A
				-- 1 byte, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11110110" | "11110111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0)); -- read value of Ri
											exe_state <= P2;
										
										when P2	=>
											AR <= i_ram_doByte;	-- the value is the address we need to store into
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(AR, i_ram_doByte);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
				
				-- MOV @Ri, direct
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "10100110" | "10100111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											exe_state <= P2;
											
										when P2 =>
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0)); -- read Ri
											exe_state <= P2;
										
										when P2	=>
											AR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(AR, DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV @Ri, #data
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "01110110" | "01110111" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => 
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0)); -- Read Ri
											exe_state <= P2;
										
										when P2	=>
											AR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(AR, DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV C, bit
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "10100010" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => 
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BIT_START(AR); -- Read Ri
											exe_state <= P2;
										
										when P2	=>
											PSW(7) <= i_ram_doBit;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV bit, C
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "10010010" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											RAM_WR_BIT_START(AR, PSW(7));
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											exe_state <= P2;
											
										when P2 =>
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MOV DPTR, #data16
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "10010000" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"83", DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M2; -- this is 2 cylces instruction
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when M2 =>
							case cpu_state is
								when S1 =>
									case exe_state is
										when P1 =>
											ROM_RD_START(PC);
											exe_state <= P2;
											
										when P2 =>
											PC <= PC + 1;
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"82", DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- CLR C
				-- 1 byte, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11000011" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											PSW(7) <= '0';
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- CLR bit
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11000010" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => 
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START(AR, '0');
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- SETB C
				-- 1 byte, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11010011" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											PSW(7) <= '1';
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- SETB bit
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11010010" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => 
									case exe_state is
										when P1	=>  
											ROM_RD_START(PC);
											exe_state <= P2;
										
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START(AR, '1');
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				when others =>
			end case; -- end case IR
	 end if;
	 ----------------------------------------------------------
	 --			OLD CODE													--
	 ----------------------------------------------------------
--    case cpu_state is
--		when T0 =>
--			case exe_state is
--				when E0	=>
--					ROM_RD_START(PC);
--					exe_state <= E1;	
--							
--				when E1	=> 	
--					IR <= i_rom_data;
--					PC <= PC + 1;
--					ROM_STOP;
--					exe_state <= E0;
--					cpu_state <= T1;
--
--				when others =>	  
--			end case;  
--
--		when T1 =>
--			case IR is 
--			
--				-- NOP
--				when "00000000"  =>
--					case exe_state is
--						when E0	=>  
--							exe_state <= E1;
--						
--						when E1	=>
--							exe_state <= E2;
--							
--						when E2	=>						
--							exe_state <= E0;
--							cpu_state <= T0;
--						when others =>
--					end case;  
--				
--				-- ADD A,Rn
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				
--				when  "00101000" | 
--						"00101001" | 
--						"00101010" | 
--						"00101011" | 
--						"00101100" | 
--						"00101101" | 
--						"00101110" | 
--						"00101111" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"E0");
--							exe_state <= E1;
--						
--						when E1 => 
--							alu_src_1L <= i_ram_doByte;
--							i_ram_addr <= x"D0";
--							exe_state <= E2;
--							
--						when E2 =>
--							PSW <= i_ram_doByte;
--							exe_state <= E3;
--							
--						when E3 => 
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & IR(2 downto 0));	-- Read Rn
--							exe_state <= E4;
--							
--						when E4 =>
--							alu_src_2L <= i_ram_doByte;
--							alu_op_code <= ALU_OPC_ADD;
--							alu_by_wd <= '0';
--							exe_state <= E5;
--							
--						when E5 =>
--							RAM_WR_BYTE_START(x"E0", alu_ans_L);
--							UPDATE_PSW;
--							exe_state <= E6;
--							
--						when E6 =>
--							RAM_WR_BYTE_START(x"D0", PSW);
--							exe_state <= E7;
--							
--						when E7 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--							
--						when others =>
--					end case; -- end case exe_state
--				
--				-- ADD A, #data
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "00100100" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"E0");
--							exe_state <= E1;
--						
--						when E1 =>
--							PC <= PC + 1;
--							
--							alu_src_1L <= i_ram_doByte;
--							alu_src_2L <= i_rom_data;
--							alu_op_code <= ALU_OPC_ADD;
--							alu_by_wd <= '0';
--							
--							RAM_RD_BYTE_START(x"D0");
--							
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							PSW <= i_ram_doByte;
--							
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(x"E0", alu_ans_L);
--							UPDATE_PSW;
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_WR_BYTE_START(x"D0", PSW);
--							exe_state <= E5;
--						
--						when E5 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--							
--						when others =>
--					end case;
--					
--					
--				-- MOV A, Rn
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when  "11101000" | 
--						"11101001" | 
--						"11101010" | 
--						"11101011" | 
--						"11101100" | 
--						"11101101" | 
--						"11101110" | 
--						"11101111" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"D0");		-- Read PSW
--							exe_state <= E1;
--						
--						when E1 =>
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & IR(2 downto 0));		-- Read Rn
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(x"E0", i_ram_doByte);
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- MOV A, direct
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				-- Question: should we check MOV A,ACC?
--				when "11100101" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							RAM_RD_BYTE_START(i_rom_data);
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							RAM_WR_BYTE_START(x"E0", i_ram_doByte);
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- MOV A, @Ri
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "11100110" | "11100111" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & "00" & IR(0));
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_RD_BYTE_START(i_ram_doByte);
--							exe_state <= E4;
--							
--						when E4 =>
--							tmp := i_ram_doByte;
--							exe_state <= E5;
--							
--						when E5 =>
--							RAM_WR_BYTE_START(x"E0", tmp);
--							exe_state <= E6;
--							
--						when E6 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--							
--						when others =>
--					end case;
--					
--				-- MOV A, #data
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "01110100" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);		-- Read the data from PC
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							RAM_WR_BYTE_START(x"E0", i_rom_data);
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- MOV Rn, A ************************
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when  "11111000" | 
--						"11111001" | 
--						"11111010" | 
--						"11111011" | 
--						"11111100" | 
--						"11111101" | 
--						"11111110" | 
--						"11111111" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PSW <= i_ram_doByte;
--							RAM_RD_BYTE_START(x"E0");
--							exe_state <= E2;
--							
--						when E2 =>
--							RAM_WR_BYTE_START("000" & PSW(4) & PSW(3) & IR(2 downto 0), i_ram_doByte);
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- MOV Rn, direct
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when  "10101000" | 
--						"10101001" | 
--						"10101010" | 
--						"10101011" | 
--						"10101100" | 
--						"10101101" | 
--						"10101110" | 
--						"10101111" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							PSW <= i_ram_doByte;
--							RAM_RD_BYTE_START(i_rom_data);
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							RAM_WR_BYTE_START("000" & PSW(4) & PSW(3) & IR(2 downto 0), i_ram_doByte);
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--							
--						when others =>
--					end case;
--				
--				-- MOV Rn, #data
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when  "01111000" |  
--						"01111001" |  
--						"01111010" |  
--						"01111011" |  
--						"01111100" |  
--						"01111101" |  
--						"01111110" | 
--						"01111111" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);			-- 2 bytes  instruction, read another bytes from ROM
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							DR <= i_rom_data;			-- store the immediate data in DR
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							RAM_WR_BYTE_START("000" & PSW(4) & PSW(3) & IR(2 downto 0), DR);  -- Address of the register that immediate data will be load into		
--							ROM_STOP;
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- MOV direct, A
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "11110101" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"E0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							tmp := i_rom_data;
--							ACC <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							RAM_WR_BYTE_START(tmp, ACC);
--							exe_state <= E3;
--						
--						when E3 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- MOV direct, Rn
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when  "10001000" | 
--						"10001001" | 
--						"10001010" | 
--						"10001011" | 
--						"10001100" | 
--						"10001101" | 
--						"10001110" | 
--						"10001111" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & IR(2 downto 0));
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(i_rom_data, i_ram_doByte);
--							exe_state <= E4;
--							
--						when E4 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- MOV direct, direct
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "10000101" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							RAM_RD_BYTE_START(i_rom_data);
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_RD_START(PC);
--							
--							tmp := i_ram_doByte;
--							exe_state <= E3;
--							
--						when E3 =>
--							PC <= PC + 1;
--							
--							RAM_WR_BYTE_START(i_rom_data, tmp);
--							exe_state <= E4;
--							
--						when E4 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- MOV direct, @Ri
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "10000110" | "10000111" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & "00" & IR(0));  -- read the data stored in Ri
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_RD_BYTE_START(i_ram_doByte);	 -- read the data stored in the addresss specified by Ri
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_WR_BYTE_START(i_rom_data, i_ram_doByte);		
--							exe_state <= E5;
--							
--						when E5 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- MOV direct, #data
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "01110101" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							tmp := i_rom_data;	-- temporarily store direct addr in tmp
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_RD_START(PC);
--							exe_state <= E3;
--							
--						when E3 =>
--							PC <= PC + 1;
--							
--							RAM_WR_BYTE_START(tmp, i_rom_data);
--							exe_state <= E4;
--							
--						when E4 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- MOV @Ri, A
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "11110110" | "11110111" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"E0");
--							exe_state <= E1;
--							
--						when E1 =>
--							ACC <= i_ram_doByte;
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E2;
--							
--						when E2 =>
--							PSW <= i_ram_doByte;
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & "00" & IR(0)); -- Read the value of Ri
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_WR_BYTE_START(i_ram_doByte, ACC);	-- value of Ri will be the address that ACC will be copied into
--							exe_state <= E5;
--							
--						when E5 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- MOV @Ri, direct
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "10100110" | "10100111" =>
--					case exe_state is 
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							PSW <= i_ram_doByte;
--							RAM_RD_BYTE_START(i_rom_data);	-- Read the value stored in the direct address
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							tmp := i_ram_doByte;	 -- Temporarily store the value in tmp
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & "00" & IR(0)); -- Read the value of Ri
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(i_ram_doByte, tmp);
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- MOV @Ri, #data
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "01110110" | "01110111" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							PSW <= i_ram_doByte;
--							tmp := i_rom_data;
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							RAM_RD_BYTE_START("000" & PSW(4) & PSW(3) & "00" & IR(0)); -- Read the value of Ri
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(i_ram_doByte, tmp);
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- MOV DPTR, #data16
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "10010000" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							RAM_WR_BYTE_START(x"83", i_rom_data);
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_RD_START(PC);
--							exe_state <= E3;
--							
--						when E3 =>
--							PC <= PC + 1;
--							
--							RAM_WR_BYTE_START(x"82", i_rom_data);
--							exe_state <= E4;
--							
--						when E4 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--				
--				-- MOV C, bit
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "10100010" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							PSW <= i_ram_doByte;
--							RAM_RD_BIT_START(i_rom_data);
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--
--							PSW(7) <= i_ram_doBit;
--							exe_state <= E3;
--						
--						when E3 =>
--							RAM_WR_BYTE_START(x"D0", PSW);
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--							
--						when others =>
--					end case;
--				
--				-- MOV bit, C
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "10010010" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							ROM_RD_START(PC);
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							PC <= PC + 1;
--							
--							RAM_WR_BIT_START(i_rom_data, PSW(7));
--							exe_state <= E3;
--							
--						when E3 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- CLR C
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "11000011" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							PSW(7) <= '0';
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(x"D0", PSW);
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- CLR bit
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "11000010" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							RAM_WR_BIT_START(i_rom_data, '0');
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- SETB C
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "11010011" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"D0");
--							exe_state <= E1;
--							
--						when E1 =>
--							PSW <= i_ram_doByte;
--							exe_state <= E2;
--							
--						when E2 =>
--							PSW(7) <= '1';
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(x"D0", PSW);
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--							
--					
--						when others =>
--					end case;
--					
--				-- SETB bit
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Simulated
--				when "11010010" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							RAM_WR_BIT_START(i_rom_data, '1');
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_STOP;
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--						
--						when others =>
--					end case;
--					
--				-- ACALL addr11
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Not Simulated
--				when  "00010001" |
--						"00110001" |
--						"01010001" |
--						"01110001" |
--						"10010001" |
--						"10110001" |
--						"11010001" |
--						"11110001" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							RAM_RD_BYTE_START(x"81");
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							AR <= i_ram_doByte + 1;
--							DR <= i_rom_data;
--							exe_state <= E2;
--						
--						when E2 =>
--							RAM_WR_BYTE_START(AR, PC(7 downto 0));
--							AR <= AR + 1;
--							ROM_STOP;
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_WR_BYTE_START(AR, PC(15 downto 8));
--							PC(10 downto 0) <= IR(7 downto 5) & DR;
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				-- LCALL addr16
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Not Simulated
--				when "00010010" =>
--					case exe_state is
--						when E0 =>
--							ROM_RD_START(PC);
--							exe_state <= E1;
--							
--						when E1 =>
--							PC <= PC + 1;
--							
--							DR <= i_rom_data;
--							RAM_RD_START(x"81");
--							exe_state <= E2;
--							
--						when E2 =>
--							ROM_RD_START(PC);
--							AR <= i_ram_doByte + 1;
--							exe_state <= E3;
--							
--						when E3 =>
--							PC <= PC + 1;
--							
--							exe_state <= E4;
--							
--						when E4 =>
--							RAM_WR_BYTE_START(AR, PC(7 downto 0));
--							AR <= AR+1;
--							PC(7 downto 0) <= i_rom_data;
--							exe_state <= E5;
--							
--						when E5 =>
--							ROM_STOP;
--							RAM_WR_BYTE_START(AR, PC(15 downto 8));
--							PC(15 downto 8) <= DR;
--							
--						when E6 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--												
--						when others =>
--					end case;
--					
--				-- RET
--				-- Author: Tran Phuoc Dang Khoa
--				-- Status: Not Simulated
--				when "00100010" =>
--					case exe_state is
--						when E0 =>
--							RAM_RD_BYTE_START(x"81");
--							exe_state <= E1;
--							
--						when E1 =>
--							AR <= i_ram_doByte;
--							RAM_RD_BYTE_START(i_ram_doByte);
--							exe_state <= E2;
--							
--						when E2 =>
--							AR <= AR - 1;
--							PC(15 downto 8) <= i_ram_doByte;
--							exe_state <= E3;
--							
--						when E3 =>
--							RAM_RD_BYTE_START(AR);
--							AR <= AR - 1;
--							exe_state <= E4;
--							
--						when E4 =>
--							PC(7 downto 0) <= i_ram_doByte;
--							exe_state <= E5;
--							
--						when E5 =>
--							RAM_STOP;
--							exe_state <= E0;
--							cpu_state <= T0;
--					
--						when others =>
--					end case;
--					
--				
--				
--				when others =>
--			end case;	
--		
--		when I0 =>
	




--			when others => 		exe_state <= E0;	
--										cpu_state <= T0;
--    
--		end case; --cpu_state

end if;
end process;
end seq_arch;

-------------------------------------------------------------------------------

-- end of file --
