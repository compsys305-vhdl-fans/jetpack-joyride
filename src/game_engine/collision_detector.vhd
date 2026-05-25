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
        frame_count          : IN UNSIGNED(7 DOWNTO 0);
        death                : OUT STD_LOGIC;
        collision_red        : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        collision_green      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        collision_blue       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY collision_detector;

ARCHITECTURE rtl OF collision_detector IS
    COMPONENT sprite_renderer IS
        PORT (
            clock : IN STD_LOGIC;
            
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
    SIGNAL player_sprite_id : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_palette_id : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL player_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL player_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL player_sprite_is_transparent : STD_LOGIC;
    SIGNAL player_sprite_valid : STD_LOGIC;

    -- Laser signals
    SIGNAL is_on_any_laser_line : STD_LOGIC;
    SIGNAL player_pixel_on : STD_LOGIC;
    SIGNAL collision_pixel_on : STD_LOGIC;

    SIGNAL death_reg : STD_LOGIC := '0';

    CONSTANT PLAYER_X_POS : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(100, 10);
    CONSTANT BEAM_HALF_WIDTH : INTEGER := 7;
    CONSTANT NODE_HALF_SIZE : INTEGER := 8;

BEGIN
    -- Player Sprite Selection
    PROCESS(player_grounded, left_button)
    BEGIN
        IF player_grounded = '1' THEN
            player_sprite_id <= SPRITE_BARRY_RUN;
        ELSE
            player_sprite_id <= SPRITE_BARRY_FLY;
        END IF;
    END PROCESS;
    
    player_palette_id <= PALETTE_BARRY;
    player_rel_x <= resize(pixel_x - PLAYER_X_POS, 16);
    player_rel_y <= resize(pixel_y - UNSIGNED(player_y), 16);

    player_sprite_renderer: sprite_renderer
        PORT MAP (
            clock => clock_25MHz,
            sprite_id => player_sprite_id,
            palette_id => player_palette_id,
            scale_shift => 0,
            rel_x => player_rel_x,
            rel_y => player_rel_y,
            color => player_sprite_color,
            is_transparent => player_sprite_is_transparent,
            valid => player_sprite_valid
        );

    player_pixel_on <= player_sprite_valid AND (NOT player_sprite_is_transparent);
    collision_pixel_on <= player_pixel_on AND is_on_any_laser_line;
    
    -- Laser Collision Detection (beam rectangle only; excludes endpoints)
    PROCESS(laser_pool, pixel_x, pixel_y)
        VARIABLE on_laser : BOOLEAN := false;
        VARIABLE px, py : INTEGER;
        VARIABLE ax, ay, bx, by : INTEGER;
        VARIABLE abx, aby : INTEGER;
        VARIABLE apx, apy : INTEGER;
        VARIABLE len2 : INTEGER;
        VARIABLE approx_len : INTEGER;
        VARIABLE dot : INTEGER;
        VARIABLE cross : INTEGER;
        VARIABLE beam_v : INTEGER;
        VARIABLE a, b : NATURAL;
        VARIABLE maximum, minimum : NATURAL;
    BEGIN
        px := TO_INTEGER(pixel_x);
        py := TO_INTEGER(pixel_y);

        FOR i IN 0 TO MAX_LASERS - 1 LOOP
            IF laser_pool(i).is_active = '1' THEN
                ax := TO_INTEGER(laser_pool(i).x0);
                ay := TO_INTEGER(laser_pool(i).y0);
                bx := TO_INTEGER(laser_pool(i).x1);
                by := TO_INTEGER(laser_pool(i).y1);

                IF (ABS(px - ax) < NODE_HALF_SIZE AND ABS(py - ay) < NODE_HALF_SIZE) OR
                   (ABS(px - bx) < NODE_HALF_SIZE AND ABS(py - by) < NODE_HALF_SIZE) THEN
                    NULL;
                ELSE
                    abx := bx - ax;
                    aby := by - ay;
                    apx := px - ax;
                    apy := py - ay;
                    len2 := (abx * abx) + (aby * aby);

                    a := ABS(abx);
                    b := ABS(aby);
                    IF a > b THEN
                        maximum := a;
                        minimum := b;
                    ELSE
                        maximum := b;
                        minimum := a;
                    END IF;
                    approx_len := maximum + (minimum / 2);

                    IF (len2 > 0) AND (approx_len > 0) THEN
                        dot := (apx * abx) + (apy * aby);
                        cross := (apx * aby) - (apy * abx);
                        IF (dot >= 0) AND (dot <= len2) THEN
                            beam_v := cross / approx_len;
                            IF ABS(beam_v) < BEAM_HALF_WIDTH THEN
                                on_laser := true;
                                EXIT;
                            END IF;
                        END IF;
                    END IF;
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
        IF vert_sync = '1' THEN
            death_reg <= '0';
        ELSIF RISING_EDGE(clock_25MHz) THEN
            IF player_sprite_valid = '1' AND player_sprite_is_transparent = '0' AND is_on_any_laser_line = '1' THEN
                death_reg <= '1';
            END IF;
        END IF;
    END PROCESS;

    PROCESS(player_pixel_on, is_on_any_laser_line, collision_pixel_on)
    BEGIN
        IF collision_pixel_on = '1' THEN
            collision_red <= "1111";
            collision_green <= "1111";
            collision_blue <= "1111";
        ELSIF player_pixel_on = '1' THEN
            collision_red <= "0000";
            collision_green <= "0000";
            collision_blue <= "1111";
        ELSIF is_on_any_laser_line = '1' THEN
            collision_red <= "1111";
            collision_green <= "0000";
            collision_blue <= "0000";
        ELSE
            collision_red <= "0000";
            collision_green <= "0000";
            collision_blue <= "0000";
        END IF;
    END PROCESS;

    death <= death_reg;

END ARCHITECTURE rtl;
