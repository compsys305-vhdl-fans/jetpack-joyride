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

    -- Player Sprite Signals (Sprite ID 0)
    SIGNAL player_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_valid       : STD_LOGIC;

    -- Routing signals
    SIGNAL active_pixel_index : UNSIGNED(7 DOWNTO 0);
    SIGNAL active_valid       : STD_LOGIC;
    SIGNAL mapped_color       : STD_LOGIC_VECTOR(11 DOWNTO 0);
    
BEGIN

    -- 1. Apply bit-shift scaling to incoming relative coordinates
    local_x <= SHIFT_RIGHT(rel_x, scale_shift);
    local_y <= SHIFT_RIGHT(rel_y, scale_shift);

    -- 2. Instantiate all ROMs
    player_rom: image_loader
        GENERIC MAP (
            IMAGE_WIDTH => 16,
            IMAGE_HEIGHT => 16,
            MIF_FILE => "../res/barry/run1.mif"
        )
        PORT MAP (
            clock => clock,
            x => local_x,
            y => local_y,
            pixel_index => player_pixel_index,
            valid => player_valid
        );

    -- 3. Multiplex outputs based on sprite_id
    PROCESS(sprite_id, player_pixel_index, player_valid)
    BEGIN
        CASE sprite_id IS
            WHEN x"00" => 
                active_pixel_index <= player_pixel_index;
                active_valid <= player_valid;
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
