library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity packer_32_to_256 is
    Generic (
        -- Add generics for Xilinx compatibility
        C_S_AXI_DATA_WIDTH : integer := 32
    );
    Port (
        clk         : in  std_logic;
        ce          : in  std_logic := '1';  -- Clock enable for Xilinx
        rst         : in  std_logic;
        -- Input: 32-bit words from requantizer
        data_in     : in  std_logic_vector(31 downto 0);
        -- Output: 256-bit packed word
        data_out    : out std_logic_vector(255 downto 0)
    );
end packer_32_to_256;

architecture Behavioral of packer_32_to_256 is
    -- Shift register to store 8 x 32-bit words
    type shift_reg_type is array (0 to 7) of std_logic_vector(31 downto 0);
    signal shift_reg : shift_reg_type := (others => (others => '0'));
    
    -- Counter to track position
    signal counter : unsigned(2 downto 0) := (others => '0');
    
    -- Output register
    signal data_out_reg : std_logic_vector(255 downto 0) := (others => '0');
    
    -- Xilinx attributes for timing
    attribute use_dsp : string;
    attribute use_dsp of Behavioral : architecture is "no";
    
begin

    -- Synchronous process with clock enable
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset all registers
                for i in 0 to 7 loop
                    shift_reg(i) <= (others => '0');
                end loop;
                counter <= (others => '0');
                data_out_reg <= (others => '0');
            elsif ce = '1' then  -- Only process when clock enable is high
                -- Shift operation
                for i in 7 downto 1 loop
                    shift_reg(i) <= shift_reg(i-1);
                end loop;
                shift_reg(0) <= data_in;
                
                -- Increment counter
                if counter = 7 then
                    counter <= (others => '0');
                    -- Output packed data when we have 8 words
                    data_out_reg <= shift_reg(7) & shift_reg(6) & shift_reg(5) & shift_reg(4) & 
                                   shift_reg(3) & shift_reg(2) & shift_reg(1) & shift_reg(0);
                else
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Connect output
    data_out <= data_out_reg;

end Behavioral;
