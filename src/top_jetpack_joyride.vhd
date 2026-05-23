LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY hardware;
USE hardware.vga_types.ALL;

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
        GENERIC (
            PLAYER_HEIGHT : POSITIVE
        );
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

    COMPONENT sprite_renderer IS
        PORT (
            clock          : IN STD_LOGIC;
            sprite_id      : IN UNSIGNED(7 DOWNTO 0);
            palette_id     : IN UNSIGNED(7 DOWNTO 0);
            scale_shift    : IN NATURAL;
            rel_x          : IN UNSIGNED(15 DOWNTO 0);
            rel_y          : IN UNSIGNED(15 DOWNTO 0);
            color          : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            is_transparent : OUT STD_LOGIC;
            valid          : OUT STD_LOGIC
        );
    END COMPONENT sprite_renderer;

    COMPONENT strand_effect IS
        PORT (
            clock       : IN STD_LOGIC;
            pixel_x     : IN UNSIGNED(9 DOWNTO 0);
            pixel_y     : IN UNSIGNED(9 DOWNTO 0);
            frame_count : IN UNSIGNED(7 DOWNTO 0);
            r_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            g_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            b_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
    END COMPONENT strand_effect;

    SIGNAL clock_25 : STD_LOGIC := '0';

    -- player signals
    SIGNAL player_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL player_vy : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL player_grounded : STD_LOGIC;
    SIGNAL player_y_render : UNSIGNED(9 DOWNTO 0);
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

    SIGNAL sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL sprite_valid : STD_LOGIC;

    -- lfsr signals
    CONSTANT MAX_PLAYER_HEIGHT : POSITIVE := 64;
    SIGNAL lfsr_reset : STD_LOGIC := '0';
    SIGNAL random_num : STD_LOGIC_VECTOR(19 DOWNTO 0);

    CONSTANT PLAYER_X : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(120, 10);
    -- Default sprite is 16x16, scaled by 2 = 32x32
    -- Lil Stomper is 64x64, not scaled
    SIGNAL player_sprite_width : POSITIVE := 16;
    SIGNAL player_sprite_height : POSITIVE := 16;
    SIGNAL player_scale_shift : NATURAL := 1;
    SIGNAL player_display_width : POSITIVE := 32;
    SIGNAL player_display_height : POSITIVE := 32;
    SIGNAL teleporter_preview_on : STD_LOGIC;
    SIGNAL player_palette_id : UNSIGNED(7 DOWNTO 0);

    SIGNAL player_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL player_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_player_sprite : STD_LOGIC;
    SIGNAL player_is_transparent : STD_LOGIC;

    SIGNAL player_drawn : STD_LOGIC;
    SIGNAL in_player_sprite_d : STD_LOGIC := '0';

    SIGNAL player_sprite_id : UNSIGNED(7 DOWNTO 0);

    -- strand effect signals
    SIGNAL frame_counter : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL strand_r, strand_g, strand_b : STD_LOGIC_VECTOR(3 DOWNTO 0);

BEGIN
    -- placeholder; we should have port maps and stuff, but ideally no logic here (apart from logic inversion for active-low buttons and stuff)
    -- clock divider to generate 25MHz from 50MHz
    clk_div: PROCESS (clock_50) BEGIN
        IF RISING_EDGE(clock_50) THEN
            clock_25 <= NOT clock_25;
        END IF;
    END PROCESS clk_div;

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
        GENERIC MAP (
            PLAYER_HEIGHT => MAX_PLAYER_HEIGHT
        )
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

    PROCESS (pixel_column, pixel_row, player_y_render)
        VARIABLE s_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_y : UNSIGNED(15 DOWNTO 0);
    BEGIN
        s_x := RESIZE(UNSIGNED(pixel_column), 16);
        s_y := RESIZE(UNSIGNED(pixel_row), 16);
        p_x := RESIZE(PLAYER_X, 16);
        p_y := RESIZE(player_y_render, 16);
        
        IF (s_x >= p_x) AND (s_x < p_x + TO_UNSIGNED(player_display_width, 16)) AND
           (s_y >= p_y) AND (s_y < p_y + TO_UNSIGNED(player_display_height, 16)) THEN
            in_player_sprite <= '1';
            player_rel_x <= s_x - p_x;
            player_rel_y <= s_y - p_y;
        ELSE
            in_player_sprite <= '0';
        END IF;
    END PROCESS;

    player_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25,
            sprite_id      => player_sprite_id,
            palette_id     => player_palette_id,
            scale_shift    => player_scale_shift,
            rel_x          => player_rel_x,
            rel_y          => player_rel_y,
            color          => sprite_color,
            is_transparent => player_is_transparent,
            valid          => sprite_valid
        );

    mouse_reset <= NOT KEY(0);  -- active low reset
    ledr(1 DOWNTO 0) <= player_vehicle;
    ledr(9 DOWNTO 2) <= sw(9 DOWNTO 2);

    PROCESS (pixel_row, teleporter_preview_y)
    BEGIN
        IF UNSIGNED(pixel_row) = UNSIGNED(teleporter_preview_y) THEN
            teleporter_preview_on <= '1';
        ELSE
            teleporter_preview_on <= '0';
        END IF;
    END PROCESS;

    PROCESS(clock_25)
    BEGIN
        IF RISING_EDGE(clock_25) THEN
            in_player_sprite_d <= in_player_sprite;
        END IF;
    END PROCESS;

    PROCESS(player_vehicle, left_button, player_grounded, player_vy)
    BEGIN
        IF player_vehicle = "00" THEN
            -- Jetpack gamemode: active sprite only when holding down
            player_palette_id <= x"00"; -- Barry
            player_scale_shift <= 1;
            player_display_width <= 32;
            player_display_height <= 32;
            IF left_button = '1' THEN
                player_sprite_id <= x"02";
            ELSE
                player_sprite_id <= x"00";
            END IF;
        ELSIF player_vehicle = "01" THEN
            player_palette_id <= x"01"; -- Lil Stomper
            player_scale_shift <= 0;
            player_display_width <= 64;
            player_display_height <= 64;
            -- Lil Stomper gamemode: flying sprite when player holding down and in the air, and if not holding, falling sprite, but if on ground, show running sprite
            IF player_grounded = '1' THEN
                player_sprite_id <= x"10";
            ELSIF left_button = '1' THEN
                player_sprite_id <= x"11";
            ELSE
                player_sprite_id <= x"12";
            END IF;
        ELSIF player_vehicle = "10" THEN -- Bird
            player_palette_id <= x"02"; -- Bird
            player_scale_shift <= 0;
            player_display_width <= 32;
            player_display_height <= 32;
            IF player_vy(9) = '1' THEN
                player_sprite_id <= x"20";
            ELSE
                player_sprite_id <= x"21";
            END IF;
        ELSIF player_vehicle = "11" THEN -- Teleporter
            player_palette_id <= x"03"; -- Teleporter
            player_scale_shift <= 0;
            player_display_width <= 32;
            player_display_height <= 32;
            player_sprite_id <= x"30";
        END IF;
    END PROCESS;

    -- The game component calculates physics based on the largest possible player sprite (64x64).
    -- player_y from the game component represents the *top* of this collision box.
    -- For smaller sprites, we need to add an offset to their render position so they appear grounded at the bottom of the collision box.
    -- We calculate the top of the sprite for rendering.
    player_y_render <= UNSIGNED(player_y) + TO_UNSIGNED(MAX_PLAYER_HEIGHT - player_display_height, 10);

    player_drawn <= in_player_sprite_d AND sprite_valid AND (NOT player_is_transparent);

    strand_inst: strand_effect
        PORT MAP(
            clock => clock_25,
            pixel_x => UNSIGNED(pixel_column),
            pixel_y => UNSIGNED(pixel_row),
            frame_count => frame_counter,
            r_out => strand_r,
            g_out => strand_g,
            b_out => strand_b
        );

    PROCESS(vga_vsync_sig)
    BEGIN
        IF RISING_EDGE(vga_vsync_sig) THEN
            frame_counter <= frame_counter + 1;
        END IF;
    END PROCESS;

    PROCESS (player_drawn, sprite_color, teleporter_preview_on, pixel_row, strand_r, strand_g, strand_b) BEGIN
        IF player_drawn = '1' THEN
            red_sig <= sprite_color(11 DOWNTO 8);
            green_sig <= sprite_color(7 DOWNTO 4);
            blue_sig <= sprite_color(3 DOWNTO 0);
        ELSIF teleporter_preview_on = '1' THEN
            red_sig <= x"F";
            green_sig <= x"6";
            blue_sig <= x"0";
        ELSIF (TO_INTEGER(UNSIGNED(pixel_row)) >= 470) THEN
            red_sig <= x"8";
            green_sig <= x"8";
            blue_sig <= x"8";
        ELSE
            -- Map background to strand effect
            red_sig <= strand_r;
            green_sig <= strand_g;
            blue_sig <= strand_b;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
