LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY palette_grabber IS
    GENERIC (
        IMAGE_WIDTH : POSITIVE;
        IMAGE_HEIGHT : POSITIVE;
        DISPLAY_WIDTH : POSITIVE;
        DISPLAY_HEIGHT : POSITIVE;
        MIF_FILE : STRING;
        TRANSPARENT_INDEX : NATURAL := 0
    );
    PORT (
        clock : IN STD_LOGIC;
        screen_x : IN UNSIGNED(15 DOWNTO 0);
        screen_y : IN UNSIGNED(15 DOWNTO 0);
        sprite_x : IN UNSIGNED(15 DOWNTO 0);
        sprite_y : IN UNSIGNED(15 DOWNTO 0);
        color : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        valid : OUT STD_LOGIC
    );
END ENTITY palette_grabber;

ARCHITECTURE rtl OF palette_grabber IS
    COMPONENT image_loader IS
        GENERIC (
            IMAGE_WIDTH : POSITIVE;
            IMAGE_HEIGHT : POSITIVE;
            MIF_FILE : STRING
        );
        PORT (
            clock : IN STD_LOGIC;
            x : IN UNSIGNED(15 DOWNTO 0);
            y : IN UNSIGNED(15 DOWNTO 0);
            pixel_index : OUT UNSIGNED(7 DOWNTO 0);
            color : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            valid : OUT STD_LOGIC
        );
    END COMPONENT image_loader;

    SIGNAL local_x : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL local_y : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL in_sprite : STD_LOGIC := '0';

    SIGNAL loader_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL loader_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL loader_valid : STD_LOGIC;

    CONSTANT image_width_u : UNSIGNED(15 DOWNTO 0) := TO_UNSIGNED(IMAGE_WIDTH, 16);
    CONSTANT image_height_u : UNSIGNED(15 DOWNTO 0) := TO_UNSIGNED(IMAGE_HEIGHT, 16);
    CONSTANT display_width_u : UNSIGNED(15 DOWNTO 0) := TO_UNSIGNED(DISPLAY_WIDTH, 16);
    CONSTANT display_height_u : UNSIGNED(15 DOWNTO 0) := TO_UNSIGNED(DISPLAY_HEIGHT, 16);
    CONSTANT transparent_index_u : UNSIGNED(7 DOWNTO 0) := TO_UNSIGNED(TRANSPARENT_INDEX, 8);
BEGIN
    sprite_loader : image_loader
        GENERIC MAP (
            IMAGE_WIDTH => IMAGE_WIDTH,
            IMAGE_HEIGHT => IMAGE_HEIGHT,
            MIF_FILE => MIF_FILE
        )
        PORT MAP (
            clock => clock,
            x => local_x,
            y => local_y,
            pixel_index => loader_pixel_index,
            color => loader_color,
            valid => loader_valid
        );

    PROCESS (screen_x, screen_y, sprite_x, sprite_y, display_width_u, display_height_u)
        VARIABLE rel_x : natural;
        VARIABLE rel_y : natural;
        VARIABLE scaled_x : natural;
        VARIABLE scaled_y : natural;
    BEGIN
        IF (screen_x >= sprite_x) AND (screen_x < sprite_x + display_width_u)
            AND (screen_y >= sprite_y) AND (screen_y < sprite_y + display_height_u) THEN
            in_sprite <= '1';
            rel_x := to_integer(screen_x - sprite_x);
            rel_y := to_integer(screen_y - sprite_y);

            scaled_x := (rel_x * IMAGE_WIDTH) / DISPLAY_WIDTH;
            scaled_y := (rel_y * IMAGE_HEIGHT) / DISPLAY_HEIGHT;

            local_x <= to_unsigned(scaled_x, local_x'length);
            local_y <= to_unsigned(scaled_y, local_y'length);
        ELSE
            in_sprite <= '0';
            local_x <= (OTHERS => '0');
            local_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    PROCESS (loader_pixel_index, in_sprite, loader_valid, loader_color)
        VARIABLE is_visible : STD_LOGIC;
    BEGIN
        IF (loader_pixel_index = transparent_index_u) THEN
            is_visible := '0';
        ELSE
            is_visible := '1';
        END IF;

        valid <= in_sprite AND loader_valid AND is_visible;
        IF (in_sprite = '1') AND (loader_valid = '1') AND (is_visible = '1') THEN
            color <= loader_color;
        ELSE
            color <= (OTHERS => '0');
        END IF;
    END PROCESS;
END ARCHITECTURE rtl;
