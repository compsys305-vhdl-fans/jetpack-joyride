LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY lib_vga_pll;
LIBRARY hardware;
USE hardware.vga_types.ALL;
USE work.obstacle_types.ALL;

ENTITY top_jetpack_joyride IS
    PORT (
        clock_50 : IN STD_LOGIC;
        key : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        sw : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

        ledr : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        hex0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex3 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex4 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex5 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);

        ps2_clk : INOUT STD_LOGIC;
        ps2_dat : INOUT STD_LOGIC;

        vga_r : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        vga_g : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        vga_b : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        vga_hs : OUT STD_LOGIC;
        vga_vs : OUT STD_LOGIC
    );
END ENTITY top_jetpack_joyride;

ARCHITECTURE rtl OF top_jetpack_joyride IS
    -- here we would declare components
    COMPONENT mouse IS
        PORT (
            clock_25Mhz, reset	 		: IN STD_LOGIC;
            mouse_data					: INOUT STD_LOGIC;
            mouse_clk 					: INOUT STD_LOGIC;
            left_button, right_button	: OUT STD_LOGIC;
            out_mouse_x 				: OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            out_mouse_y 				: OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
        );
    END COMPONENT mouse;

    COMPONENT vga IS
        PORT (
            clock_25MHz : IN STD_LOGIC;
            r_in        : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            g_in        : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            b_in        : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            r_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            g_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            b_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            hsync       : OUT STD_LOGIC;
            vsync       : OUT STD_LOGIC;
            in_screen   : OUT STD_LOGIC;
            screen      : OUT SCREEN
        );
    END COMPONENT vga;

    COMPONENT lfsr IS
        PORT (
            clock : IN STD_LOGIC;
            reset : IN STD_LOGIC;
            enable : IN STD_LOGIC;
            mouse_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            mouse_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            load : IN STD_LOGIC;
            random_out : OUT STD_LOGIC_VECTOR(19 DOWNTO 0)
        );
    END COMPONENT lfsr;

    COMPONENT game IS
        PORT (
            clock_50MHz, vert_sync : IN STD_LOGIC;
            mouse_left : IN STD_LOGIC;
            debug_vehicle_select : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            playing : OUT STD_LOGIC;
            player_vehicle : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            player_vy : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            grounded : OUT STD_LOGIC;
            teleporter_preview_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
        );
    END COMPONENT game;

    COMPONENT collision_detector IS
        PORT (
            clock_25MHz          : IN STD_LOGIC;
            vert_sync            : IN STD_LOGIC;
            pixel_x              : IN UNSIGNED(9 DOWNTO 0);
            pixel_y              : IN UNSIGNED(9 DOWNTO 0);
            player_y             : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            player_vehicle       : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            left_button          : IN STD_LOGIC;
            player_grounded      : IN STD_LOGIC;
            player_vy            : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            laser_pool           : IN laser_pool_t;
            frame_count          : IN UNSIGNED(7 DOWNTO 0);
            death                : OUT STD_LOGIC
        );
    END COMPONENT collision_detector;
    
    COMPONENT obstacle_manager IS
        PORT (
            clock_50MHz      : IN STD_LOGIC;
            vert_sync        : IN STD_LOGIC;
            reset            : IN STD_LOGIC;
            playing          : IN STD_LOGIC;
            random_in        : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
            lasers_out       : OUT laser_pool_t
        );
    END COMPONENT obstacle_manager;
    
    COMPONENT renderer IS
        PORT (
            clock_25MHz          : IN STD_LOGIC;
            pixel_x              : IN UNSIGNED(9 DOWNTO 0);
            pixel_y              : IN UNSIGNED(9 DOWNTO 0);
    
            player_y             : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            player_vehicle       : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            left_button          : IN STD_LOGIC;
            player_grounded      : IN STD_LOGIC;
            player_vy            : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            teleporter_preview_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    
            laser_pool           : IN laser_pool_t;
            frame_count          : IN UNSIGNED(7 DOWNTO 0);
            
            red_out              : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            green_out            : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            blue_out             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
    END COMPONENT renderer;

    COMPONENT vga_pll IS
        PORT (
            refclk   : IN STD_LOGIC;
            rst      : IN STD_LOGIC;
            outclk_0 : OUT STD_LOGIC;
            locked   : OUT STD_LOGIC
        );
    END COMPONENT vga_pll;

    SIGNAL clock_25 : STD_LOGIC := '0';
    SIGNAL vga_pll_locked : STD_LOGIC := '0';

    -- player signals
    SIGNAL player_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL player_vy : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL player_grounded : STD_LOGIC;
    SIGNAL playing : STD_LOGIC;
    SIGNAL player_vehicle : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL debug_vehicle_select : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL teleporter_preview_y : STD_LOGIC_VECTOR(9 DOWNTO 0);

    -- mouse signals
    SIGNAL left_button, right_button : STD_LOGIC;
    SIGNAL mouse_x, mouse_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL mouse_reset : STD_LOGIC := '0';

    -- vga signals
    SIGNAL screen_pos : SCREEN;
    SIGNAL pixel_row, pixel_column : STD_LOGIC_VECTOR(9 DOWNTO 0);

    SIGNAL red_sig, green_sig, blue_sig : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_red, vga_green, vga_blue : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_vsync_sig : STD_LOGIC;

    SIGNAL lfsr_reset : STD_LOGIC := '0';
    SIGNAL random_num : STD_LOGIC_VECTOR(19 DOWNTO 0);

    -- laser signals
    SIGNAL frame_counter : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');

    -- laser pool
    SIGNAL laser_pool : laser_pool_t;

    -- death signal
    SIGNAL death_signal : STD_LOGIC;
	 
BEGIN
    vga_pll_inst: ENTITY lib_vga_pll.vga_pll
        PORT MAP (
            refclk => clock_50,
            rst => NOT key(0),
            outclk_0 => clock_25,
            locked => vga_pll_locked
        );

    obstacle_manager_inst: ENTITY work.obstacle_manager
        PORT MAP (
            clock_50MHz => clock_50,
            vert_sync => vga_vsync_sig,
            reset => mouse_reset,
            playing => playing,
            random_in => random_num,
            lasers_out => laser_pool
        );

    mouse_inst: mouse port map(
        clock_25Mhz => clock_25,
        reset => mouse_reset,
        mouse_data => ps2_dat,
        mouse_clk => ps2_clk,
        left_button => left_button,
        right_button => right_button,
        out_mouse_x => mouse_x,
        out_mouse_y => mouse_y
    );

    vga_inst: vga port map(
        clock_25MHz => clock_25,
        r_in => red_sig,
        g_in => green_sig,
        b_in => blue_sig,
        r_out => vga_red,
        g_out => vga_green,
        b_out => vga_blue,
        hsync => vga_hs,
        vsync => vga_vsync_sig,
        in_screen => open,  -- currently unused
        screen => screen_pos
    );

    pixel_column <= STD_LOGIC_VECTOR(TO_UNSIGNED(screen_pos.pixel_x, 10));
    pixel_row <= STD_LOGIC_VECTOR(TO_UNSIGNED(screen_pos.pixel_y, 10));

    vga_r <= vga_red;
    vga_g <= vga_green;
    vga_b <= vga_blue;
    vga_vs <= vga_vsync_sig;
    debug_vehicle_select <= sw(1 DOWNTO 0);

    lfsr_inst: lfsr port map(
        clock => clock_50,
        reset => lfsr_reset, -- currently unused
        enable => '1',  -- always enabled
        mouse_x => mouse_x,
        mouse_y => mouse_y,
        load => left_button,  -- re-seed on left click
        random_out => random_num
    );

    game_inst: game
        PORT MAP (
        clock_50MHz => clock_50,
        vert_sync => vga_vsync_sig,
        mouse_left => left_button,
        debug_vehicle_select => debug_vehicle_select,
        playing => playing,
        player_vehicle => player_vehicle,
        player_y => player_y,
        player_vy => player_vy,
        grounded => player_grounded,
        teleporter_preview_y => teleporter_preview_y
    );

    collision_detector_inst: ENTITY work.collision_detector
    PORT MAP (
        clock_25MHz => clock_25,
        vert_sync => vga_vsync_sig,
        pixel_x => UNSIGNED(pixel_column),
        pixel_y => UNSIGNED(pixel_row),
        player_y => player_y,
        player_vehicle => player_vehicle,
        left_button => left_button,
        player_grounded => player_grounded,
        player_vy => player_vy,
        laser_pool => laser_pool,
        frame_count => frame_counter,
        death => death_signal
    );
    
    renderer_inst: ENTITY work.renderer
    PORT MAP (
        clock_25MHz => clock_25,
        pixel_x => UNSIGNED(pixel_column),
        pixel_y => UNSIGNED(pixel_row),
        player_y => player_y,
        player_vehicle => player_vehicle,
        left_button => left_button,
        player_grounded => player_grounded,
        player_vy => player_vy,
        teleporter_preview_y => teleporter_preview_y,
        laser_pool => laser_pool,
        frame_count => frame_counter,
        red_out => red_sig,
        green_out => green_sig,
        blue_out => blue_sig
    );

    mouse_reset <= NOT KEY(0);  -- active low reset
    ledr(1 DOWNTO 0) <= player_vehicle;
    ledr(9) <= death_signal;
    ledr(8 DOWNTO 2) <= sw(8 DOWNTO 2);

    -- unused currently, but we should map this to score eventually when it exists
    hex0 <= "0000000";
    hex1 <= "0000000";
    hex2 <= "0000000";
    hex3 <= "0000000";
    hex4 <= "0000000";
    hex5 <= "0000000";

    PROCESS(vga_vsync_sig)
    BEGIN
        IF RISING_EDGE(vga_vsync_sig) THEN
            frame_counter <= frame_counter + 1;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
