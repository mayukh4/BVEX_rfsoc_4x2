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
        ce          : in  std_logic := '1';  -- Clock enable for Xilinx
        rst         : in  std_logic;
        
        -- Input signals
        sync_pps    : in  std_logic;         -- 1PPS signal from GPS/timing source
        arm_pps     : in  std_logic;         -- Arming/enable signal
        
        -- Output counters
        pps_cnt     : out std_logic_vector(31 downto 0);     -- PPS counter
        cycles_per_pps : out std_logic_vector(31 downto 0);  -- Clock cycles between PPS pulses
        
        -- DEBUG OUTPUTS - Add these to your Simulink as software registers!
        debug_sync_pps    : out std_logic_vector(31 downto 0);  -- Raw PPS input
        debug_pps_edge    : out std_logic_vector(31 downto 0);  -- Edge detection signal
        debug_arm_pps     : out std_logic_vector(31 downto 0);  -- Arm signal
        debug_ce          : out std_logic_vector(31 downto 0);  -- Clock enable
        debug_reset_count : out std_logic_vector(31 downto 0);  -- Count of resets executed
        debug_sync_z1     : out std_logic_vector(31 downto 0);  -- Sync stage 1
        debug_sync_z2     : out std_logic_vector(31 downto 0);  -- Sync stage 2
        debug_sync_z3     : out std_logic_vector(31 downto 0)   -- Sync stage 3
    );
end timestamp_gen_simple;

architecture Behavioral of timestamp_gen_simple is
    -- VLBI/VDIF Epoch: January 1, 2000 00:00:00 UTC
    constant INITIAL_VDIF_SECONDS : unsigned(31 downto 0) := to_unsigned(788918400, 32);
    
    -- Internal registers
    signal pps_cnt_reg     : unsigned(31 downto 0) := INITIAL_VDIF_SECONDS;
    signal cycles_per_pps_reg : unsigned(31 downto 0) := (others => '0');
    signal last_cycles_per_pps : unsigned(31 downto 0) := (others => '0');
    
    -- 3-stage synchronizer
    signal sync_pps_z1     : std_logic := '0';
    signal sync_pps_z2     : std_logic := '0';  
    signal sync_pps_z3     : std_logic := '0';
    signal pps_rising_edge : std_logic := '0';
    
    -- DEBUG SIGNALS
    signal reset_count : unsigned(31 downto 0) := (others => '0');  -- Count actual resets
    
    attribute use_dsp : string;
    attribute use_dsp of Behavioral : architecture is "no";
    
    attribute keep : string;
    attribute keep of pps_rising_edge : signal is "true";
    attribute keep of pps_cnt_reg : signal is "true";
    attribute keep of cycles_per_pps_reg : signal is "true";
    attribute keep of last_cycles_per_pps : signal is "true";
    
begin

    -- Synchronizer process
    sync_process: process(clk)
    begin
        if rising_edge(clk) then
            -- Synchronizer ALWAYS runs (not gated by ce)
            sync_pps_z1 <= sync_pps;
            sync_pps_z2 <= sync_pps_z1;
            sync_pps_z3 <= sync_pps_z2;
            
            -- Edge detection
            pps_rising_edge <= sync_pps_z2 and not sync_pps_z3;
        end if;
    end process;

    -- Main counter process
    counter_process: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pps_cnt_reg <= INITIAL_VDIF_SECONDS;
                cycles_per_pps_reg <= (others => '0');
                last_cycles_per_pps <= (others => '0');
                reset_count <= (others => '0');
                
            elsif ce = '1' then
                -- Check for PPS edge and reset condition
                if arm_pps = '1' and pps_rising_edge = '1' then
                    -- PPS detected - increment PPS counter and reset cycles
                    pps_cnt_reg <= pps_cnt_reg + 1;
                    last_cycles_per_pps <= cycles_per_pps_reg;
                    cycles_per_pps_reg <= (others => '0');
                    reset_count <= reset_count + 1;  -- DEBUG: Count actual resets
                    
                elsif arm_pps = '1' then
                    -- Normal operation - just increment cycles
                    cycles_per_pps_reg <= cycles_per_pps_reg + 1;
                    
                else
                    -- arm_pps = '0' - still increment cycles but no PPS handling
                    cycles_per_pps_reg <= cycles_per_pps_reg + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Main outputs
    pps_cnt <= std_logic_vector(pps_cnt_reg);
    cycles_per_pps <= std_logic_vector(last_cycles_per_pps);
    
    -- DEBUG OUTPUTS - Connect these to software registers in Simulink!
    debug_sync_pps    <= x"0000000" & "000" & sync_pps;
    debug_pps_edge    <= x"0000000" & "000" & pps_rising_edge;
    debug_arm_pps     <= x"0000000" & "000" & arm_pps;
    debug_ce          <= x"0000000" & "000" & ce;
    debug_reset_count <= std_logic_vector(reset_count);
    debug_sync_z1     <= x"0000000" & "000" & sync_pps_z1;
    debug_sync_z2     <= x"0000000" & "000" & sync_pps_z2;
    debug_sync_z3     <= x"0000000" & "000" & sync_pps_z3;

end Behavioral;
