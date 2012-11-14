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
	signal GR 				: std_logic_vector(7 downto 0); 	-- Gaurav's Register
	signal ACC				: std_logic_vector(7 downto 0);		-- Accummulator
	signal PSW				: std_logic_vector(7 downto 0);
	signal int_hold		: std_logic;
	
	
	
begin

   process(rst, clk)
	
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
--					if (int_hold = '0') then	-- Interrupts are enabled
--						case interrupt_flag is
--							when "001" | "010" | "011" | "100" | "101" =>
--								int_hold <= '1';	-- disable interrupt
--								exe_state <= P1;
--								cpu_state <= I0;	-- jump into interrupt service routine
--							when others =>			-- no interrupt
--								ROM_RD_START(PC);	-- fetch and decode instruction
--								exe_state <= P2;	
--						end case;
--					else
						ROM_RD_START(PC);	-- fetch and decode instruction
						exe_state <= P2;	
--					end if;
							
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

				-- ADD A, direct
				-- 2 bytes, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when "00100101" =>
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
											RAM_RD_BYTE_START(i_rom_data);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
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


				

				-- ADDC A,Rn
				-- 1 byte, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "00111000" |
						"00111001" |
						"00111010" |
						"00111011" |
						"00111100" |
						"00111101" |
						"00111110" |
						"00111111" =>
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
											alu_op_code <= ALU_OPC_ADC;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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

				-- ADDC A, direct
				-- 2 bytes, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when "00110101" =>
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
											RAM_RD_BYTE_START(i_rom_data);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_ADC;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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


				
	
				-- ADDC A, #data
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "00110100" =>
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
											alu_op_code <= ALU_OPC_ADC;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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

				-- SUBB A,Rn
				-- 1 byte, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "10011000" |
						"10011001" |
						"10011010" |
						"10011011" |
						"10011100" |
						"10011101" |
						"10011110" |
						"10011111" =>
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
											alu_op_code <= ALU_OPC_SBB;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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

				-- SUBB A, direct
				-- 2 bytes, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when "10010101" =>
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
											RAM_RD_BYTE_START(i_rom_data);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_SBB;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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


				
	
				-- SUBB A, #data
				-- 2 bytes, 1 cycle
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "10010100" =>
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
											alu_op_code <= ALU_OPC_SBB;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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

				
				
			
			 -- DEC A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00010100" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
                            RAM_RD_BYTE_START(x"E0");
                            exe_state <= P2; 
                        when P2 => 
                            alu_src_1L <= i_ram_doByte;
                            alu_src_2L <= "00000001";
									 alu_op_code <= ALU_OPC_SUB;    
                            alu_by_wd <= '0';
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
                            RAM_WR_BYTE_START(x"E0", alu_ans_L);
                            exe_state <= P2;
                        when P2 => 
                            RAM_STOP;
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle			


			 -- DEC Rn
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00011000" | "00011001" | "00011010" | "00011011" | "00011100" | "00011101" | "00011110" | "00011111" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
                            RAM_RD_BYTE_START(x"D0");
                            exe_state <= P2; 
                        when P2 =>  
									 PSW <= i_ram_doByte;
                            RAM_RD_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0));
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
                            alu_src_1L <= i_ram_doByte;
                            alu_src_2L <= "00000001";
									 alu_op_code <= ALU_OPC_SUB;    
                            alu_by_wd <= '0';
                            exe_state <= P2;
                        when P2 =>
									 RAM_WR_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0), alu_ans_L);
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
									 RAM_STOP;
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle	

				-- DEC direct
				-- 2 bytes, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				
				when "00010101" =>
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
											--ROM_STOP;
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
											alu_src_1L <= i_ram_doByte; -- direct byte
											alu_src_2L <= "00000001";
											alu_op_code <= ALU_OPC_SUB;    
											alu_by_wd <= '0';
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(i_rom_data, alu_ans_L); 
											exe_state <= P2;
										
										when P2	=>
										   RAM_STOP;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state

						when others =>
					end case; -- end case machine cycle
							
				--	DEC @Ri
				-- 1 byte, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				
				when "00010110" | "00010111" =>
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
											AR <= i_ram_doByte;
											RAM_RD_BYTE_START(i_ram_doByte);
											exe_state <= P2;
										
										when P2	=>
											alu_src_1L <= i_ram_doByte; -- (Ri)
											alu_src_2L <= "00000001";
											alu_op_code <= ALU_OPC_SUB;    
											alu_by_wd <= '0';
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
											RAM_WR_BYTE_START(AR, alu_ans_L);
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

				-- INC DPTR
				-- 1 byte, 2 cycles
				-- Author: Akash Ranka
				-- Status: Simulated
				when "10100011" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"82");
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
											RAM_RD_BYTE_START(x"83");
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											alu_src_1L <= DR;
											alu_src_1H <= i_ram_doByte;
											alu_src_2L <= "00000001";
											alu_src_2H <= "00000000";
											alu_op_code <= ALU_OPC_ADD; 
											alu_by_wd <= '1';
											alu_cy_bw <= '0';
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
								when S1 =>	-- 1 byte instruction, do nothing
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
											RAM_WR_BYTE_START(x"82", alu_ans_L);
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"83", alu_ans_H);
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing
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

			 -- CLR A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "11100100" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
                            exe_state <= P2; 
                        when P2 =>
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
									 RAM_WR_BYTE_START(x"E0", x"00");
                            exe_state <= P2;
                        when P2 => 
                            RAM_STOP;
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle		

			 -- CPL A
			 -- 1 byte, 1 cycle
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "11110100" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
									 RAM_RD_BYTE_START(x"E0");
                            exe_state <= P2; 
                        when P2 =>
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
									 RAM_WR_BYTE_START(x"E0", not(i_ram_doByte));
                            exe_state <= P2;
                        when P2 =>
									 RAM_STOP;
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle		

			 -- SWAP A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "11000100" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
									 RAM_RD_BYTE_START(x"E0");
                            exe_state <= P2; 
                        when P2 =>
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
									 RAM_WR_BYTE_START(x"E0", i_ram_doByte(3 downto 0) & i_ram_doByte(7 downto 4));
                            exe_state <= P2;
                        when P2 =>
									 RAM_STOP;
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle	
			
			 -- RL A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00100011" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
								    RAM_RD_BYTE_START(x"E0");
                            exe_state <= P2; 
                        when P2 =>
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
									 RAM_WR_BYTE_START(x"E0", i_ram_doByte(6 downto 0) & i_ram_doByte(7));
                            exe_state <= P2;
                        when P2 =>
									 RAM_STOP;
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle	
			
			 -- RLC A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00110011" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
								    RAM_RD_BYTE_START(x"D0");
                            exe_state <= P2; 
                        when P2 =>
                            PSW <= i_ram_doByte;
                            RAM_RD_BYTE_START(x"E0");
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
                            RAM_WR_BYTE_START(x"E0", i_ram_doByte(6 downto 0) & PSW(7));
                            DR(0) <= i_ram_doByte(7); --CY
                            exe_state <= P2;
                        when P2 =>
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
								    RAM_WR_BYTE_START(x"D0", DR(0) & PSW(6 downto 0));
                            exe_state <= P2;
                        when P2 => 
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
			
			 -- RR A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00000011" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
								    RAM_RD_BYTE_START(x"E0");
                            exe_state <= P2; 
                        when P2 =>
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
									 RAM_WR_BYTE_START(x"E0", i_ram_doByte(0) & i_ram_doByte(7 downto 1));
                            exe_state <= P2;
                        when P2 =>
									 RAM_STOP;
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle			

			 -- RRC A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00010011" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
								    RAM_RD_BYTE_START(x"D0");
                            exe_state <= P2; 
                        when P2 =>
                            PSW <= i_ram_doByte;
                            RAM_RD_BYTE_START(x"E0");
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
                            RAM_WR_BYTE_START(x"E0", PSW(7) & i_ram_doByte(7 downto 1));
                            DR(0) <= i_ram_doByte(7); --CY
                            exe_state <= P2;
                        when P2 =>
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
								    RAM_WR_BYTE_START(x"D0", DR(0) & PSW(6 downto 0));
                            exe_state <= P2;
                        when P2 => 
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

			 -- CPL C
			 -- 1 byte, 1 cycle
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "10110011" =>
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
											PSW(7) <= not(PSW(7));
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

			 -- CPL bit
			 -- 2 byte, 1 cycle
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "10110010" =>
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
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_RD_BIT_START (i_rom_data);
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START(i_rom_data, not(i_ram_doBit));
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
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0));
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
					
				-- ACALL addr11
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when  "00010001" |
						"00110001" |
						"01010001" |
						"01110001" |
						"10010001" |
						"10110001" |
						"11010001" |
						"11110001" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"81");
											exe_state <= P2;
										
										when P2	=>
											AR <= i_ram_doByte; -- address the SP point to stored in AR
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
											DR <= i_rom_data;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											AR <= AR + 1;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(AR, PC(7 downto 0));
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
											AR <= AR + 1;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(AR, PC(15 downto 8));
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
											PC(10 downto 0) <= IR(7 downto 5) & DR;
											RAM_WR_BYTE_START(x"81", AR);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- LCALL addr16
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "00010010" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"81");
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
											AR <= AR + 1;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"7F", DR); -- using the last position of the scratch pad to temporarily
											exe_state <= P2;				  -- store the higher bits of the new location
										
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
											RAM_WR_BYTE_START(AR, PC(7 downto 0));
											exe_state <= P2;
										
										when P2	=>
											PC(7 downto 0) <= DR;
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
											AR <= AR + 1;
											RAM_RD_BYTE_START(x"7F"); -- Read out the higher bits in the scratch pad
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
											RAM_WR_BYTE_START(AR, PC(15 downto 8));
											exe_state <= P2;
										
										when P2	=>
											PC(15 downto 8) <= DR;
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- RET
				-- 1 byte, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "00100010" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"81");
											exe_state <= P2;
										
										when P2	=>
											AR <= i_ram_doByte; -- address the SP point to stored in AR
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											PC(15 downto 8) <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>	-- 1 byte instruction, do nothing
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
											AR <= AR - 1;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											PC(7 downto 0) <= i_ram_doByte;
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
								when S1 =>	-- 1 byte instruction, do nothing
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
											AR <= AR - 1;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"81", AR); -- Update actual SP
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing
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
					
				-- RETI
				-- 1 byte, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "00110010" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"81");
											exe_state <= P2;
										
										when P2	=>
											AR <= i_ram_doByte; -- address the SP point to stored in AR
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											PC(15 downto 8) <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>	-- 1 byte instruction, do nothing
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
											AR <= AR - 1;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											PC(7 downto 0) <= i_ram_doByte;
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
								when S1 =>	-- 1 byte instruction, do nothing
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
											AR <= AR + 1;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"81", AR); -- Update actual SP
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing
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
											int_hold <= '0';	-- re-enable interrupts
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
					
				-- AJMP addr11
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when	"00000001" |
						"00100001" |
						"01000001" |
						"01100001" |
						"10000001" |
						"10100001" |
						"11000001" |
						"11100001" =>
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
											PC(10 downto 0) <= IR(7 downto 5) & DR;
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
					
				-- LJMP addr16
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when	"00000010" =>
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
											RAM_WR_BYTE_START(x"7F", DR);	-- using x7F scratch pad as temporary storage
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
											
										when P2	=>
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
											PC(7 downto 0) <= DR;
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
											RAM_RD_BYTE_START(x"7F");	-- Read from temporary storage
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
											PC(15 downto 8) <= DR;
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
					
				-- SJMP rel
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "10000000" =>
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
											if (DR(7) = '1') then
												PC <= PC + (x"FF" & DR);
											else
												PC <= PC + (x"00" & DR);
											end if;
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
				
				-- JB bit, rel
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "00100000" =>
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
											AR <= i_rom_data;	-- store bit address in AR
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
											
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;	-- store rel address in DR
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
											RAM_RD_BIT_START(AR);
											exe_state <= P2;
										
										when P2	=>
											if (i_ram_doBit = '1') then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
					
				-- JBC bit, rel
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "00010000" =>
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
											AR <= i_rom_data;	-- store bit address in AR
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
											
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;	-- store rel address in DR
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
											RAM_RD_BIT_START(AR);
											exe_state <= P2;
										
										when P2	=>
											if (i_ram_doBit = '1') then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
											RAM_WR_BIT_START(AR, '0');	-- clear the bit
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- JC rel
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "01000000" =>
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
											if (PSW(7) = '1') then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
					
				-- JMP @A+DPTR
				-- 1 byte, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "01110011" =>
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
									
								when S4 =>	-- 1 byte instruction, do nothing
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
											RAM_RD_BYTE_START(x"82");
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
								when S1 =>	-- 1 byte instruction, do nothing
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
											RAM_RD_BYTE_START(x"83");
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											alu_src_1L <= ACC;
											alu_src_1H <= x"00";
											alu_src_2L <= DR;
											alu_src_2H <= i_ram_doByte;
											alu_op_code <= ALU_OPC_ADD;
											alu_by_wd <= '1';
											RAM_STOP;
											exe_state <= P2;
										
										when P2	=>
											PC <= alu_ans_H & alu_ans_L;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing
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
					
				-- JNB bit, rel
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "00110000" =>
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
											AR <= i_rom_data;	-- store bit address in AR
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
											
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;	-- store rel address in DR
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
											RAM_RD_BIT_START(AR);
											exe_state <= P2;
										
										when P2	=>
											if (i_ram_doBit = '0') then
												if(DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
					
				-- JNC rel
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "01010000" =>
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
											if (PSW(7) = '0') then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
					
				-- JNZ rel
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "01110000" =>
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
											if (ACC /= x"00") then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
				
				-- JZ rel
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "01100000" =>
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
											if (ACC = x"00") then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
					
				-- CJNE A, direct, rel
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "10110101" =>
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
											AR <= i_rom_data;	-- store direct address in AR
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
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
											ROM_RD_START(PC);
											exe_state <= P2;
											
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;	-- store rel address in DR
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											if (ACC /= i_ram_doByte) then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
											
											if (ACC > i_ram_doByte) then
												PSW(7) <= '0';
											elsif (ACC < i_ram_doByte) then
												PSW(7) <= '1';
											end if;
											RAM_STOP;
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
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
			-- CJNE A,#data, rel
			-- 3 bytes, 2 cycles
			-- Author: Tran Phuoc Dang Khoa
			-- Status: Not Simulated
			when "10110100" =>
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
											DR <= i_rom_data;	-- immediate data in DR
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"D0");
											exe_state <= P2;
										
										when P2	=>
											PSW <= i_ram_doByte;
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
											ROM_RD_START(PC);
											exe_state <= P2;
											
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;	-- store rel address in AR
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
											if (ACC /= DR) then
												if (AR(7) = '1') then
													PC <= PC + (x"FF" & AR);
												else
													PC <= PC + (x"00" & AR);
												end if;
											end if;
											
											if (ACC > DR) then
												PSW(7) <= '0';
											elsif (ACC < DR) then
												PSW(7) <= '1';
											end if;
											RAM_STOP;
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
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- CJNE Rn, #data, rel
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when 	"10111000" |
						"10111001" |
						"10111010" |
						"10111011" |
						"10111100" |
						"10111101" |
						"10111110" |
						"10111111" =>
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
											DR <= i_rom_data;	-- immediate data in DR
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
											
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;	-- store rel address in AR
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0));
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											if (i_ram_doByte /= DR) then
												if (AR(7) = '1') then
													PC <= PC + (x"FF" & AR);
												else
													PC <= PC + (x"00" & AR);
												end if;
											end if;
											
											if (i_ram_doByte > DR) then
												PSW(7) <= '0';
											elsif (i_ram_doByte < DR) then
												PSW(7) <= '1';
											end if;
											RAM_STOP;
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
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- CJNE @Ri, #data, rel
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when "10110110" | "10110111" =>
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
											DR <= i_rom_data;	-- immediate data in DR
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
											
										when P2	=>
											PC <= PC + 1;
											AR <= i_rom_data;	-- store rel address in AR
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0));
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START(i_ram_doByte);
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											if (i_ram_doByte /= DR) then
												if (AR(7) = '1') then
													PC <= PC + (x"FF" & AR);
												else
													PC <= PC + (x"00" & AR);
												end if;
											end if;
											
											if (i_ram_doByte > DR) then
												PSW(7) <= '0';
											elsif (i_ram_doByte < DR) then
												PSW(7) <= '1';
											end if;
											RAM_STOP;
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
											RAM_WR_BYTE_START(x"D0", PSW);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- DJNZ Rn, rel
				-- 2 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Not Simulated
				when 	"11011000" |
						"11011001" |
						"11011010" |
						"11011011" |
						"11011100" |
						"11011101" |
						"11011110" |
						"11011111" =>
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
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0));
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>
											alu_src_1L <= i_ram_doByte;
											alu_by_wd <= '0';
											alu_op_code <= ALU_OPC_DEC;
											RAM_STOP;
											exe_state <= P2;
										
										when P2	=>
											DR <= alu_ans_L;
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
											RAM_WR_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0), alu_ans_L);
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
											if(DR /= x"00")  then
												if (AR(7) = '1') then
													PC <= PC + (x"FF" & AR);
												else
													PC <= PC + (x"00" & AR);
												end if;
											end if;
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
					
				-- DJNZ direct, rel
				-- 3 bytes, 2 cycles
				-- Author: Tran Phuoc Dang Khoa
				-- Status: Simulated
				when "11010101" =>
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
											AR <= i_rom_data;	-- direct address stored in AR
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
											
										when P2	=>
											PC <= PC + 1;
											DR <= i_rom_data;	-- store rel address in DR
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											alu_src_1L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_DEC;
											alu_by_wd <= '0';
											RAM_STOP;
											exe_state <= P2;
										
										when P2	=>
											if (alu_ans_L /= x"00") then
												if (DR(7) = '1') then
													PC <= PC + (x"FF" & DR);
												else
													PC <= PC + (x"00" & DR);
												end if;
											end if;
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
											RAM_WR_BYTE_START(AR, alu_ans_L);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				-- MUL AB
				-- 1 byte, 4 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "10100100" =>
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
											RAM_RD_BYTE_START(x"F0");
											exe_state <= P2;

										when P2	=>
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;

										when others =>
									end case; -- end case exe state

								when S4 =>
									case exe_state is
										when P1	=>  
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P2;

										when P2	=>
											ACC <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S5;

										when others =>
									end case; -- end case exe state

								when S5 =>
									case exe_state is
										when P1	=>
											mul_a_i <= "00000000" & ACC;
											mul_b_i <= "00000000" & DR;
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
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M3; 

										when others =>
									end case; -- end case exe state

								when others =>
							end case; 

						when M3 =>
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
											machine_cycle <= M4; -- end 2 cycles instruction, back to M1

										when others =>
									end case; -- end case exe state

								when others =>
							end case; 

						when M4 =>
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
											RAM_WR_BYTE_START(x"F0", mul_prod_o(15 downto 8));
											exe_state <= P2;

										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;

										when others =>
									end case; -- end case exe state

								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"E0", mul_prod_o(7 downto 0));
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
											if conv_integer(mul_prod_o(15 downto 0)) > 255 then
												PSW(7) <= '0';
												PSW(2) <= '1';
												RAM_WR_BYTE_START(x"D0",PSW);
											else
												PSW(7) <= '0';
												PSW(2) <= '0';
												RAM_WR_BYTE_START(x"D0",PSW);
											end if;
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
					
				-- DIV AB
				-- 1 byte, 4 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "10000100" =>
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
											RAM_RD_BYTE_START(x"F0");
											exe_state <= P2;

										when P2	=>
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;

										when others =>
									end case; -- end case exe state

								when S4 =>
									case exe_state is
										when P1	=>  
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P2;

										when P2	=>
											ACC <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S5;

										when others =>
									end case; -- end case exe state

								when S5 =>
									case exe_state is
										when P1	=>
											divisor_i <= "00000000" & DR; -- B
											dividend_i <= "00000000" & ACC; -- ACC
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
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M3; 

										when others =>
									end case; -- end case exe state

								when others =>
							end case; 

						when M3 =>
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
											machine_cycle <= M4; -- end 2 cycles instruction, back to M1

										when others =>
									end case; -- end case exe state

								when others =>
							end case; 

						when M4 =>
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
											RAM_WR_BYTE_START(x"F0",remainder_o(7 downto 0));
											exe_state <= P2;

										when P2	=>
											exe_state <= P1;
											cpu_state <= S3;

										when others =>
									end case; -- end case exe state

								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"E0", quotient_o(7 downto 0));
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
											if DR = "00000000" then
												PSW(7) <= '0';
												PSW(2) <= '1';
												RAM_WR_BYTE_START(x"D0",PSW);
											else
												PSW(7) <= '0';
												PSW(2) <= '0';
												RAM_WR_BYTE_START(x"D0",PSW);
											end if;
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
					
				-- MOVX A,@Ri
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Not Simulated
				when  "11100010" | "11100011"  =>
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
											RAM_RD_BYTE_START( "000" & PSW(4 downto 3) & "00" & IR(0));
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											--DR <= i_ram_doByte;
											ale <= '1'; -- assert ALE
											RAM_WR_BYTE_START(x"80",i_ram_doByte);
											exe_state <= P2;
										
										when P2	=>
											ale <= '0'; -- deassert ALE
											exe_state <= P1;
											cpu_state <= S4;
											RAM_WR_BYTE_START(x"80","00000000");
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START("10110111",'0');  --turn on read strobe
											-- xBO(7 down to 3) & "111"
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_RD_BYTE_START(x"80");
											exe_state <= P2;
										
										when P2	=>

											ACC <= i_ram_doByte;
											RAM_WR_BIT_START("10110111",'1');
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"E0",ACC);
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

				-- MOVX A,@DPTR
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Not Simulated
				when  "11100000"  =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"82");
											exe_state <= P2;
										
										when P2	=>
											AR <= i_ram_doByte;
											RAM_RD_BYTE_START(x"83");
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											DR <= i_ram_doByte;
											RAM_WR_BYTE_START(x"80",AR);
											ale <= '1';
											exe_state <= P2;
										
										when P2	=>
											ale <= '0';
											RAM_WR_BYTE_START(x"80", x"00");			--reset P0
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"A0",DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BIT_START("10110111", '0');
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"80");
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											RAM_WR_BIT_START("10110111", '1');
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
											RAM_WR_BYTE_START(x"A0", x"00");
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

				-- MOVX @Ri,A
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Not Simulated
				when  "11110010" | "11110011"  =>
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
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) &"00" &IR(0));
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x"80",i_ram_doByte);
											ale <= '1';
											exe_state <= P2;
										
										when P2	=>										
											RAM_WR_BYTE_START(x"80","00000000");
											ale<= '0';
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"80",i_ram_doByte);
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_WR_BIT_START("10110110",'0');  --turn on read strobe
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BIT_START("10110110",'1');  -- turn off write strobe
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  									
											RAM_WR_BYTE_START(x"80", "00000000"); --reset P0
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

				-- MOVX @DPTR,A
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Not Simulated
				when  "11110000" =>
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
											RAM_RD_BYTE_START(x"82");
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											AR <= i_ram_doByte;
											RAM_RD_BYTE_START(x"83");
											exe_state <= P2;
										
										when P2	=>
											DR <=i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"A0",DR);
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"80",AR);
											ale <= '1'; -- assert ale
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											ale <= '0';
											RAM_WR_BYTE_START(x"A0","00000000"); -- reset P2
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"80","00000000");  --reset P0
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(x"80",ACC);
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
											RAM_WR_BIT_START("10110110",'1'); -- turn on write strobe
											exe_state <= P2;
											
										when P2 =>
											RAM_WR_BIT_START("10110110",'0'); -- turn off write strobe
											exe_state <= P1;
											cpu_state <= S2;
											
										when others =>
									end case;
									
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_WR_BYTE_START(x80,"00000000");
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
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle

				-- MOVC A,@A+PC
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Not Simulated
				when  "10000011" =>
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
											alu_src_1L <= ACC; -- 
											alu_src_1H <= "00000000"; -- 
											alu_src_2L <= PC(7 downto 0); -- 
											alu_src_2H <= PC(15 downto 8); -- 
											alu_by_wd <= '1';
											alu_op_code <= ALU_OPC_ADD;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>  
											ROM_RD_START(alu_ans_H & alu_ans_L);
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
											RAM_WR_BYTE_START(x"E0", i_rom_data);
											exe_state <= P2;
										
										when P2	=>
										   	RAM_STOP;
										   	ROM_STOP;
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

				-- MOVC A,@A+DPTR
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Not Simulated
				when  "10010011" =>
					case machine_cycle is
						when M1 =>
							case cpu_state is
								when S2 =>
									case exe_state is
										when P1	=>
											RAM_RD_BYTE_START(x"83"); -- data high pointer
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte;
											RAM_RD_BYTE_START(x"82"); -- data low pointer
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											AR <= i_ram_doByte;
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P2;
										
										when P2	=>
											ACC <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 =>
									case exe_state is
										when P1	=>
											alu_src_2L <= AR;
											alu_src_2H <= DR;
											alu_src_1L <= ACC;
											alu_src_1H <= "00000000";
											alu_by_wd <= '1';
											alu_op_code <= ALU_OPC_ADD;
											exe_state <= P2;
										
										when P2	=>
											ROM_RD_START(alu_ans_H & alu_ans_L);
											-- (A) +(DPTR)
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_WR_BYTE_START(x"E0",i_rom_data);
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											ROM_STOP;
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
					
					
								-- ANL A, Rn
				-- 1 byte, 1 cycle
				-- Autho : Gaurav Chandrashekar
				-- Status : Simulated
				when  "01011000" | 
						"01011001" | 
						"01011010" | 
						"01011011" | 
						"01011100" | 
						"01011101" | 
						"01011110" | 
						"01011111" =>
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
											alu_op_code <= ALU_OPC_AND;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
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
											exe_state <= P2;
										
										when P2	=>
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

				-- ANL A, direct
				-- 1 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01010101" =>
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
											RAM_RD_BYTE_START(i_rom_data);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_AND;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- ANL A, @Ri
				-- 1 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when  "01010110" | "01010111" =>
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
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0));
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
											DR <= i_ram_doByte;
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											alu_src_1L <= i_ram_doByte;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_AND;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
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
											exe_state <= P2;
										
										when P2	=>
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

				-- ANL A, #data
				-- 2 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01010100" =>
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
											alu_op_code <= ALU_OPC_AND;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- ANL direct, A
				-- 2 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01010010" =>
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
											RAM_RD_BYTE_START(DR);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_AND;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(DR, alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- ANL direct, #data
				-- 3 byte, 2 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01010011" =>
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
											alu_src_1L <= DR;
											alu_src_2L <= i_rom_data;
											alu_op_code <= ALU_OPC_AND;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(AR, alu_ans_L);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle

				-- XRL A, Rn
				-- 1 byte, 1 cycle
				-- Autho : Gaurav Chandrashekar
				-- Status : Simulated
				when  "01101000" | 
						"01101001" | 
						"01101010" | 
						"01101011" | 
						"01101100" | 
						"01101101" | 
						"01101110" | 
						"01101111" =>
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
											alu_op_code <= ALU_OPC_XOR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
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
											exe_state <= P2;
										
										when P2	=>
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

				-- XRL A, direct
				-- 1 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01100101" =>
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
											RAM_RD_BYTE_START(i_rom_data);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_XOR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- XRL A, @Ri
				-- 1 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when  "01100110" | "01100111" =>
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
											PSW <= i_ram_doByte;
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
											RAM_RD_BYTE_START(x"E0");
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											alu_src_1L <= i_ram_doByte;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_XOR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
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
											exe_state <= P2;
										
										when P2	=>
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

				-- XRL A, #data
				-- 2 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01100100" =>
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
											alu_op_code <= ALU_OPC_XOR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- XRL direct, A
				-- 2 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01100010" =>
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
											RAM_RD_BYTE_START(DR);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_XOR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(DR, alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- XRL direct, #data
				-- 3 byte, 2 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01100011" =>
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
											alu_src_1L <= DR;
											alu_src_2L <= i_rom_data;
											alu_op_code <= ALU_OPC_XOR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(AR, alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
				
				-- ANL C, bit
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "10000010"  =>
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
											RAM_RD_BIT_START(AR);
											exe_state <= P2;
										
										when P2	=>
--											DR <= i_ram_doBit;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START(AR,PSW(7) and i_ram_doBit);
											-- RAM_WR_BIT_START(AR,PSW(7) and DR);
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
					
				-- ANL C, /bit
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "10110000"  =>
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
											RAM_RD_BIT_START(AR);
											exe_state <= P2;
										
										when P2	=>
--											DR <= i_ram_doBit;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START(AR,PSW(7) and not i_ram_doBit);
											-- RAM_WR_BIT_START(AR,PSW(7) and DR);
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

				-- ORL C, bit
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "01110010"  =>
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
											RAM_RD_BIT_START(AR);
											exe_state <= P2;
										
										when P2	=>
--											DR <= i_ram_doBit;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START(AR,PSW(7) or i_ram_doBit);
											-- RAM_WR_BIT_START(AR,PSW(7) and DR);
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
				
				-- ORL C, /bit
				-- 2 bytes, 2 cycles
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "10100000"  =>
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
											RAM_RD_BIT_START(AR);
											exe_state <= P2;
										
										when P2	=>
--											DR <= i_ram_doBit;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BIT_START(AR,PSW(7) or not i_ram_doBit);
											-- RAM_WR_BIT_START(AR,PSW(7) and DR);
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

			 -- INC A
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00000100" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
                            RAM_RD_BYTE_START(x"E0");
                            exe_state <= P2; 
                        when P2 => 
                            alu_src_1L <= i_ram_doByte;
                            alu_src_2L <= "00000001";
									 alu_op_code <= ALU_OPC_ADD;    
                            alu_by_wd <= '0';
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
                            RAM_WR_BYTE_START(x"E0", alu_ans_L);
                            exe_state <= P2;
                        when P2 => 
                            RAM_STOP;
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle			


			 -- INC Rn
			 -- Author: Akash Ranka
			 -- Status: Simulated
                
			 when "00001000" | "00001001" | "00001010" | "00001011" | "00001100" | "00001101" | "00001110" | "00001111" =>
				 case machine_cycle is
					 when M1 =>
					 case cpu_state is
						when S2 =>
						
						case exe_state is
                        when P1 =>
                            RAM_RD_BYTE_START(x"D0");
                            exe_state <= P2; 
                        when P2 =>  
									 PSW <= i_ram_doByte;
                            RAM_RD_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0));
                            exe_state <= P1;
									 cpu_state <= S3; 
								 when others =>
						 end case;
                
					when S3 =>
					 
						case exe_state is
                        when P1 =>
                            alu_src_1L <= i_ram_doByte;
                            alu_src_2L <= "00000001";
									 alu_op_code <= ALU_OPC_ADD;    
                            alu_by_wd <= '0';
                            exe_state <= P2;
                        when P2 =>
									 RAM_WR_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0), alu_ans_L);
                            exe_state <= P1;
									 cpu_state <= S4;
								 when others =>
						 end case;

					when S4 =>
					 
						case exe_state is
                        when P1 =>
									 RAM_STOP;
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S5;
								 when others =>
						 end case;

					when S5 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S6;
								 when others =>
						 end case;        
               

					when S6 =>
					 
						case exe_state is
                        when P1 =>
                            exe_state <= P2;
                        when P2 => 
                            exe_state <= P1;
									 cpu_state <= S1;
									 machine_cycle <= M1;
								when others =>
							end case; -- end case exe state
							
						when others =>
					end case; -- end case cpu state
					
				when others =>
			end case; -- end case machine cycle	

				-- INC direct
				-- 2 bytes, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				
				when "00000101" =>
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
											--ROM_STOP;
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
											alu_src_1L <= i_ram_doByte; -- direct byte
											alu_src_2L <= "00000001";
											alu_op_code <= ALU_OPC_ADD;    
											alu_by_wd <= '0';
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(i_rom_data, alu_ans_L); 
											exe_state <= P2;
										
										when P2	=>
										   RAM_STOP;
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state

						when others =>
					end case; -- end case machine cycle
							
				--	INC @Ri
				-- 1 byte, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				
				when "00000110" | "00000111" =>
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
											AR <= i_ram_doByte;
											RAM_RD_BYTE_START(i_ram_doByte);
											exe_state <= P2;
										
										when P2	=>
											alu_src_1L <= i_ram_doByte; -- (Ri)
											alu_src_2L <= "00000001";
											alu_op_code <= ALU_OPC_ADD;    
											alu_by_wd <= '0';
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
											RAM_WR_BYTE_START(AR, alu_ans_L);
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
					
					
				
	
				-- ADD A,@Ri
				-- 1 byte, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "00100110" | "00100111" =>
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
											PSW <= i_ram_doByte;
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
											RAM_RD_BYTE_START(x"E0");
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											alu_src_1L <= i_ram_doByte;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_ADD;
											alu_by_wd <= '0';
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

				-- ADDC A,@Ri
				-- 1 byte, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "00110110" | "00110111" =>
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
											PSW <= i_ram_doByte;
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
											RAM_RD_BYTE_START(x"E0");
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											alu_src_1L <= i_ram_doByte;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_ADC;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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

				-- SUBB A,@Ri
				-- 1 byte, 1 cycle
				-- Author: Gaurav Chandrashekar
				-- Status: Simulated
				when  "10010110" | "10010111" =>
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
											PSW <= i_ram_doByte;
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
											RAM_RD_BYTE_START(x"E0");
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											alu_src_1L <= i_ram_doByte;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_SBB;
											alu_by_wd <= '0';
											alu_cy_bw <= PSW(7);
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
					
				-- XCH A, Rn
				-- 1 byte, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				when  "11001000" | 
						"11001001" | 
						"11001010" | 
						"11001011" | 
						"11001100" | 
						"11001101" | 
						"11001110" | 
						"11001111" =>
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
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0));
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											DR <= i_ram_doByte; -- Rn
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
											RAM_RD_BYTE_START(x"E0");
											exe_state <= P2;
										
										when P2	=>
											ACC <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START("000" & PSW(4 downto 3) & IR(2 downto 0), ACC); -- Rn <= ACC
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", DR); -- ACC <= Rn (or DR)
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
	
				-- XCH A, direct
				-- 2 byte, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				when  "11000101" =>
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
											RAM_RD_BYTE_START(AR);
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											RAM_RD_BYTE_START(x"E0");
											DR <= i_ram_doByte;
											exe_state <= P2;
										
										when P2	=>
											ACC <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(AR, ACC); -- direct <= ACC
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", DR); -- ACC <= direct
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle

				-- XCH A, @Ri
				-- 1 byte, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				when  "11000110" | "11000111" =>
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
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0));
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											AR <= i_ram_doByte; -- Address of @Ri
											RAM_RD_BYTE_START(AR);
											exe_state <= P2;
										
										when P2	=>
											DR <= i_ram_doByte; -- @Ri
											RAM_RD_BYTE_START(x"E0"); -- ACC
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>
											ACC <= i_ram_doByte;  
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
											RAM_WR_BYTE_START(AR, ACC); -- @Ri <= ACC
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", DR); -- ACC <= @Ri (or DR)
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
	
				-- XCHD A, @Ri
				-- 1 byte, 1 cycle
				-- Author: Akash Ranka
				-- Status: Simulated
				when  "11010110" | "11010111" =>
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
											RAM_RD_BYTE_START("000" & PSW(4 downto 3) & "00" & IR(0));
											exe_state <= P1;
											cpu_state <= S3;
											
										when others =>
									end case; -- end case exe state
								
								when S3 =>
									case exe_state is
										when P1	=>
											AR <= i_ram_doByte; -- Address of @Ri
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START(AR);
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
									
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=>  
											DR <= i_ram_doByte; -- @Ri
											exe_state <= P2;
										
										when P2	=>
											RAM_RD_BYTE_START(x"E0"); -- ACC
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
									
								when S5 =>
									case exe_state is
										when P1	=> 
											ACC <= i_ram_doByte;
											exe_state <= P2;
										
										when P2	=>
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
											RAM_WR_BYTE_START(AR, DR(7 downto 4) & ACC(3 downto 0)); -- @Ri <= @Ri(7-4) & ACC(3-0)
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", ACC(7 downto 4) & DR(3 downto 0)); -- ACC <= ACC(7-4) & @Ri (3-0)
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1;
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
					
				-- ORL A, Rn
				-- 1 byte, 1 cycle
				-- Autho : Gaurav Chandrashekar
				-- Status : Simulated
				when  "01001000" | 
						"01001001" | 
						"01001010" | 
						"01001011" | 
						"01001100" | 
						"01001101" | 
						"01001110" | 
						"01001111" =>
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
											alu_op_code <= ALU_OPC_OR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
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
											exe_state <= P2;
										
										when P2	=>
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

				-- ORL A, direct
				-- 1 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01000101" =>
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
											RAM_RD_BYTE_START(i_rom_data);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_OR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- ORL A, @Ri
				-- 1 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when  "01000110" | "01000111" =>
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
											PSW <= i_ram_doByte;
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
											RAM_RD_BYTE_START(x"E0");
											DR <= i_ram_doByte;
											exe_state <= P1;
											cpu_state <= S4;
											
										when others =>
									end case; -- end case exe state
								when S4 => -- 1 byte instruction, do nothing here
									case exe_state is
										when P1	=> 
											alu_src_1L <= i_ram_doByte;
											alu_src_2L <= DR;
											alu_op_code <= ALU_OPC_OR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0'; 
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
											exe_state <= P2;
										
										when P2	=>
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

				-- ORL A, #data
				-- 2 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01000100" =>
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
											alu_op_code <= ALU_OPC_OR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(x"E0", alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- ORL direct, A
				-- 2 byte, 1 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01000010" =>
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
											RAM_RD_BYTE_START(DR);
											ROM_STOP;
											exe_state <= P1;
											cpu_state <= S5;
											
										when others =>
									end case; -- end case exe state
								when S5 =>
									case exe_state is
										when P1	=> 
											alu_src_1L <= ACC;
											alu_src_2L <= i_ram_doByte;
											alu_op_code <= ALU_OPC_OR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											RAM_WR_BYTE_START(DR, alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
								when S6 =>
									case exe_state is
										when P1	=>  
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

				-- ORL direct, #data
				-- 3 byte, 2 cycle
				-- Author : Gaurav Chandrashekar
				-- Status : Simulated
				when "01000011" =>
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
											alu_src_1L <= DR;
											alu_src_2L <= i_rom_data;
											alu_op_code <= ALU_OPC_OR;
											alu_by_wd <= '0';
											alu_cy_bw <= '0';
											exe_state <= P2;
										
										when P2	=>
											ROM_STOP;
											RAM_WR_BYTE_START(AR, alu_ans_L);
											exe_state <= P1;
											cpu_state <= S6;
											
										when others =>
									end case; -- end case exe state
									
								when S6 =>
									case exe_state is
										when P1	=> 
											exe_state <= P2;
										
										when P2	=>
											RAM_STOP;
											exe_state <= P1;
											cpu_state <= S1;
											machine_cycle <= M1; -- end 2 cycles instruction, back to M1
											
										when others =>
									end case; -- end case exe state
									
								when others =>
							end case; -- end case cpu state
							
						when others =>
					end case; -- end case machine cycle
					
				when others =>
			end case; -- end case IR
	 end if;
	

end if;
end process;
end seq_arch;

-------------------------------------------------------------------------------

-- end of file --
