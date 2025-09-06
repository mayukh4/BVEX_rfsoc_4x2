library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dynamic_requantizer is
    Generic (
        -- Add generics for Xilinx compatibility
        C_S_AXI_DATA_WIDTH : integer := 32
    );
    Port (
        clk         : in  std_logic;
        ce          : in  std_logic := '1';  -- Clock enable for Xilinx
        rst         : in  std_logic;
        -- Input: 8 complex samples (16 total 16-bit values)
        data_in     : in  std_logic_vector(255 downto 0);
        -- Output: 8 complex samples (16 total 2-bit values)
        data_out    : out std_logic_vector(31 downto 0)
    );
end dynamic_requantizer;

architecture Behavioral of dynamic_requantizer is
    -- Constants
    constant SAMPLE_WIDTH : integer := 16;
    constant NUM_SAMPLES : integer := 16;
    
    -- Registers for pipelining
    signal data_in_reg : std_logic_vector(255 downto 0);
    signal data_out_reg : std_logic_vector(31 downto 0);
    
    -- Fixed thresholds for simplicity
    signal upper_thresh : signed(SAMPLE_WIDTH-1 downto 0) := to_signed(1000, SAMPLE_WIDTH);
    signal lower_thresh : signed(SAMPLE_WIDTH-1 downto 0) := to_signed(-1000, SAMPLE_WIDTH);
    signal mean_value : signed(SAMPLE_WIDTH-1 downto 0) := (others => '0');
    
    -- Xilinx attributes for timing
    attribute use_dsp : string;
    attribute use_dsp of Behavioral : architecture is "no";
    
begin

    -- Synchronous process with clock enable
    process(clk)
        variable current_sample : signed(SAMPLE_WIDTH-1 downto 0);
        variable quantized_value : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                data_out_reg <= (others => '0');
                data_in_reg <= (others => '0');
            elsif ce = '1' then  -- Only process when clock enable is high
                -- Register inputs
                data_in_reg <= data_in;
                
                -- Process all samples
                for i in 0 to NUM_SAMPLES-1 loop
                    current_sample := signed(data_in_reg((i+1)*SAMPLE_WIDTH-1 downto i*SAMPLE_WIDTH));
                    
                    -- 2-bit quantization logic
                    if current_sample > upper_thresh then
                        quantized_value := "11";
                    elsif current_sample > mean_value then
                        quantized_value := "10";
                    elsif current_sample > lower_thresh then
                        quantized_value := "01";
                    else
                        quantized_value := "00";
                    end if;
                    
                    -- Pack into output register
                    data_out_reg(i*2+1 downto i*2) <= quantized_value;
                end loop;
            end if;
        end if;
    end process;
    
    -- Connect output
    data_out <= data_out_reg;

end Behavioral;
