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
        death                : OUT STD_LOGIC
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

    SIGNAL death_reg : STD_LOGIC := '0';

    CONSTANT PLAYER_X_POS : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(100, 10);

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
    
    -- Laser Collision Detection (line check)
    PROCESS(laser_pool, pixel_x, pixel_y)
        VARIABLE on_laser : BOOLEAN := false;
        VARIABLE px_s : SIGNED(11 DOWNTO 0);
        VARIABLE py_s : SIGNED(11 DOWNTO 0);
    BEGIN
        px_s := RESIZE(SIGNED('0' & pixel_x), 12);
        py_s := RESIZE(SIGNED('0' & pixel_y), 12);

        FOR i IN 0 TO MAX_LASERS - 1 LOOP
            IF laser_pool(i).is_active = '1' AND
               py_s >= laser_pool(i).y0 AND py_s <= laser_pool(i).y1 AND
               px_s >= laser_pool(i).x0 AND px_s <= laser_pool(i).x1 THEN
                on_laser := true;
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

    death <= death_reg;

END ARCHITECTURE rtl;
