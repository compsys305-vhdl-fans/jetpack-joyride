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
            enable : IN STD_LOGIC;
            mouse_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            mouse_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            load : IN STD_LOGIC;
            random_out : OUT STD_LOGIC_VECTOR(19 DOWNTO 0)
        );
    END COMPONENT lfsr;

    COMPONENT game IS
        PORT (
            clock_50MHz, vert_sync, reset : IN STD_LOGIC;
            mouse_left : IN STD_LOGIC;
            mouse_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            mouse_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            death_signal : IN STD_LOGIC;
            powerup_collected : IN STD_LOGIC;
            coin_collected : IN STD_LOGIC;
            random_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            screen_flash : OUT STD_LOGIC;
            debug_vehicle_select : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            playing : OUT STD_LOGIC;
            is_dead : OUT STD_LOGIC;
            menu_active : OUT STD_LOGIC;
            training_mode : OUT STD_LOGIC;
            player_vehicle : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            player_vy : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            grounded : OUT STD_LOGIC;
            teleporter_preview_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            world_speed : OUT UNSIGNED(9 DOWNTO 0);
            score_digits_out : OUT STD_LOGIC_VECTOR(27 DOWNTO 0)
        );
    END COMPONENT game;

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
    SIGNAL menu_active : STD_LOGIC;
    SIGNAL training_mode : STD_LOGIC;
    SIGNAL player_vehicle : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL debug_vehicle_select : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL teleporter_preview_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL world_speed : UNSIGNED(9 DOWNTO 0);

    -- mouse signals
    SIGNAL left_button, right_button : STD_LOGIC;
    SIGNAL mouse_x, mouse_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL mouse_reset : STD_LOGIC := '0';

    -- vga signals
    SIGNAL screen_pos : SCREEN;
    SIGNAL pixel_row, pixel_column : STD_LOGIC_VECTOR(9 DOWNTO 0);

    SIGNAL red_sig, green_sig, blue_sig : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL render_red, render_green, render_blue : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL collision_red, collision_green, collision_blue : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_red, vga_green, vga_blue : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_vsync_sig : STD_LOGIC;

    SIGNAL paused : STD_LOGIC := '0';
    SIGNAL key0_prev : STD_LOGIC := '1';
    SIGNAL update_tick : STD_LOGIC := '0';

    SIGNAL random_num : STD_LOGIC_VECTOR(19 DOWNTO 0);

    -- laser signals
    SIGNAL frame_counter : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');

    -- laser pool
    SIGNAL laser_pool : laser_pool_t;
    SIGNAL missile_pool : missile_pool_t;
    SIGNAL coin_pool : coin_pool_t := INACTIVE_COIN_POOL;
    SIGNAL powerup_pool : powerup_pool_t := INACTIVE_POWERUP_POOL;
    SIGNAL powerup_collected : STD_LOGIC;
    SIGNAL coin_collected : STD_LOGIC;
    SIGNAL coin_collected_idx : UNSIGNED(2 DOWNTO 0);
    SIGNAL screen_flash : STD_LOGIC;
    SIGNAL score_value : STD_LOGIC_VECTOR(27 DOWNTO 0);
    -- death signal
    SIGNAL death_raw : STD_LOGIC;
    SIGNAL death_signal : STD_LOGIC;
    SIGNAL obstacles_enabled : STD_LOGIC;

    SIGNAL score_digit0 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL score_digit1 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL score_digit2 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL score_digit3 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL score_digit4 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL score_digit5 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    FUNCTION seven_seg_digit(digit : STD_LOGIC_VECTOR(3 DOWNTO 0)) RETURN STD_LOGIC_VECTOR IS
    BEGIN
        CASE digit IS
            WHEN x"0" => RETURN "1000000";
            WHEN x"1" => RETURN "1111001";
            WHEN x"2" => RETURN "0100100";
            WHEN x"3" => RETURN "0110000";
            WHEN x"4" => RETURN "0011001";
            WHEN x"5" => RETURN "0010010";
            WHEN x"6" => RETURN "0000010";
            WHEN x"7" => RETURN "1111000";
            WHEN x"8" => RETURN "0000000";
            WHEN x"9" => RETURN "0010000";
            WHEN OTHERS => RETURN "1111111";
        END CASE;
    END FUNCTION seven_seg_digit;

