LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.sprite_palettes_pkg.ALL;
USE work.vga_types.ALL;

ENTITY renderer IS
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

        -- For now, we'll hardcode one laser. This should be a record/array later.
        laser_x0             : IN UNSIGNED(9 DOWNTO 0);
        laser_y0             : IN UNSIGNED(9 DOWNTO 0);
        laser_x1             : IN UNSIGNED(9 DOWNTO 0);
        laser_y1             : IN UNSIGNED(9 DOWNTO 0);
        laser_is_active      : IN STD_LOGIC;
        frame_count          : IN UNSIGNED(7 DOWNTO 0);
        
        -- Output pixel color
        red_out              : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        green_out            : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        blue_out             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY renderer;

ARCHITECTURE rtl OF renderer IS
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

    -- Signals for player sprite calculation
    SIGNAL player_x_anchor      : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(120, 10);
    SIGNAL player_sprite_width  : POSITIVE;
    SIGNAL player_sprite_height : POSITIVE;
    SIGNAL player_scale_shift   : NATURAL;
    SIGNAL player_display_width : POSITIVE;
    SIGNAL player_display_height: POSITIVE;
    SIGNAL player_palette_id    : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_sprite_id     : UNSIGNED(7 DOWNTO 0);

    SIGNAL player_x_render     : UNSIGNED(9 DOWNTO 0);
    SIGNAL player_y_render     : UNSIGNED(9 DOWNTO 0);
    SIGNAL player_rel_x        : UNSIGNED(15 DOWNTO 0);
    SIGNAL player_rel_y        : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_player_sprite    : STD_LOGIC;
    SIGNAL player_is_transparent : STD_LOGIC;
    SIGNAL sprite_valid        : STD_LOGIC;
    SIGNAL sprite_color        : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL player_drawn        : STD_LOGIC;
    SIGNAL in_player_sprite_d  : STD_LOGIC := '0';
    CONSTANT MAX_PLAYER_HEIGHT : POSITIVE := 128;

    -- Signals for laser calculation
    SIGNAL laser_color        : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL laser_is_transparent : STD_LOGIC;
    
    SIGNAL teleporter_preview_on : STD_LOGIC;

