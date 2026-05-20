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
        PORT (
            clock_50MHz, vert_sync : IN STD_LOGIC;
            mouse_left : IN STD_LOGIC;
            debug_vehicle_select : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            playing : OUT STD_LOGIC;
            player_vehicle : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
        );
    END COMPONENT game;

    SIGNAL clock_25 : STD_LOGIC := '0';

    -- player signals
    SIGNAL player_on : STD_LOGIC;
    SIGNAL player_y : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL playing : STD_LOGIC;
    SIGNAL player_vehicle : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL debug_vehicle_select : STD_LOGIC_VECTOR(1 DOWNTO 0);

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

    -- lfsr signals
    SIGNAL lfsr_reset : STD_LOGIC := '0';
    SIGNAL random_num : STD_LOGIC_VECTOR(19 DOWNTO 0);

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

    game_inst: game port map(
        clock_50MHz => clock_50,
        vert_sync => vga_vsync_sig,
        mouse_left => left_button,
        debug_vehicle_select => debug_vehicle_select,
        playing => playing,
        player_vehicle => player_vehicle,
        player_y => player_y
    );

    mouse_reset <= NOT KEY(0);  -- active low reset
    ledr(1 DOWNTO 0) <= player_vehicle;
    ledr(9 DOWNTO 2) <= sw(9 DOWNTO 2);

    -- illuminate the whole row of the player's y position, to test that the player_y signal is working correctly
    PROCESS (pixel_row, player_y)
    BEGIN
        IF (pixel_row = player_y) THEN
            player_on <= '1';
        ELSE
            player_on <= '0';
        END IF;
    END PROCESS;

    PROCESS (player_on) BEGIN
        IF player_on = '1' THEN
            red_sig <= x"8";
            green_sig <= x"A";
            blue_sig <= x"F";
        ELSE
            red_sig <= (OTHERS => '0');
            green_sig <= (OTHERS => '0');
            blue_sig <= (OTHERS => '0');
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
