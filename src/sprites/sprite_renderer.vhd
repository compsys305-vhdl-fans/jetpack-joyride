LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.sprite_palettes_pkg.ALL;

ENTITY sprite_renderer IS
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
END ENTITY sprite_renderer;

ARCHITECTURE rtl OF sprite_renderer IS

    COMPONENT image_loader IS
        GENERIC (
            IMAGE_WIDTH : POSITIVE;
            IMAGE_HEIGHT : POSITIVE;
            MIF_FILE : STRING;
            FLIP_X : boolean := false
        );
        PORT (
            clock : IN STD_LOGIC;
            x : IN UNSIGNED(15 DOWNTO 0);
            y : IN UNSIGNED(15 DOWNTO 0);
            pixel_index : OUT UNSIGNED(7 DOWNTO 0);
            valid : OUT STD_LOGIC
        );
    END COMPONENT image_loader;

    SIGNAL local_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL local_y : UNSIGNED(15 DOWNTO 0);

    -- Animation Signals (25MHz clock -> 2,500,000 cycles; ~83 ms = 1 tick, 12 ticks = 1 second)              2083333 ~ roughly 12 ticks per second
    CONSTANT TICK_CYCLES : INTEGER := 2083333 - 1;
    SIGNAL tick_counter  : INTEGER RANGE 0 TO TICK_CYCLES := 0;
    SIGNAL anim_tick     : INTEGER RANGE 0 TO 11 := 0;
    SIGNAL death_cycle_step : INTEGER RANGE 0 TO 5 := 0;

    -- Player Sprite Signals
    SIGNAL player_run1_pixel_index, player_run2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_run1_valid, player_run2_valid             : STD_LOGIC;
    
    SIGNAL player_air1_pixel_index, player_air2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_air1_valid, player_air2_valid             : STD_LOGIC;

    -- Stomper Sprite Signals
    SIGNAL stomper_run1_pixel_index, stomper_run2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL stomper_run1_valid, stomper_run2_valid             : STD_LOGIC;
    SIGNAL stomper_fly1_pixel_index, stomper_fly2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL stomper_fly1_valid, stomper_fly2_valid             : STD_LOGIC;
    SIGNAL stomper_fall1_pixel_index, stomper_fall2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL stomper_fall1_valid, stomper_fall2_valid             : STD_LOGIC;

    -- Bird Sprite Signals
    SIGNAL bird1_pixel_index, bird2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL bird1_valid, bird2_valid             : STD_LOGIC;

    -- Teleporter Sprite Signals
    SIGNAL teleporter1_pixel_index, teleporter2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL teleporter1_valid, teleporter2_valid             : STD_LOGIC;

    -- Laser Sprite Signals
    SIGNAL laser1_pixel_index, laser2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL laser1_valid, laser2_valid             : STD_LOGIC;
    SIGNAL laser1_flipped_pixel_index, laser2_flipped_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL laser1_flipped_valid, laser2_flipped_valid             : STD_LOGIC;

    -- Background Sprite Signals
    SIGNAL bg_light_pixel_index, bg_pillar_pixel_index, bg_plain_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL bg_light_valid, bg_pillar_valid, bg_plain_valid : STD_LOGIC;
    SIGNAL djt_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL djt_valid : STD_LOGIC;
    SIGNAL djt_source_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL djt_source_y : UNSIGNED(15 DOWNTO 0);

    -- Death Sprite Signals
    SIGNAL death_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL death_valid : STD_LOGIC;

    -- Pause Sprite Signals
    SIGNAL pause_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL pause_valid : STD_LOGIC;

    -- Warning Sprite Signals
    SIGNAL warning_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL warning_valid : STD_LOGIC;

    -- Missile Sprite Signals
    SIGNAL missile1_pixel_index, missile2_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL missile1_valid, missile2_valid             : STD_LOGIC;

    -- Coin Sprite Signals
    SIGNAL coin1_pixel_index, coin2_pixel_index, coin3_pixel_index, coin4_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL coin1_valid, coin2_valid, coin3_valid, coin4_valid             : STD_LOGIC;

    -- Powerup Sprite Signals
    SIGNAL powerup_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL powerup_valid : STD_LOGIC;

    -- Title Sprite Signals
    SIGNAL title_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL title_valid : STD_LOGIC;


    CONSTANT DJT_SOURCE_WIDTH : NATURAL := 400;
    CONSTANT DJT_SOURCE_HEIGHT : NATURAL := 600;
    CONSTANT DJT_ROTATED_WIDTH : NATURAL := DJT_SOURCE_HEIGHT;
    CONSTANT DJT_ROTATED_HEIGHT : NATURAL := DJT_SOURCE_WIDTH;

    -- Routing signals
    SIGNAL active_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL active_valid       : STD_LOGIC;
    SIGNAL adjusted_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL mapped_color       : STD_LOGIC_VECTOR(11 DOWNTO 0);

    TYPE death_cycle_idx_t IS ARRAY (0 TO 5) OF UNSIGNED(7 DOWNTO 0);
    CONSTANT DEATH_CYCLE_ORDER : death_cycle_idx_t := (
        x"05", -- red
        x"04", -- orange
        x"07", -- yellow
        x"03", -- green
        x"02", -- blue
        x"06"  -- pink
    );

    FUNCTION map_rainbow_cycle(idx : UNSIGNED(7 DOWNTO 0); step : INTEGER) RETURN UNSIGNED IS
        VARIABLE mapped : UNSIGNED(7 DOWNTO 0) := idx;
        VARIABLE pos : INTEGER := -1;
    BEGIN
        FOR i IN 0 TO 5 LOOP
            IF idx = DEATH_CYCLE_ORDER(i) THEN
                pos := i;
            END IF;
        END LOOP;

        IF pos /= -1 THEN
            mapped := DEATH_CYCLE_ORDER((pos + step) MOD 6);
        END IF;

        RETURN mapped;
    END FUNCTION map_rainbow_cycle;
    
