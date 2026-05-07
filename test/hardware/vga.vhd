LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

LIBRARY PROJECT_CONFIG;
USE PROJECT_CONFIG.TYPES.ALL;

ENTITY vga_tb IS
    PORT (
        success : OUT STD_LOGIC
    );
END vga_tb;

ARCHITECTURE behaviour OF vga_tb IS

    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT vga
        PORT(
            clock_25MHz : IN STD_LOGIC;
            r_in        : IN STD_LOGIC;
            g_in        : IN STD_LOGIC;
            b_in        : IN STD_LOGIC;
            r_out       : OUT STD_LOGIC;
            g_out       : OUT STD_LOGIC;
            b_out       : OUT STD_LOGIC;
            hsync       : OUT STD_LOGIC;
            vsync       : OUT STD_LOGIC;
            screen      : OUT SCREEN
        );
    END COMPONENT;

    --Inputs
    SIGNAL clock_25MHz  : STD_LOGIC := '0';
    SIGNAL r_in         : STD_LOGIC := '0';
    SIGNAL g_in         : STD_LOGIC := '0';
    SIGNAL b_in         : STD_LOGIC := '0';

    --Outputs
    SIGNAL r_out        : STD_LOGIC;
    SIGNAL g_out        : STD_LOGIC;
    SIGNAL b_out        : STD_LOGIC;
    SIGNAL hsync        : STD_LOGIC;
    SIGNAL vsync        : STD_LOGIC;
    SIGNAL screen       : SCREEN;
BEGIN

    -- Instantiate the Unit Under Test (UUT)
    uut: vga PORT MAP (
        clock_25MHz => clock_25MHz,
        r_in => r_in,
        g_in => g_in,
        b_in => b_in,
        r_out => r_out,
        g_out => g_out,
        b_out => b_out,
        hsync => hsync,
        vsync => vsync,
        screen => screen
    );

    clk_gen: PROCESS
    BEGIN
        clock_25MHz <= '0';
        WAIT FOR 20 NS;  -- 25 MHz clock period
        clock_25MHz <= '1';
        WAIT FOR 20 NS;
    END PROCESS clk_gen;

    -- Stimulus process - generate a screen's worth of pixels
    stim_proc: PROCESS
        VARIABLE pixels_generated : INTEGER := 0;
    BEGIN
        -- hold reset state for 100 ns.
        WAIT FOR 100 NS;

        -- generate pixels until we have generated a full screen
        WHILE pixels_generated < 640*480 LOOP
            -- use some arbitrary colour based on the pixel x y
            r_in <= STD_LOGIC'VAL((screen.pixel_x / 80) MOD 2);  -- change every 80 pixels
            g_in <= STD_LOGIC'VAL((screen.pixel_y / 60) MOD 2);  -- change every 60 pixels
            b_in <= STD_LOGIC'VAL(((screen.pixel_x + screen.pixel_y) / 100) MOD 2);  -- change every 100 pixels diagonally

            -- check if the value is what is expected, and if not, immediately stop loop, and fail test.

            WAIT FOR 40 NS;  -- wait for one pixel clock (25 MHz)
            pixels_generated := pixels_generated + 1;
        END LOOP;
        
        -- stop simulation after generating a full screen
        WAIT;
    END PROCESS stim_proc;
END ARCHITECTURE behaviour;
