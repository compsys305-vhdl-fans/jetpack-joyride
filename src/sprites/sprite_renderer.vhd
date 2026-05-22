LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.sprite_palettes_pkg.ALL;

ENTITY sprite_renderer IS
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
END ENTITY sprite_renderer;

ARCHITECTURE rtl OF sprite_renderer IS

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
            valid : OUT STD_LOGIC
        );
    END COMPONENT image_loader;

    SIGNAL local_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL local_y : UNSIGNED(15 DOWNTO 0);

    -- Animation Signals (25MHz clock -> 2,500,000 cycles = 100 ms = 1 tick, 10 ticks = 1 second)
    CONSTANT TICK_CYCLES : INTEGER := 2500000 - 1;
    SIGNAL tick_counter  : INTEGER RANGE 0 TO TICK_CYCLES := 0;
    SIGNAL anim_tick     : INTEGER RANGE 0 TO 9 := 0;

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

    -- Routing signals
    SIGNAL active_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL active_valid       : STD_LOGIC;
    SIGNAL mapped_color       : STD_LOGIC_VECTOR(11 DOWNTO 0);
    
BEGIN

    -- 0. Internal Animation Clock
    PROCESS(clock)
    BEGIN
        IF RISING_EDGE(clock) THEN
            IF tick_counter = TICK_CYCLES THEN
                tick_counter <= 0;
                IF anim_tick = 9 THEN
                    anim_tick <= 0;
                ELSE
                    anim_tick <= anim_tick + 1;
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

    -- 3. Multiplex outputs based on sprite_id
    PROCESS(sprite_id, anim_tick,
            player_run1_pixel_index, player_run1_valid, player_run2_pixel_index, player_run2_valid,
            player_air1_pixel_index, player_air1_valid, player_air2_pixel_index, player_air2_valid,
            stomper_run1_pixel_index, stomper_run1_valid, stomper_run2_pixel_index, stomper_run2_valid,
            stomper_fly1_pixel_index, stomper_fly1_valid, stomper_fly2_pixel_index, stomper_fly2_valid,
            stomper_fall1_pixel_index, stomper_fall1_valid, stomper_fall2_pixel_index, stomper_fall2_valid,
            bird1_pixel_index, bird1_valid, bird2_pixel_index, bird2_valid,
            teleporter1_pixel_index, teleporter1_valid, teleporter2_pixel_index, teleporter2_valid)
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
                active_pixel_index <= bird2_pixel_index;
                active_valid       <= bird2_valid;

            WHEN SPRITE_BIRD_NOHOLD =>
                active_pixel_index <= bird1_pixel_index;
                active_valid       <= bird1_valid;
                
            WHEN SPRITE_TELEPORTER =>
                IF get_anim_frame(sprite_id, anim_tick) = 0 THEN
                    active_pixel_index <= teleporter1_pixel_index;
                    active_valid       <= teleporter1_valid;
                ELSE
                    active_pixel_index <= teleporter2_pixel_index;
                    active_valid       <= teleporter2_valid;
                END IF;

            -- Add more sprites here later
            WHEN OTHERS =>
                active_pixel_index <= (OTHERS => '0');
                active_valid <= '0';
        END CASE;
    END PROCESS;

    -- 4. Apply palette and transparency check
    mapped_color <= get_sprite_color(palette_id, active_pixel_index);

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