BEGIN
    vga_pll_inst: ENTITY lib_vga_pll.vga_pll
        PORT MAP (
            refclk => clock_50,
            rst => NOT key(3),
            outclk_0 => clock_25,
            locked => vga_pll_locked
        );

    PROCESS(clock_50, menu_active, death_signal)
    BEGIN
        IF RISING_EDGE(clock_50) THEN
            IF key0_prev = '1' AND key(0) = '0' AND menu_active = '0' AND death_signal = '0' THEN
                paused <= NOT paused;
            END IF;
            key0_prev <= key(0);
        END IF;
    END PROCESS;

    update_tick <= vga_vsync_sig AND (NOT paused);
    obstacles_enabled <= playing;

    obstacle_manager_inst: ENTITY work.obstacle_manager
        PORT MAP (
            vert_sync => update_tick,
            reset => mouse_reset,
            playing => obstacles_enabled,
            random_in => random_num,
            world_speed => world_speed,
            player_y => player_y,
            player_vehicle => player_vehicle,
            coin_collected => coin_collected,
            coin_collected_idx => coin_collected_idx,
            lasers_out => laser_pool,
            missiles_out => missile_pool,
            coins_out => coin_pool,
            powerups_out => powerup_pool
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
        enable => '1',  -- always enabled
        mouse_x => mouse_x,
        mouse_y => mouse_y,
        load => left_button,  -- re-seed on left click
        random_out => random_num
    );

    game_inst: game
        PORT MAP (
        clock_50MHz => clock_50,
        vert_sync => update_tick,
        reset => mouse_reset,
        mouse_left => left_button,
        mouse_x => mouse_x,
        mouse_y => mouse_y,
        death_signal => death_raw,
        powerup_collected => powerup_collected,
        coin_collected => coin_collected,
        random_in => random_num(1 DOWNTO 0),
        screen_flash => screen_flash,
        debug_vehicle_select => debug_vehicle_select,
        playing => playing,
        is_dead => death_signal,
        menu_active => menu_active,
        training_mode => training_mode,
        player_vehicle => player_vehicle,
        player_y => player_y,
        player_vy => player_vy,
        grounded => player_grounded,
        teleporter_preview_y => teleporter_preview_y,
        world_speed => world_speed,
        score_digits_out => score_value
    );

    collision_detector_inst: ENTITY work.collision_detector
    PORT MAP (
        clock_25MHz => clock_25,
        vert_sync => update_tick,
        pixel_x => UNSIGNED(pixel_column),
        pixel_y => UNSIGNED(pixel_row),
        player_y => player_y,
        player_vehicle => player_vehicle,
        left_button => left_button,
        player_grounded => player_grounded,
        player_vy => player_vy,
        laser_pool => laser_pool,
        missile_pool => missile_pool,
        coin_pool => coin_pool,
        powerup_pool => powerup_pool,
        death => death_raw,
        powerup_collected => powerup_collected,
        coin_collected => coin_collected,
        coin_collected_idx => coin_collected_idx,
        collision_red => collision_red,
        collision_green => collision_green,
        collision_blue => collision_blue
    );

    renderer_inst: ENTITY work.renderer
    PORT MAP (
        clock_25MHz => clock_25,
        show_djt => sw(6),
        pixel_x => UNSIGNED(pixel_column),
        pixel_y => UNSIGNED(pixel_row),
        player_y => player_y,
        player_vehicle => player_vehicle,
        left_button => left_button,
        player_grounded => player_grounded,
        player_vy => player_vy,
        teleporter_preview_y => teleporter_preview_y,
        death => death_signal,
        paused => paused,
        menu_active => menu_active,
        mouse_x => mouse_x,
        mouse_y => mouse_y,
        laser_pool => laser_pool,
        missile_pool => missile_pool,
        coin_pool => coin_pool,
        powerup_pool => powerup_pool,
        screen_flash => screen_flash,
        score_digits_in => score_value,
        frame_count => frame_counter,
        random_in => random_num,
        world_speed => world_speed,
        red_out => render_red,
        green_out => render_green,
        blue_out => render_blue
    );

    PROCESS(sw, render_red, render_green, render_blue, collision_red, collision_green, collision_blue)
    BEGIN
        IF sw(9) = '1' THEN
            red_sig <= collision_red;
            green_sig <= collision_green;
            blue_sig <= collision_blue;
        ELSE
            red_sig <= render_red;
            green_sig <= render_green;
            blue_sig <= render_blue;
        END IF;
    END PROCESS;

    mouse_reset <= NOT KEY(3);  -- active low reset
    ledr(1 DOWNTO 0) <= player_vehicle;
    ledr(9) <= death_signal;
    ledr(8 DOWNTO 2) <= sw(8 DOWNTO 2);

    hex0 <= seven_seg_digit(score_digit0);
    hex1 <= seven_seg_digit(score_digit1);
    hex2 <= seven_seg_digit(score_digit2);
    hex3 <= seven_seg_digit(score_digit3);
    hex4 <= seven_seg_digit(score_digit4);
    hex5 <= seven_seg_digit(score_digit5);

    PROCESS(update_tick)
    BEGIN
        IF RISING_EDGE(update_tick) THEN
            score_digit0 <= score_value(3 DOWNTO 0);
            score_digit1 <= score_value(7 DOWNTO 4);
            score_digit2 <= score_value(11 DOWNTO 8);
            score_digit3 <= score_value(15 DOWNTO 12);
            score_digit4 <= score_value(19 DOWNTO 16);
            score_digit5 <= score_value(23 DOWNTO 20);
        END IF;
    END PROCESS;

    PROCESS(update_tick)
    BEGIN
        IF RISING_EDGE(update_tick) THEN
            frame_counter <= frame_counter + 1;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
