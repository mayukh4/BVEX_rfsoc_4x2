library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity timestamp_gen_simple is
    Generic (
        -- Add generics for Xilinx compatibility
        C_S_AXI_DATA_WIDTH : integer := 32
    );
    Port (
        clk         : in  std_logic;
        ce          : in  std_logic := '1';  -- Clock enable for Xilinx Sysgen (I think...)
        rst         : in  std_logic;
        
        -- Input signals (matching Mitch's design exactly)
        sync_pps    : in  std_logic;         -- 1PPS signal from GPS/timing source
        arm_pps     : in  std_logic;         -- Arming/enable signal
        
        -- Output counters
        pps_cnt     : out std_logic_vector(31 downto 0);     -- PPS counter (seconds since VDIF epoch)
        cycles_per_pps : out std_logic_vector(31 downto 0)   -- Clock cycles between PPS pulses
    );
end timestamp_gen_simple;

architecture Behavioral of timestamp_gen_simple is
    -- VLBI/VDIF Epoch: January 1, 2000 00:00:00 UTC
    -- Current time (June 2025) is approximately 788918400 seconds since VDIF epoch
    constant INITIAL_VDIF_SECONDS : unsigned(31 downto 0) := to_unsigned(788918400, 32);
    
    -- Expected cycles per second at 256 MHz
    constant EXPECTED_CYCLES_PER_PPS : unsigned(31 downto 0) := to_unsigned(255999999, 32);
    
    -- Internal registers
    signal pps_cnt_reg     : unsigned(31 downto 0) := INITIAL_VDIF_SECONDS;
    signal cycles_per_pps_reg : unsigned(31 downto 0) := (others => '0');
    
    -- CRITICAL FIX: Added a capture register for stable cycles output
    signal last_cycles_per_pps : unsigned(31 downto 0) := (others => '0');
    
    -- 3-stage synchronizer (ALWAYS clocked, not gated by ce)
    signal sync_pps_z1     : std_logic := '0';  -- First delay register
    signal sync_pps_z2     : std_logic := '0';  -- Second delay register  
    signal sync_pps_z3     : std_logic := '0';  -- Third delay register (better MTBF)
    
    -- FIXED: Use signal for edge detection (not variable)
    signal pps_rising_edge : std_logic := '0';  -- Edge detection signal
    
    -- Xilinx attributes for timing optimization
    attribute use_dsp : string;
    attribute use_dsp of Behavioral : architecture is "no";
    
    attribute keep : string;
    attribute keep of pps_rising_edge : signal is "true";
    attribute keep of pps_cnt_reg : signal is "true";
    attribute keep of cycles_per_pps_reg : signal is "true";
    attribute keep of last_cycles_per_pps : signal is "true";
    
begin

    -- eparate synchronizer process
    sync_process: process(clk)
    begin
        if rising_edge(clk) then
            -- Synchronizer ALWAYS runs (not gated by ce)
            sync_pps_z1 <= sync_pps;      -- First stage
            sync_pps_z2 <= sync_pps_z1;   -- Second stage  
            sync_pps_z3 <= sync_pps_z2;   -- Third stage
            
            -- Edge detection using PREVIOUS clock values
            pps_rising_edge <= sync_pps_z2 and not sync_pps_z3;
        end if;
    end process;

    -- FIXED: Main counter process using signals
    counter_process: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset to known VDIF epoch time
                pps_cnt_reg <= INITIAL_VDIF_SECONDS;
                cycles_per_pps_reg <= (others => '0');
                last_cycles_per_pps <= (others => '0');
                
            elsif ce = '1' then
                -- FIXED: Use signal for edge detection (properly timed)
                if arm_pps = '1' and pps_rising_edge = '1' then
                    -- PPS pulse detected: increment seconds, capture then reset cycles
                    pps_cnt_reg <= pps_cnt_reg + 1;
                    last_cycles_per_pps <= cycles_per_pps_reg;  -- CAPTURE current count first
                    cycles_per_pps_reg <= (others => '0');     -- THEN reset for next second
                    
                elsif arm_pps = '1' then
                    -- Normal operation: increment cycle counter only
                    cycles_per_pps_reg <= cycles_per_pps_reg + 1;
                    
                else
                    -- If arm_pps = '0', still increment cycles but don't change PPS
                    cycles_per_pps_reg <= cycles_per_pps_reg + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Output assignments
    pps_cnt <= std_logic_vector(pps_cnt_reg);
    cycles_per_pps <= std_logic_vector(last_cycles_per_pps);  -- Stable captured value

end Behavioral;