BEGIN

    -- 0. Internal Animation Clock
    PROCESS(clock)
    BEGIN
        IF RISING_EDGE(clock) THEN
            IF tick_counter = TICK_CYCLES THEN
                tick_counter <= 0;
                -- 12 tick cycle
                IF anim_tick = 11 THEN
                    anim_tick <= 0;
                ELSE
                    anim_tick <= anim_tick + 1;
                END IF;

                IF death_cycle_step = 5 THEN
                    death_cycle_step <= 0;
                ELSE
                    death_cycle_step <= death_cycle_step + 1;
                END IF;
            ELSE
                tick_counter <= tick_counter + 1;
            END IF;
        END IF;
    END PROCESS;

    -- 1. Apply bit-shift scaling to incoming relative coordinates
    local_x <= SHIFT_RIGHT(rel_x, scale_shift);
    local_y <= SHIFT_RIGHT(rel_y, scale_shift);

    -- 2. Instantiate all ROMs
    player_run1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/barry/run1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => player_run1_pixel_index, valid => player_run1_valid);

    player_run2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/barry/run2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => player_run2_pixel_index, valid => player_run2_valid);

    player_air1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/barry/active1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => player_air1_pixel_index, valid => player_air1_valid);

    player_air2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/barry/active2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => player_air2_pixel_index, valid => player_air2_valid);

    stomper_run1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 64, MIF_FILE => "../res/lil-stomper/running1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => stomper_run1_pixel_index, valid => stomper_run1_valid);

    stomper_run2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 64, MIF_FILE => "../res/lil-stomper/running2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => stomper_run2_pixel_index, valid => stomper_run2_valid);

    stomper_fly1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 64, MIF_FILE => "../res/lil-stomper/flying1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => stomper_fly1_pixel_index, valid => stomper_fly1_valid);

    stomper_fly2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 64, MIF_FILE => "../res/lil-stomper/flying2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => stomper_fly2_pixel_index, valid => stomper_fly2_valid);

    stomper_fall1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 64, MIF_FILE => "../res/lil-stomper/falling1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => stomper_fall1_pixel_index, valid => stomper_fall1_valid);

    stomper_fall2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 64, MIF_FILE => "../res/lil-stomper/falling2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => stomper_fall2_pixel_index, valid => stomper_fall2_valid);

    bird1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 32, IMAGE_HEIGHT => 32, MIF_FILE => "../res/bird/bird1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => bird1_pixel_index, valid => bird1_valid);

    bird2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 32, IMAGE_HEIGHT => 32, MIF_FILE => "../res/bird/bird2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => bird2_pixel_index, valid => bird2_valid);

    teleporter1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 32, IMAGE_HEIGHT => 32, MIF_FILE => "../res/teleporter/teleporter1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => teleporter1_pixel_index, valid => teleporter1_valid);

    teleporter2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 32, IMAGE_HEIGHT => 32, MIF_FILE => "../res/teleporter/teleporter2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => teleporter2_pixel_index, valid => teleporter2_valid);

    laser1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/laser/laser1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => laser1_pixel_index, valid => laser1_valid);

    laser2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/laser/laser2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => laser2_pixel_index, valid => laser2_valid);

    laser1_flipped_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/laser/laser1.mif", FLIP_X => true)
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => laser1_flipped_pixel_index, valid => laser1_flipped_valid);

    laser2_flipped_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/laser/laser2.mif", FLIP_X => true)
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => laser2_flipped_pixel_index, valid => laser2_flipped_valid);

    bg_light_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 240, MIF_FILE => "../res/background2/background-light.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => bg_light_pixel_index, valid => bg_light_valid);

    bg_pillar_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 240, MIF_FILE => "../res/background2/background-pillar.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => bg_pillar_pixel_index, valid => bg_pillar_valid);

    bg_plain_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 64, IMAGE_HEIGHT => 240, MIF_FILE => "../res/background2/background-plain.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => bg_plain_pixel_index, valid => bg_plain_valid);

    death_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 42, IMAGE_HEIGHT => 13, MIF_FILE => "../res/ui/death.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => death_pixel_index, valid => death_valid);

    pause_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 34, IMAGE_HEIGHT => 13, MIF_FILE => "../res/ui/pause.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => pause_pixel_index, valid => pause_valid);

    warning_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/warning/warning.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => warning_pixel_index, valid => warning_valid);

    missile1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/missile/missile1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => missile1_pixel_index, valid => missile1_valid);

    missile2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/missile/missile2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => missile2_pixel_index, valid => missile2_valid);

    coin1_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/coin/coin1.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => coin1_pixel_index, valid => coin1_valid);

    coin2_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/coin/coin2.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => coin2_pixel_index, valid => coin2_valid);

    coin3_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/coin/coin3.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => coin3_pixel_index, valid => coin3_valid);

    coin4_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 16, IMAGE_HEIGHT => 16, MIF_FILE => "../res/coin/coin4.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => coin4_pixel_index, valid => coin4_valid);

    powerup_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 32, IMAGE_HEIGHT => 32, MIF_FILE => "../res/powerup/powerup.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => powerup_pixel_index, valid => powerup_valid);
    title_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 240, IMAGE_HEIGHT => 60, MIF_FILE => "../res/title/title.mif")
        PORT MAP (clock => clock, x => local_x, y => local_y, pixel_index => title_pixel_index, valid => title_valid);

    PROCESS(local_x, local_y)
    BEGIN
        IF (TO_INTEGER(local_x) < DJT_ROTATED_WIDTH) AND (TO_INTEGER(local_y) < DJT_ROTATED_HEIGHT) THEN
            djt_source_x <= RESIZE(local_y, 16);
            djt_source_y <= TO_UNSIGNED(DJT_SOURCE_HEIGHT - 1, 16) - local_x;
        ELSE
            djt_source_x <= (OTHERS => '0');
            djt_source_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    djt_rom: image_loader
        GENERIC MAP (IMAGE_WIDTH => 400, IMAGE_HEIGHT => 600, MIF_FILE => "../res/djt/djtbl.mif")
        PORT MAP (clock => clock, x => djt_source_x, y => djt_source_y, pixel_index => djt_pixel_index, valid => djt_valid);

    -- 3. Multiplex outputs based on sprite_id
    PROCESS(sprite_id, anim_tick, show_djt,
            player_run1_pixel_index, player_run1_valid, player_run2_pixel_index, player_run2_valid,
            player_air1_pixel_index, player_air1_valid, player_air2_pixel_index, player_air2_valid,
            stomper_run1_pixel_index, stomper_run1_valid, stomper_run2_pixel_index, stomper_run2_valid,
            stomper_fly1_pixel_index, stomper_fly1_valid, stomper_fly2_pixel_index, stomper_fly2_valid,
            stomper_fall1_pixel_index, stomper_fall1_valid, stomper_fall2_pixel_index, stomper_fall2_valid,
            bird1_pixel_index, bird1_valid, bird2_pixel_index, bird2_valid,
            teleporter1_pixel_index, teleporter1_valid, teleporter2_pixel_index, teleporter2_valid,
            laser1_pixel_index, laser1_valid, laser2_pixel_index, laser2_valid,
            laser1_flipped_pixel_index, laser1_flipped_valid, laser2_flipped_pixel_index, laser2_flipped_valid,
            bg_light_pixel_index, bg_light_valid, bg_pillar_pixel_index, bg_pillar_valid, bg_plain_pixel_index, bg_plain_valid,
            djt_pixel_index, djt_valid,
            death_pixel_index, death_valid,
            pause_pixel_index, pause_valid,
            warning_pixel_index, warning_valid,
            missile1_pixel_index, missile1_valid, missile2_pixel_index, missile2_valid,
            coin1_pixel_index, coin1_valid,
            coin2_pixel_index, coin2_valid,
            coin3_pixel_index, coin3_valid,
            coin4_pixel_index, coin4_valid,
            powerup_pixel_index, powerup_valid,
            title_pixel_index, title_valid)
    BEGIN
        CASE sprite_id IS
            WHEN SPRITE_BARRY_RUN => -- Running (Animated)
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= player_run1_pixel_index;
                    active_valid       <= player_run1_valid;
                ELSE
                    active_pixel_index <= player_run2_pixel_index;
                    active_valid       <= player_run2_valid;
                END IF;
                
            WHEN SPRITE_BARRY_FLY => -- Flying / Active (Animated)
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= player_air1_pixel_index;
                    active_valid       <= player_air1_valid;
                ELSE
                    active_pixel_index <= player_air2_pixel_index;
                    active_valid       <= player_air2_valid;
                END IF;

            WHEN SPRITE_STOMPER_RUN =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= stomper_run1_pixel_index;
                    active_valid       <= stomper_run1_valid;
                ELSE
                    active_pixel_index <= stomper_run2_pixel_index;
                    active_valid       <= stomper_run2_valid;
                END IF;

            WHEN SPRITE_STOMPER_FLY =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= stomper_fly1_pixel_index;
                    active_valid       <= stomper_fly1_valid;
                ELSE
                    active_pixel_index <= stomper_fly2_pixel_index;
                    active_valid       <= stomper_fly2_valid;
                END IF;

            WHEN SPRITE_STOMPER_FALL =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= stomper_fall1_pixel_index;
                    active_valid       <= stomper_fall1_valid;
                ELSE
                    active_pixel_index <= stomper_fall2_pixel_index;
                    active_valid       <= stomper_fall2_valid;
                END IF;

            WHEN SPRITE_BIRD_HOLD =>
                active_pixel_index <= bird1_pixel_index;
                active_valid       <= bird1_valid;

            WHEN SPRITE_BIRD_NOHOLD =>
                active_pixel_index <= bird2_pixel_index;
                active_valid       <= bird2_valid;
                
            WHEN SPRITE_TELEPORTER =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= teleporter1_pixel_index;
                    active_valid       <= teleporter1_valid;
                ELSE
                    active_pixel_index <= teleporter2_pixel_index;
                    active_valid       <= teleporter2_valid;
                END IF;
            
            WHEN SPRITE_LASER_NODE =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= laser1_pixel_index;
                    active_valid       <= laser1_valid;
                ELSE
                    active_pixel_index <= laser2_pixel_index;
                    active_valid       <= laser2_valid;
                END IF;

            WHEN SPRITE_LASER_NODE_FLIPPED =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= laser1_flipped_pixel_index;
                    active_valid       <= laser1_flipped_valid;
                ELSE
                    active_pixel_index <= laser2_flipped_pixel_index;
                    active_valid       <= laser2_flipped_valid;
                END IF;

            WHEN SPRITE_BG2_LIGHT =>
                active_pixel_index <= bg_light_pixel_index;
                active_valid       <= bg_light_valid;

            WHEN SPRITE_BG2_PILLAR =>
                active_pixel_index <= bg_pillar_pixel_index;
                active_valid       <= bg_pillar_valid;

            WHEN SPRITE_BG2_PLAIN =>
                active_pixel_index <= bg_plain_pixel_index;
                active_valid       <= bg_plain_valid;

            WHEN SPRITE_DJT =>
                active_pixel_index <= djt_pixel_index;
                active_valid       <= djt_valid;

            WHEN SPRITE_DEATH_TEXT =>
                active_pixel_index <= death_pixel_index;
                active_valid       <= death_valid;

            WHEN SPRITE_PAUSE_TEXT =>
                active_pixel_index <= pause_pixel_index;
                active_valid       <= pause_valid;

            WHEN SPRITE_WARNING =>
                active_pixel_index <= warning_pixel_index;
                active_valid       <= warning_valid;

            WHEN SPRITE_MISSILE =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= missile1_pixel_index;
                    active_valid       <= missile1_valid;
                ELSE
                    active_pixel_index <= missile2_pixel_index;
                    active_valid       <= missile2_valid;
                END IF;

            WHEN SPRITE_COIN =>
                -- 11 22 33 44 33 22 (6 frames, 12Hz)
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= coin1_pixel_index;
                    active_valid       <= coin1_valid;
                ELSIF get_anim_frame(sprite_id, anim_tick) = 1 THEN
                    active_pixel_index <= coin2_pixel_index;
                    active_valid       <= coin2_valid;
                ELSIF get_anim_frame(sprite_id, anim_tick) = 2 THEN
                    active_pixel_index <= coin3_pixel_index;
                    active_valid       <= coin3_valid;
                ELSIF get_anim_frame(sprite_id, anim_tick) = 3 THEN
                    active_pixel_index <= coin4_pixel_index;
                    active_valid       <= coin4_valid;
                ELSE
                    active_pixel_index <= coin1_pixel_index;
                    active_valid       <= coin1_valid;
                END IF;

            WHEN SPRITE_POWERUP =>
                active_pixel_index <= powerup_pixel_index;
                active_valid       <= powerup_valid;
            
            WHEN SPRITE_TITLE =>
                active_pixel_index <= title_pixel_index;
                active_valid       <= title_valid;

            WHEN OTHERS =>
                IF show_djt = '1' THEN
                    active_pixel_index <= djt_pixel_index;
                    active_valid       <= djt_valid;
                ELSE
                    active_pixel_index <= (OTHERS => '0');
                    active_valid       <= '0';
                END IF;
        END CASE;
    END PROCESS;

    PROCESS(active_pixel_index, sprite_id, death_cycle_step)
        -- The original pixel index from the sprite MIF file
        VARIABLE original_index : UNSIGNED(7 DOWNTO 0);
    BEGIN
        original_index := active_pixel_index;

        IF (sprite_id = SPRITE_DEATH_TEXT) OR (sprite_id = SPRITE_PAUSE_TEXT) THEN
            -- The UI sprites use a special rainbow cycle effect.
            -- However, this should only apply to the fill colours, not the
            -- transparent background (index 0) or the black outline (index 1).
            IF original_index > x"01" THEN
                adjusted_pixel_index <= map_rainbow_cycle(original_index, death_cycle_step);
            ELSE
                adjusted_pixel_index <= original_index;
            END IF;
        ELSE
            adjusted_pixel_index <= original_index;
        END IF;
    END PROCESS;

    -- 4. Apply palette and transparency check
    mapped_color <= get_sprite_color(palette_id, adjusted_pixel_index);

    PROCESS(mapped_color, active_valid)
    BEGIN
        -- Pass out the mapped color directly
        color <= mapped_color;
        valid <= active_valid;
        
        IF (mapped_color = TRANSPARENT_COLOR) THEN
            is_transparent <= '1';
        ELSE
            is_transparent <= '0';
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