BEGIN
    PROCESS(player_vehicle, left_button, player_grounded, player_vy)
    BEGIN
        IF player_vehicle = "00" THEN
            -- Jetpack gamemode: active sprite only when holding down
            player_palette_id <= PALETTE_BARRY;
            player_scale_shift <= 1;
            player_sprite_width <= 16;
            player_sprite_height <= 16;
            IF left_button = '1' THEN
                player_sprite_id <= SPRITE_BARRY_FLY;
            ELSE
                player_sprite_id <= SPRITE_BARRY_RUN;
            END IF;
        ELSIF player_vehicle = "01" THEN
            player_palette_id <= PALETTE_LIL_STOMPER;
            player_scale_shift <= 1;
            player_sprite_width <= 64;
            player_sprite_height <= 64;
            -- Lil Stomper gamemode: flying sprite when player holding down and in the air, and if not holding, falling sprite, but if on ground, show running sprite
            IF player_grounded = '1' THEN
                player_sprite_id <= SPRITE_STOMPER_RUN;
            ELSIF left_button = '1' THEN
                player_sprite_id <= SPRITE_STOMPER_FLY;
            ELSE
                player_sprite_id <= SPRITE_STOMPER_FALL;
            END IF;
        ELSIF player_vehicle = "10" THEN -- Bird
            player_palette_id <= PALETTE_BIRD;
            player_scale_shift <= 1;
            player_sprite_width <= 32;
            player_sprite_height <= 32;
            IF player_vy(9) = '1' THEN
                player_sprite_id <= SPRITE_BIRD_NOHOLD;
            ELSE
                player_sprite_id <= SPRITE_BIRD_HOLD;
            END IF;
        ELSIF player_vehicle = "11" THEN -- Teleporter
            player_palette_id <= PALETTE_TELEPORTER;
            player_scale_shift <= 1;
            player_sprite_width <= 32;
            player_sprite_height <= 32;
            player_sprite_id <= SPRITE_TELEPORTER;
        END IF;
    END PROCESS;

    player_display_width <= player_sprite_width * 2;
    player_display_height <= player_sprite_height * 2;

    PROCESS (player_display_width, player_x_anchor)
        VARIABLE center_x : INTEGER;
        VARIABLE left_x : INTEGER;
    BEGIN
        center_x := TO_INTEGER(player_x_anchor);
        left_x := center_x - (player_display_width / 2);

        IF left_x < 0 THEN
            left_x := 0;
        END IF;

        player_x_render <= TO_UNSIGNED(left_x, 10);
    END PROCESS;

    player_y_render <= UNSIGNED(player_y) + TO_UNSIGNED(MAX_PLAYER_HEIGHT - player_display_height, 10);

    PROCESS (pixel_x, pixel_y, player_x_render, player_y_render, player_display_width, player_display_height)
        VARIABLE s_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_y : UNSIGNED(15 DOWNTO 0);
    BEGIN
        s_x := RESIZE(pixel_x, 16);
        s_y := RESIZE(pixel_y, 16);
        p_x := RESIZE(player_x_render, 16);
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
            clock          => clock_25MHz,
            sprite_id      => player_sprite_id,
            palette_id     => player_palette_id,
            scale_shift    => player_scale_shift,
            rel_x          => player_rel_x,
            rel_y          => player_rel_y,
            color          => sprite_color,
            is_transparent => player_is_transparent,
            valid          => sprite_valid
        );

    PROCESS(clock_25MHz)
    BEGIN
        IF RISING_EDGE(clock_25MHz) THEN
            in_player_sprite_d <= in_player_sprite;
        END IF;
    END PROCESS;

    player_drawn <= in_player_sprite_d AND sprite_valid AND (NOT player_is_transparent);

    laser_inst: ENTITY work.laser
        PORT MAP(
            clock => clock_25MHz,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            frame_count => frame_count,
            x0 => laser_x0,
            y0 => laser_y0,
            x1 => laser_x1,
            y1 => laser_y1,
            is_active => laser_is_active,
            color_out => laser_color,
            is_transparent => laser_is_transparent
        );

    PROCESS (pixel_y, teleporter_preview_y)
    BEGIN
        IF UNSIGNED(pixel_y) = UNSIGNED(teleporter_preview_y) THEN
            teleporter_preview_on <= '1';
        ELSE
            teleporter_preview_on <= '0';
        END IF;
    END PROCESS;

    PROCESS (player_drawn, sprite_color, teleporter_preview_on, pixel_y, laser_is_transparent, laser_color)
        VARIABLE base_r, base_g, base_b : INTEGER RANGE 0 TO 15;
        VARIABLE add_r, add_g, add_b : INTEGER;
    BEGIN
        IF player_drawn = '1' THEN
            red_out <= sprite_color(11 DOWNTO 8);
            green_out <= sprite_color(7 DOWNTO 4);
            blue_out <= sprite_color(3 DOWNTO 0);
        ELSE
            IF teleporter_preview_on = '1' THEN
                base_r := 15;
                base_g := 6;
                base_b := 0;
            ELSIF (TO_INTEGER(UNSIGNED(pixel_y)) >= 470) THEN
                base_r := 8;
                base_g := 8;
                base_b := 8;
            ELSE
                -- we do the background here (background sprite)
                base_r := 0;
                base_g := 0;
                base_b := 0;
            END IF;

            IF laser_is_transparent = '0' THEN
                add_r := base_r + TO_INTEGER(UNSIGNED(laser_color(11 DOWNTO 8)));
                add_g := base_g + TO_INTEGER(UNSIGNED(laser_color(7 DOWNTO 4)));
                add_b := base_b + TO_INTEGER(UNSIGNED(laser_color(3 DOWNTO 0)));

                IF add_r > 15 THEN red_out <= x"F"; ELSE red_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(add_r, 4)); END IF;
                IF add_g > 15 THEN green_out <= x"F"; ELSE green_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(add_g, 4)); END IF;
                IF add_b > 15 THEN blue_out <= x"F"; ELSE blue_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(add_b, 4)); END IF;
            ELSE
                red_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(base_r, 4));
                green_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(base_g, 4));
                blue_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(base_b, 4));
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
