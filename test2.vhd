--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   02:00:38 10/01/2012
-- Design Name:   
-- Module Name:   D:/Myproject/test2.vhd
-- Project Name:  Myproject
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: sequencer2
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY test2 IS
END test2;
 
ARCHITECTURE behavior OF test2 IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT sequencer2
    PORT(
         rst : IN  std_logic;
         clk : IN  std_logic;
         ale : OUT  std_logic;
         psen : OUT  std_logic;
         alu_op_code : OUT  std_logic_vector(3 downto 0);
         alu_src_1L : OUT  std_logic_vector(7 downto 0);
         alu_src_1H : OUT  std_logic_vector(7 downto 0);
         alu_src_2L : OUT  std_logic_vector(7 downto 0);
         alu_src_2H : OUT  std_logic_vector(7 downto 0);
         alu_by_wd : OUT  std_logic;
         alu_cy_bw : OUT  std_logic;
         alu_ans_L : IN  std_logic_vector(7 downto 0);
         alu_ans_H : IN  std_logic_vector(7 downto 0);
         alu_cy : IN  std_logic;
         alu_ac : IN  std_logic;
         alu_ov : IN  std_logic;
         dividend_i : OUT  std_logic_vector(15 downto 0);
         divisor_i : OUT  std_logic_vector(15 downto 0);
         quotient_o : IN  std_logic_vector(15 downto 0);
         remainder_o : IN  std_logic_vector(15 downto 0);
         div_done : IN  std_logic;
         mul_a_i : OUT  std_logic_vector(15 downto 0);
         mul_b_i : OUT  std_logic_vector(15 downto 0);
         mul_prod_o : IN  std_logic_vector(31 downto 0);
         i_ram_wrByte : OUT  std_logic;
         i_ram_wrBit : OUT  std_logic;
         i_ram_rdByte : OUT  std_logic;
         i_ram_rdBit : OUT  std_logic;
         i_ram_addr : OUT  std_logic_vector(7 downto 0);
         i_ram_diByte : OUT  std_logic_vector(7 downto 0);
         i_ram_diBit : OUT  std_logic;
         i_ram_doByte : IN  std_logic_vector(7 downto 0);
         i_ram_doBit : IN  std_logic;
         i_rom_addr : OUT  std_logic_vector(15 downto 0);
         i_rom_data : IN  std_logic_vector(7 downto 0);
         i_rom_rd : OUT  std_logic;
         pc_debug : OUT  std_logic_vector(15 downto 0);
         interrupt_flag : IN  std_logic_vector(2 downto 0);
         erase_flag : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal rst : std_logic := '0';
   signal clk : std_logic := '0';
   signal alu_ans_L : std_logic_vector(7 downto 0) := (others => '0');
   signal alu_ans_H : std_logic_vector(7 downto 0) := (others => '0');
   signal alu_cy : std_logic := '0';
   signal alu_ac : std_logic := '0';
   signal alu_ov : std_logic := '0';
   signal quotient_o : std_logic_vector(15 downto 0) := (others => '0');
   signal remainder_o : std_logic_vector(15 downto 0) := (others => '0');
   signal div_done : std_logic := '0';
   signal mul_prod_o : std_logic_vector(31 downto 0) := (others => '0');
   signal i_ram_doByte : std_logic_vector(7 downto 0) := (others => '0');
   signal i_ram_doBit : std_logic := '0';
   signal i_rom_data : std_logic_vector(7 downto 0) := (others => '0');
   signal interrupt_flag : std_logic_vector(2 downto 0) := (others => '0');

 	--Outputs
   signal ale : std_logic;
   signal psen : std_logic;
   signal alu_op_code : std_logic_vector(3 downto 0);
   signal alu_src_1L : std_logic_vector(7 downto 0);
   signal alu_src_1H : std_logic_vector(7 downto 0);
   signal alu_src_2L : std_logic_vector(7 downto 0);
   signal alu_src_2H : std_logic_vector(7 downto 0);
   signal alu_by_wd : std_logic;
   signal alu_cy_bw : std_logic;
   signal dividend_i : std_logic_vector(15 downto 0);
   signal divisor_i : std_logic_vector(15 downto 0);
   signal mul_a_i : std_logic_vector(15 downto 0);
   signal mul_b_i : std_logic_vector(15 downto 0);
   signal i_ram_wrByte : std_logic;
   signal i_ram_wrBit : std_logic;
   signal i_ram_rdByte : std_logic;
   signal i_ram_rdBit : std_logic;
   signal i_ram_addr : std_logic_vector(7 downto 0);
   signal i_ram_diByte : std_logic_vector(7 downto 0);
   signal i_ram_diBit : std_logic;
   signal i_rom_addr : std_logic_vector(15 downto 0);
   signal i_rom_rd : std_logic;
   signal pc_debug : std_logic_vector(15 downto 0);
   signal erase_flag : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: sequencer2 PORT MAP (
          rst => rst,
          clk => clk,
          ale => ale,
          psen => psen,
          alu_op_code => alu_op_code,
          alu_src_1L => alu_src_1L,
          alu_src_1H => alu_src_1H,
          alu_src_2L => alu_src_2L,
          alu_src_2H => alu_src_2H,
          alu_by_wd => alu_by_wd,
          alu_cy_bw => alu_cy_bw,
          alu_ans_L => alu_ans_L,
          alu_ans_H => alu_ans_H,
          alu_cy => alu_cy,
          alu_ac => alu_ac,
          alu_ov => alu_ov,
          dividend_i => dividend_i,
          divisor_i => divisor_i,
          quotient_o => quotient_o,
          remainder_o => remainder_o,
          div_done => div_done,
          mul_a_i => mul_a_i,
          mul_b_i => mul_b_i,
          mul_prod_o => mul_prod_o,
          i_ram_wrByte => i_ram_wrByte,
          i_ram_wrBit => i_ram_wrBit,
          i_ram_rdByte => i_ram_rdByte,
          i_ram_rdBit => i_ram_rdBit,
          i_ram_addr => i_ram_addr,
          i_ram_diByte => i_ram_diByte,
          i_ram_diBit => i_ram_diBit,
          i_ram_doByte => i_ram_doByte,
          i_ram_doBit => i_ram_doBit,
          i_rom_addr => i_rom_addr,
          i_rom_data => i_rom_data,
          i_rom_rd => i_rom_rd,
          pc_debug => pc_debug,
          interrupt_flag => interrupt_flag,
          erase_flag => erase_flag
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
