LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.sprite_palettes_pkg.ALL;
USE work.obstacle_types.ALL;

ENTITY collision_detector IS
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
        missile_pool         : IN missile_pool_t;
        coin_pool            : IN coin_pool_t;
        powerup_pool         : IN powerup_pool_t;
        death                : OUT STD_LOGIC;
        powerup_collected    : OUT STD_LOGIC;
        collision_red        : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        collision_green      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        collision_blue       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY collision_detector;

ARCHITECTURE rtl OF collision_detector IS
    COMPONENT sprite_renderer IS
        PORT (
            clock : IN STD_LOGIC;
            show_djt : IN STD_LOGIC;
            
            -- Query inputs
            sprite_id   : IN UNSIGNED(7 DOWNTO 0);
            palette_id  : IN UNSIGNED(7 DOWNTO 0);
            scale_shift : IN NATURAL;
            rel_x       : IN UNSIGNED(15 DOWNTO 0);
            rel_y       : IN UNSIGNED(15 DOWNTO 0);
            
            -- Outputs
            color          : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            is_transparent : OUT STD_LOGIC;
            valid          : OUT STD_LOGIC
        );
    END COMPONENT sprite_renderer;

    -- Player sprite signals
    SIGNAL player_x_anchor      : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(120, 10);
    SIGNAL player_sprite_width  : POSITIVE;
    SIGNAL player_sprite_height : POSITIVE;
    SIGNAL player_scale_shift   : NATURAL;
    SIGNAL player_display_width : POSITIVE;
    SIGNAL player_display_height: POSITIVE;
    SIGNAL player_palette_id    : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_sprite_id     : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_x_render      : UNSIGNED(9 DOWNTO 0);
    SIGNAL player_y_render      : UNSIGNED(9 DOWNTO 0);
    SIGNAL player_rel_x         : UNSIGNED(15 DOWNTO 0);
    SIGNAL player_rel_y         : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_player_sprite     : STD_LOGIC;
    SIGNAL in_player_sprite_d   : STD_LOGIC := '0';
    SIGNAL player_sprite_color  : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL player_sprite_is_transparent : STD_LOGIC;
    SIGNAL player_sprite_valid  : STD_LOGIC;

    -- Missile sprite signals
    SIGNAL missile_rel_x         : UNSIGNED(15 DOWNTO 0);
    SIGNAL missile_rel_y         : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_missile_sprite     : STD_LOGIC;
    SIGNAL in_missile_sprite_d   : STD_LOGIC := '0';
    SIGNAL missile_sprite_color  : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL missile_sprite_is_transparent : STD_LOGIC;
    SIGNAL missile_sprite_valid  : STD_LOGIC;
    SIGNAL missile_pixel_on      : STD_LOGIC;

    -- Coin sprite signals
    SIGNAL coin_rel_x         : UNSIGNED(15 DOWNTO 0);
    SIGNAL coin_rel_y         : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_coin_sprite     : STD_LOGIC;
    SIGNAL in_coin_sprite_d   : STD_LOGIC := '0';
    SIGNAL coin_sprite_color  : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL coin_sprite_is_transparent : STD_LOGIC;
    SIGNAL coin_sprite_valid  : STD_LOGIC;
    SIGNAL coin_pixel_on      : STD_LOGIC;

    -- Powerup sprite signals
    SIGNAL powerup_rel_x         : UNSIGNED(15 DOWNTO 0);
    SIGNAL powerup_rel_y         : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_powerup_sprite     : STD_LOGIC;
    SIGNAL in_powerup_sprite_d   : STD_LOGIC := '0';
    SIGNAL powerup_sprite_color  : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL powerup_sprite_is_transparent : STD_LOGIC;
    SIGNAL powerup_sprite_valid  : STD_LOGIC;
    SIGNAL powerup_pixel_on      : STD_LOGIC;
    SIGNAL powerup_collected_pixel : STD_LOGIC;
    SIGNAL powerup_collected_reg : STD_LOGIC := '0';

    -- Laser signals
    SIGNAL is_on_any_laser_line : STD_LOGIC;
    SIGNAL is_on_any_laser_line_d : STD_LOGIC := '0';
    SIGNAL player_pixel_on : STD_LOGIC;
    SIGNAL collision_pixel_on : STD_LOGIC;

    SIGNAL death_reg : STD_LOGIC := '0';

    CONSTANT MAX_PLAYER_DISPLAY_HEIGHT : NATURAL := 128;
    CONSTANT BEAM_HALF_WIDTH : INTEGER := 7;
    CONSTANT NODE_HALF_SIZE : INTEGER := 8;
    CONSTANT MISSILE_SPRITE_WIDTH : NATURAL := 16;
    CONSTANT MISSILE_SPRITE_HEIGHT : NATURAL := 16;
    CONSTANT MISSILE_SCALE_SHIFT : NATURAL := 1;
    CONSTANT MISSILE_DISPLAY_WIDTH : NATURAL := MISSILE_SPRITE_WIDTH * 2;
    CONSTANT MISSILE_DISPLAY_HEIGHT : NATURAL := MISSILE_SPRITE_HEIGHT * 2;
    CONSTANT COIN_SPRITE_WIDTH : NATURAL := 16;
    CONSTANT COIN_SPRITE_HEIGHT : NATURAL := 16;
    CONSTANT COIN_SCALE_SHIFT : NATURAL := 1;
    CONSTANT COIN_DISPLAY_WIDTH : NATURAL := COIN_SPRITE_WIDTH * 2;
    CONSTANT COIN_DISPLAY_HEIGHT : NATURAL := COIN_SPRITE_HEIGHT * 2;

    CONSTANT POWERUP_SPRITE_WIDTH : NATURAL := 32;
    CONSTANT POWERUP_SPRITE_HEIGHT : NATURAL := 32;
    CONSTANT POWERUP_SCALE_SHIFT : NATURAL := 1;
    CONSTANT POWERUP_DISPLAY_WIDTH : NATURAL := POWERUP_SPRITE_WIDTH * 2;
    CONSTANT POWERUP_DISPLAY_HEIGHT : NATURAL := POWERUP_SPRITE_HEIGHT * 2;

    SIGNAL pixel_y_lookahead : UNSIGNED(9 DOWNTO 0);

