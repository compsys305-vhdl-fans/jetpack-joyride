LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY HARDWARE;
USE HARDWARE.VGA_TYPES.ALL;
USE work.sprite_palettes_pkg.ALL;
USE work.obstacle_types.ALL;

ENTITY renderer IS
    PORT (
        clock_25MHz          : IN STD_LOGIC;
        show_djt             : IN STD_LOGIC;
        pixel_x              : IN UNSIGNED(9 DOWNTO 0);
        pixel_y              : IN UNSIGNED(9 DOWNTO 0);

        player_y             : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        player_vehicle       : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        left_button          : IN STD_LOGIC;
        player_grounded      : IN STD_LOGIC;
        player_vy            : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        teleporter_preview_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        death                : IN STD_LOGIC;

        laser_pool           : IN laser_pool_t;
        frame_count          : IN UNSIGNED(7 DOWNTO 0);
        random_in            : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        world_speed          : IN UNSIGNED(9 DOWNTO 0);
        
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
            show_djt       : IN STD_LOGIC;
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
    TYPE laser_color_array IS ARRAY (0 TO MAX_LASERS - 1) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    TYPE laser_transparency_array IS ARRAY (0 TO MAX_LASERS - 1) OF STD_LOGIC;
    SIGNAL laser_colors        : laser_color_array;
    SIGNAL laser_transparencies: laser_transparency_array;
    SIGNAL combined_laser_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL combined_laser_is_transparent : STD_LOGIC;

    -- Background sprite signals
    SIGNAL bg_sprite_id : UNSIGNED(7 DOWNTO 0);
    SIGNAL bg_palette_id : UNSIGNED(7 DOWNTO 0);
    SIGNAL bg_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL bg_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL bg_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL bg_is_transparent : STD_LOGIC;
    SIGNAL bg_valid : STD_LOGIC;
    SIGNAL bg_drawn : STD_LOGIC;
    SIGNAL bg_seed : UNSIGNED(1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL bg_seed_valid : STD_LOGIC := '0';
    SIGNAL frame_count_d : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL bg_scroll_accum : UNSIGNED(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL bg_parallax_step : UNSIGNED(9 DOWNTO 0);
    
    SIGNAL teleporter_preview_on : STD_LOGIC;

    CONSTANT DEATH_SPRITE_WIDTH : NATURAL := 42;
    CONSTANT DEATH_SPRITE_HEIGHT : NATURAL := 13;
    CONSTANT DEATH_SCALE_SHIFT : NATURAL := 1;
    CONSTANT DEATH_DISPLAY_WIDTH : NATURAL := DEATH_SPRITE_WIDTH * 2;
    CONSTANT DEATH_DISPLAY_HEIGHT : NATURAL := DEATH_SPRITE_HEIGHT * 2;
    CONSTANT DEATH_X_LEFT : NATURAL := (640 - DEATH_DISPLAY_WIDTH) / 2;
    CONSTANT DEATH_Y_TOP : NATURAL := (480 - DEATH_DISPLAY_HEIGHT) / 2;

    SIGNAL death_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL death_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_death_sprite : STD_LOGIC;
    SIGNAL in_death_sprite_d : STD_LOGIC := '0';
    SIGNAL death_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL death_sprite_is_transparent : STD_LOGIC;
    SIGNAL death_sprite_valid : STD_LOGIC;
    SIGNAL death_drawn : STD_LOGIC;

    SIGNAL laser_beam_rect_mode : STD_LOGIC := '0';

    -- Pipelining registers
    SIGNAL pixel_y_lookahead       : UNSIGNED(9 DOWNTO 0);
    SIGNAL base_color              : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL base_color_d            : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL laser_colors_reg        : laser_color_array;
    SIGNAL laser_transparencies_reg: laser_transparency_array;

BEGIN
    pixel_y_lookahead <= pixel_y + 1;
    bg_parallax_step <= '0' & world_speed(9 DOWNTO 1);

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
        ELSE
            -- Default case to prevent latches
            player_palette_id <= PALETTE_BARRY;
            player_scale_shift <= 1;
            player_sprite_width <= 16;
            player_sprite_height <= 16;
            player_sprite_id <= SPRITE_BARRY_RUN;
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

    PROCESS (player_y, player_display_height, player_vehicle)
        CONSTANT MAX_PLAYER_DISPLAY_HEIGHT : NATURAL := 128;
        VARIABLE offset : NATURAL;
    BEGIN
        -- Offset the rendered Y position to bottom-align all sprites, except the teleporter
        IF player_vehicle = "11" THEN -- is teleporter
            offset := 0;
        ELSE
            offset := MAX_PLAYER_DISPLAY_HEIGHT - player_display_height;
        END IF;
        player_y_render <= UNSIGNED(player_y) + TO_UNSIGNED(offset, 10);
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, player_x_render, player_y_render, player_display_width, player_display_height)
        VARIABLE s_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_y : UNSIGNED(15 DOWNTO 0);
    BEGIN
        s_x := RESIZE(pixel_x, 16);
        s_y := RESIZE(pixel_y_lookahead, 16);
        p_x := RESIZE(player_x_render, 16);
        p_y := RESIZE(player_y_render, 16);
        
        IF (s_x >= p_x) AND (s_x < p_x + TO_UNSIGNED(player_display_width, 16)) AND
           (s_y >= p_y) AND (s_y < p_y + TO_UNSIGNED(player_display_height, 16)) THEN
            in_player_sprite <= '1';
            player_rel_x <= s_x - p_x;
            player_rel_y <= s_y - p_y;
        ELSE
            in_player_sprite <= '0';
            player_rel_x <= (OTHERS => '0');
            player_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, death)
        VARIABLE s_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y : UNSIGNED(15 DOWNTO 0);
        VARIABLE left_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE top_y : UNSIGNED(15 DOWNTO 0);
    BEGIN
        s_x := RESIZE(pixel_x, 16);
        s_y := RESIZE(pixel_y_lookahead, 16);
        left_x := TO_UNSIGNED(DEATH_X_LEFT, 16);
        top_y := TO_UNSIGNED(DEATH_Y_TOP, 16);

        IF (death = '1') AND
           (s_x >= left_x) AND (s_x < left_x + TO_UNSIGNED(DEATH_DISPLAY_WIDTH, 16)) AND
           (s_y >= top_y) AND (s_y < top_y + TO_UNSIGNED(DEATH_DISPLAY_HEIGHT, 16)) THEN
            in_death_sprite <= '1';
            death_rel_x <= s_x - left_x;
            death_rel_y <= s_y - top_y;
        ELSE
            in_death_sprite <= '0';
            death_rel_x <= (OTHERS => '0');
            death_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    player_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => show_djt,
            sprite_id      => player_sprite_id,
            palette_id     => player_palette_id,
            scale_shift    => player_scale_shift,
            rel_x          => player_rel_x,
            rel_y          => player_rel_y,
            color          => sprite_color,
            is_transparent => player_is_transparent,
            valid          => sprite_valid
        );

    background_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => show_djt,
            sprite_id      => bg_sprite_id,
            palette_id     => bg_palette_id,
            scale_shift    => 1,
            rel_x          => bg_rel_x,
            rel_y          => bg_rel_y,
            color          => bg_color,
            is_transparent => bg_is_transparent,
            valid          => bg_valid
        );

    death_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => '0',
            sprite_id      => SPRITE_DEATH_TEXT,
            palette_id     => PALETTE_DEATH,
            scale_shift    => DEATH_SCALE_SHIFT,
            rel_x          => death_rel_x,
            rel_y          => death_rel_y,
            color          => death_sprite_color,
            is_transparent => death_sprite_is_transparent,
            valid          => death_sprite_valid
        );

    PROCESS(clock_25MHz)
    BEGIN
        IF RISING_EDGE(clock_25MHz) THEN
            IF frame_count /= frame_count_d THEN
                IF bg_seed_valid = '0' THEN
                    bg_seed <= UNSIGNED(random_in(1 DOWNTO 0));
                    bg_seed_valid <= '1';
                END IF;

                IF bg_parallax_step = TO_UNSIGNED(0, bg_parallax_step'length) THEN
                    bg_scroll_accum <= bg_scroll_accum + 1;
                ELSE
                    bg_scroll_accum <= bg_scroll_accum + RESIZE(bg_parallax_step, 12);
                END IF;
            END IF;
            frame_count_d <= frame_count;
            in_player_sprite_d <= in_player_sprite;
            in_death_sprite_d <= in_death_sprite;
            laser_colors_reg <= laser_colors;
            laser_transparencies_reg <= laser_transparencies;
            base_color_d <= base_color;
        END IF;
    END PROCESS;

    player_drawn <= in_player_sprite_d AND sprite_valid AND (NOT player_is_transparent);
    death_drawn <= in_death_sprite_d AND death_sprite_valid AND (NOT death_sprite_is_transparent);
    bg_drawn <= bg_valid AND (NOT bg_is_transparent);

    PROCESS(pixel_x, pixel_y_lookahead, bg_seed, bg_scroll_accum, show_djt)
        VARIABLE tile_x : INTEGER;
        VARIABLE sel : INTEGER;
        VARIABLE scrolled_x : UNSIGNED(11 DOWNTO 0);
    BEGIN
        IF show_djt = '1' THEN
            bg_sprite_id <= SPRITE_DJT;
            bg_palette_id <= PALETTE_DJT;
            bg_rel_x <= RESIZE(pixel_x, 16) SLL 1;
            bg_rel_y <= RESIZE(pixel_y_lookahead, 16) SLL 1;
        ELSE
            bg_palette_id <= PALETTE_BACKGROUND2;
            scrolled_x := RESIZE(pixel_x, 12) + bg_scroll_accum;
            bg_rel_x <= RESIZE(scrolled_x(6 DOWNTO 0), 16);
            bg_rel_y <= RESIZE(pixel_y_lookahead, 16);

            tile_x := TO_INTEGER(scrolled_x(9 DOWNTO 7));
            sel := (tile_x + TO_INTEGER(bg_seed)) MOD 3;

            CASE sel IS
                WHEN 0 =>
                    bg_sprite_id <= SPRITE_BG2_LIGHT;
                WHEN 1 =>
                    bg_sprite_id <= SPRITE_BG2_PILLAR;
                WHEN OTHERS =>
                    bg_sprite_id <= SPRITE_BG2_PLAIN;
            END CASE;
        END IF;
    END PROCESS;

    laser_gen: FOR i IN 0 TO MAX_LASERS - 1 GENERATE
        laser_inst: ENTITY work.laser
            PORT MAP(
                clock => clock_25MHz,
                show_djt => show_djt,
                pixel_x => pixel_x,
                pixel_y => pixel_y_lookahead,
                frame_count => frame_count,
                beam_rect_mode => laser_beam_rect_mode,
                x0 => laser_pool(i).x0,
                y0 => laser_pool(i).y0,
                x1 => laser_pool(i).x1,
                y1 => laser_pool(i).y1,
                is_active => laser_pool(i).is_active,
                color_out => laser_colors(i),
                is_transparent => laser_transparencies(i)
            );
    END GENERATE;
    
    PROCESS(laser_colors_reg, laser_transparencies_reg)
        VARIABLE found : BOOLEAN := false;
        VARIABLE idx : INTEGER;
    BEGIN
        combined_laser_color <= (OTHERS => '0');
        combined_laser_is_transparent <= '1';
        found := false;

        FOR idx IN 0 TO MAX_LASERS - 1 LOOP
            IF (NOT found) AND (laser_transparencies_reg(idx) = '0') THEN
                combined_laser_color <= laser_colors_reg(idx);
                combined_laser_is_transparent <= '0';
                found := true;
            END IF;
        END LOOP;
    END PROCESS;

    PROCESS (pixel_y_lookahead, teleporter_preview_y, bg_drawn, bg_color, show_djt)
        VARIABLE r,g,b : INTEGER RANGE 0 TO 15;
    BEGIN
        IF bg_drawn = '1' THEN
            r := TO_INTEGER(UNSIGNED(bg_color(11 DOWNTO 8)));
            g := TO_INTEGER(UNSIGNED(bg_color(7 DOWNTO 4)));
            b := TO_INTEGER(UNSIGNED(bg_color(3 DOWNTO 0)));
        ELSE
            r := 0;  g := 0; b := 0; -- Black
        END IF;

        IF show_djt = '0' THEN
            IF UNSIGNED(pixel_y_lookahead) = UNSIGNED(teleporter_preview_y) THEN
                 r := 15; g := 6; b := 0; -- Orange
            ELSIF (TO_INTEGER(pixel_y_lookahead) >= 470) THEN
                 r := 8;  g := 8; b := 8; -- Grey
            END IF;
        END IF;
        base_color <= STD_LOGIC_VECTOR(TO_UNSIGNED(r,4) & TO_UNSIGNED(g,4) & TO_UNSIGNED(b,4));
    END PROCESS;

    PROCESS (death_drawn, death_sprite_color, show_djt, player_drawn, sprite_color, base_color_d,
             combined_laser_is_transparent, combined_laser_color)
        VARIABLE base_r, base_g, base_b : INTEGER RANGE 0 TO 15;
        VARIABLE add_r, add_g, add_b : INTEGER;
        VARIABLE final_r, final_g, final_b : INTEGER RANGE 0 TO 15;
    BEGIN
        IF death_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(death_sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(death_sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(death_sprite_color(3 DOWNTO 0)));
        ELSIF show_djt = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(base_color_d(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(base_color_d(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(base_color_d(3 DOWNTO 0)));
        ELSIF player_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(sprite_color(3 DOWNTO 0)));
        ELSE
            -- Determine base color
            base_r := TO_INTEGER(UNSIGNED(base_color_d(11 DOWNTO 8)));
            base_g := TO_INTEGER(UNSIGNED(base_color_d(7 DOWNTO 4)));
            base_b := TO_INTEGER(UNSIGNED(base_color_d(3 DOWNTO 0)));

            -- Add laser color
            IF combined_laser_is_transparent = '1' THEN
                final_r := base_r;
                final_g := base_g;
                final_b := base_b;
            ELSE
                add_r := base_r + TO_INTEGER(UNSIGNED(combined_laser_color(11 DOWNTO 8)));
                add_g := base_g + TO_INTEGER(UNSIGNED(combined_laser_color(7 DOWNTO 4)));
                add_b := base_b + TO_INTEGER(UNSIGNED(combined_laser_color(3 DOWNTO 0)));

                IF add_r > 15 THEN final_r := 15; ELSE final_r := add_r; END IF;
                IF add_g > 15 THEN final_g := 15; ELSE final_g := add_g; END IF;
                IF add_b > 15 THEN final_b := 15; ELSE final_b := add_b; END IF;
            END IF;
        END IF;

        red_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(final_r, 4));
        green_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(final_g, 4));
        blue_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(final_b, 4));
    END PROCESS;

END ARCHITECTURE rtl;