BEGIN
    pixel_y_lookahead <= pixel_y + 1;

    PROCESS(player_vehicle, left_button, player_grounded, player_vy)
    BEGIN
        IF player_vehicle = "00" THEN
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
            IF player_grounded = '1' THEN
                player_sprite_id <= SPRITE_STOMPER_RUN;
            ELSIF left_button = '1' THEN
                player_sprite_id <= SPRITE_STOMPER_FLY;
            ELSE
                player_sprite_id <= SPRITE_STOMPER_FALL;
            END IF;
        ELSIF player_vehicle = "10" THEN
            player_palette_id <= PALETTE_BIRD;
            player_scale_shift <= 1;
            player_sprite_width <= 32;
            player_sprite_height <= 32;
            IF player_vy(9) = '1' THEN
                player_sprite_id <= SPRITE_BIRD_NOHOLD;
            ELSE
                player_sprite_id <= SPRITE_BIRD_HOLD;
            END IF;
        ELSIF player_vehicle = "11" THEN
            player_palette_id <= PALETTE_TELEPORTER;
            player_scale_shift <= 1;
            player_sprite_width <= 32;
            player_sprite_height <= 32;
            player_sprite_id <= SPRITE_TELEPORTER;
        ELSE
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
        VARIABLE offset : NATURAL;
    BEGIN
        IF player_vehicle = "11" THEN
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

    PROCESS (pixel_x, pixel_y_lookahead, missile_pool)
        VARIABLE s_x, s_y : INTEGER;
        VARIABLE m_x, m_y : INTEGER;
    BEGIN
        IF missile_pool(0).is_active = '1' THEN
            s_x := TO_INTEGER(pixel_x);
            s_y := TO_INTEGER(pixel_y_lookahead);
            m_x := TO_INTEGER(missile_pool(0).x);
            m_y := TO_INTEGER(missile_pool(0).y);

            IF (s_x >= m_x) AND (s_x < m_x + MISSILE_DISPLAY_WIDTH) AND
               (s_y >= m_y) AND (s_y < m_y + MISSILE_DISPLAY_HEIGHT) THEN
                in_missile_sprite <= '1';
                missile_rel_x <= TO_UNSIGNED(s_x - m_x, 16);
                missile_rel_y <= TO_UNSIGNED(s_y - m_y, 16);
            ELSE
                in_missile_sprite <= '0';
                missile_rel_x <= (OTHERS => '0');
                missile_rel_y <= (OTHERS => '0');
            END IF;
        ELSE
            in_missile_sprite <= '0';
            missile_rel_x <= (OTHERS => '0');
            missile_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, coin_pool)
        VARIABLE s_x, s_y : INTEGER;
        VARIABLE c_x, c_y : INTEGER;
        VARIABLE found : BOOLEAN;
    BEGIN
        s_x := TO_INTEGER(pixel_x);
        s_y := TO_INTEGER(pixel_y_lookahead);
        found := false;
        in_coin_sprite <= '0';
        coin_rel_x <= (OTHERS => '0');
        coin_rel_y <= (OTHERS => '0');

        FOR i IN 0 TO MAX_COINS - 1 LOOP
            IF (NOT found) AND (coin_pool(i).is_active = '1') THEN
                c_x := TO_INTEGER(coin_pool(i).x);
                c_y := TO_INTEGER(coin_pool(i).y);

                IF (s_x >= c_x) AND (s_x < c_x + COIN_DISPLAY_WIDTH) AND
                   (s_y >= c_y) AND (s_y < c_y + COIN_DISPLAY_HEIGHT) THEN
                    found := true;
                    in_coin_sprite <= '1';
                    coin_rel_x <= TO_UNSIGNED(s_x - c_x, 16);
                    coin_rel_y <= TO_UNSIGNED(s_y - c_y, 16);
                END IF;
            END IF;
        END LOOP;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, powerup_pool)
        VARIABLE s_x, s_y : INTEGER;
        VARIABLE p_x, p_y : INTEGER;
    BEGIN
        IF powerup_pool(0).is_active = '1' THEN
            s_x := TO_INTEGER(pixel_x);
            s_y := TO_INTEGER(pixel_y_lookahead);
            p_x := TO_INTEGER(powerup_pool(0).x);
            p_y := TO_INTEGER(powerup_pool(0).y);

            IF (s_x >= p_x) AND (s_x < p_x + POWERUP_DISPLAY_WIDTH) AND
               (s_y >= p_y) AND (s_y < p_y + POWERUP_DISPLAY_HEIGHT) THEN
                in_powerup_sprite <= '1';
                powerup_rel_x <= TO_UNSIGNED(s_x - p_x, 16);
                powerup_rel_y <= TO_UNSIGNED(s_y - p_y, 16);
            ELSE
                in_powerup_sprite <= '0';
                powerup_rel_x <= (OTHERS => '0');
                powerup_rel_y <= (OTHERS => '0');
            END IF;
        ELSE
            in_powerup_sprite <= '0';
            powerup_rel_x <= (OTHERS => '0');
            powerup_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    player_sprite_renderer: sprite_renderer
        PORT MAP (
            clock => clock_25MHz,
            show_djt => '0',
            sprite_id => player_sprite_id,
            palette_id => player_palette_id,
            scale_shift => player_scale_shift,
            rel_x => player_rel_x,
            rel_y => player_rel_y,
            color => player_sprite_color,
            is_transparent => player_sprite_is_transparent,
            valid => player_sprite_valid
        );

    missile_sprite_renderer: sprite_renderer
        PORT MAP (
            clock => clock_25MHz,
            show_djt => '0',
            sprite_id => SPRITE_MISSILE,
            palette_id => PALETTE_MISSILE,
            scale_shift => MISSILE_SCALE_SHIFT,
            rel_x => missile_rel_x,
            rel_y => missile_rel_y,
            color => missile_sprite_color,
            is_transparent => missile_sprite_is_transparent,
            valid => missile_sprite_valid
        );

    coin_sprite_renderer: sprite_renderer
        PORT MAP (
            clock => clock_25MHz,
            show_djt => '0',
            sprite_id => SPRITE_COIN,
            palette_id => PALETTE_COIN,
            scale_shift => COIN_SCALE_SHIFT,
            rel_x => coin_rel_x,
            rel_y => coin_rel_y,
            color => coin_sprite_color,
            is_transparent => coin_sprite_is_transparent,
            valid => coin_sprite_valid
        );

    powerup_sprite_renderer: sprite_renderer
        PORT MAP (
            clock => clock_25MHz,
            show_djt => '0',
            sprite_id => SPRITE_POWERUP,
            palette_id => PALETTE_POWERUP,
            scale_shift => POWERUP_SCALE_SHIFT,
            rel_x => powerup_rel_x,
            rel_y => powerup_rel_y,
            color => powerup_sprite_color,
            is_transparent => powerup_sprite_is_transparent,
            valid => powerup_sprite_valid
        );

    PROCESS(clock_25MHz)
    BEGIN
        IF RISING_EDGE(clock_25MHz) THEN
            in_player_sprite_d <= in_player_sprite;
            in_missile_sprite_d <= in_missile_sprite;
            in_coin_sprite_d <= in_coin_sprite;
            in_powerup_sprite_d <= in_powerup_sprite;
            is_on_any_laser_line_d <= is_on_any_laser_line;
        END IF;
    END PROCESS;

    player_pixel_on <= in_player_sprite_d AND player_sprite_valid AND (NOT player_sprite_is_transparent);
    missile_pixel_on <= in_missile_sprite_d AND missile_sprite_valid AND (NOT missile_sprite_is_transparent);
    coin_pixel_on <= in_coin_sprite_d AND coin_sprite_valid AND (NOT coin_sprite_is_transparent);
    powerup_pixel_on <= in_powerup_sprite_d AND powerup_sprite_valid AND (NOT powerup_sprite_is_transparent);
    collision_pixel_on <= player_pixel_on AND (is_on_any_laser_line_d OR missile_pixel_on);
    powerup_collected_pixel <= player_pixel_on AND powerup_pixel_on;
    
    -- Laser Collision Detection (axis-aligned beam rectangle only; excludes endpoints)
    PROCESS(laser_pool, pixel_x, pixel_y)
        VARIABLE on_laser : BOOLEAN := false;
        VARIABLE px, py : INTEGER;
        VARIABLE ax, ay, bx, by : INTEGER;
        VARIABLE min_x, max_x : INTEGER;
        VARIABLE min_y, max_y : INTEGER;
        VARIABLE inner_min, inner_max : INTEGER;
    BEGIN
        on_laser := false;
        px := TO_INTEGER(pixel_x);
        py := TO_INTEGER(pixel_y);

        FOR i IN 0 TO MAX_LASERS - 1 LOOP
            IF laser_pool(i).is_active = '1' THEN
                ax := TO_INTEGER(laser_pool(i).x0);
                ay := TO_INTEGER(laser_pool(i).y0);
                bx := TO_INTEGER(laser_pool(i).x1);
                by := TO_INTEGER(laser_pool(i).y1);

                IF ax = bx THEN
                    IF ay < by THEN
                        min_y := ay;
                        max_y := by;
                    ELSE
                        min_y := by;
                        max_y := ay;
                    END IF;
                    inner_min := min_y + NODE_HALF_SIZE;
                    inner_max := max_y - NODE_HALF_SIZE;

                    IF (inner_min < inner_max) AND (ABS(px - ax) < BEAM_HALF_WIDTH) AND
                       (py > inner_min) AND (py < inner_max) THEN
                        on_laser := true;
                        EXIT;
                    END IF;
                ELSIF ay = by THEN
                    IF ax < bx THEN
                        min_x := ax;
                        max_x := bx;
                    ELSE
                        min_x := bx;
                        max_x := ax;
                    END IF;
                    inner_min := min_x + NODE_HALF_SIZE;
                    inner_max := max_x - NODE_HALF_SIZE;

                    IF (inner_min < inner_max) AND (ABS(py - ay) < BEAM_HALF_WIDTH) AND
                       (px > inner_min) AND (px < inner_max) THEN
                        on_laser := true;
                        EXIT;
                    END IF;
                ELSE
                    NULL;
                END IF;
            END IF;
        END LOOP;

        IF on_laser THEN
            is_on_any_laser_line <= '1';
        ELSE
            is_on_any_laser_line <= '0';
        END IF;
    END PROCESS;

    PROCESS(clock_25MHz, vert_sync)
    BEGIN
        IF vert_sync = '0' THEN
            death_reg <= '0';
            powerup_collected_reg <= '0';
        ELSIF RISING_EDGE(clock_25MHz) THEN
            IF collision_pixel_on = '1' THEN
                death_reg <= '1';
            END IF;
            IF powerup_collected_pixel = '1' THEN
                powerup_collected_reg <= '1';
            END IF;
        END IF;
    END PROCESS;

    PROCESS(player_pixel_on, is_on_any_laser_line, missile_pixel_on, coin_pixel_on, collision_pixel_on, powerup_pixel_on)
    BEGIN
        IF collision_pixel_on = '1' THEN
            collision_red <= "1111";
            collision_green <= "1111";
            collision_blue <= "1111";
        ELSIF player_pixel_on = '1' THEN
            collision_red <= "0000";
            collision_green <= "0000";
            collision_blue <= "1111";
        ELSIF missile_pixel_on = '1' THEN
            collision_red <= "1111";
            collision_green <= "1111";
            collision_blue <= "0000";
        ELSIF coin_pixel_on = '1' THEN
            collision_red <= "0000";
            collision_green <= "1111";
            collision_blue <= "0000";
        ELSIF powerup_pixel_on = '1' THEN
            collision_red <= "0000";
            collision_green <= "1111";
            collision_blue <= "1111";
        ELSIF is_on_any_laser_line = '1' THEN
            collision_red <= "1111";
            collision_green <= "0000";
            collision_blue <= "0000";
        ELSE
            collision_red <= "0000";
            collision_green <= "0000";
            collision_blue <= "000" & collision_pixel_on;
        END IF;
    END PROCESS;

    death <= death_reg;
    powerup_collected <= powerup_collected_reg;

END ARCHITECTURE rtl;
