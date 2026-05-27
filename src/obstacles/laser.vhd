LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.sprite_palettes_pkg.ALL;
USE WORK.obstacle_types.ALL;

ENTITY laser IS
    PORT (
        clock       : IN STD_LOGIC;
        show_djt    : IN STD_LOGIC;
        pixel_x     : IN UNSIGNED(9 DOWNTO 0);
        pixel_y     : IN UNSIGNED(9 DOWNTO 0);
        pos         : IN vec2;
        direction   : IN laser_direction_t;
        length      : IN NATURAL;
        is_active   : IN STD_LOGIC;
        
        color_out      : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        is_transparent : OUT STD_LOGIC
    );
END ENTITY laser;

ARCHITECTURE rtl OF laser IS
    -- Intermediate signed signals for correct arithmetic
    SIGNAL px_s : SIGNED(11 DOWNTO 0);
    SIGNAL py_s : SIGNED(11 DOWNTO 0);

    SIGNAL x0_s : SIGNED(11 DOWNTO 0);
    SIGNAL y0_s : SIGNED(11 DOWNTO 0);
    SIGNAL x1_s : SIGNED(11 DOWNTO 0);
    SIGNAL y1_s : SIGNED(11 DOWNTO 0);

    -- Signals for node 1
    SIGNAL node1_color          : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL node1_is_transparent : STD_LOGIC;
    SIGNAL node1_valid          : STD_LOGIC;
    SIGNAL node1_rel_x_s        : SIGNED(15 DOWNTO 0);
    SIGNAL node1_rel_y_s        : SIGNED(15 DOWNTO 0);
    SIGNAL node1_rel_x          : UNSIGNED(15 DOWNTO 0);
    SIGNAL node1_rel_y          : UNSIGNED(15 DOWNTO 0);
    
    -- Signals for node 2
    SIGNAL node2_color          : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL node2_is_transparent : STD_LOGIC;
    SIGNAL node2_valid          : STD_LOGIC;
    SIGNAL node2_rel_x_s        : SIGNED(15 DOWNTO 0);
    SIGNAL node2_rel_y_s        : SIGNED(15 DOWNTO 0);
    SIGNAL node2_rel_x          : UNSIGNED(15 DOWNTO 0);
    SIGNAL node2_rel_y          : UNSIGNED(15 DOWNTO 0);

    -- Signals for the beam
    SIGNAL beam_color           : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL beam_is_transparent  : STD_LOGIC;


BEGIN
    -- Convert pixel coordinates to signed for calculations
    px_s <= RESIZE(SIGNED('0' & pixel_x), 12);
    py_s <= RESIZE(SIGNED('0' & pixel_y), 12);
    x0_s <= pos.x;
    y0_s <= pos.y;

    process(pos, direction, length)
        VARIABLE len_s : SIGNED(11 DOWNTO 0);
    BEGIN
        len_s := TO_SIGNED(INTEGER(length), 12);

        IF direction = VERTICAL THEN
            x1_s <= pos.x;
            y1_s <= pos.y + len_s;
        ELSE
            x1_s <= pos.x + len_s;
            y1_s <= pos.y;
        END IF;
    END PROCESS;

    -- Calculate relative coordinates for each node using signed arithmetic
    node1_rel_x_s <= RESIZE(px_s - (x0_s - 8), 16);
    node1_rel_y_s <= RESIZE(py_s - (y0_s - 8), 16);
    node2_rel_x_s <= RESIZE(px_s - (x1_s - 8), 16);
    node2_rel_y_s <= RESIZE(py_s - (y1_s - 8), 16);

    -- Conditionally rotate sprites for vertical lasers
    rotate_proc: PROCESS(direction, node1_rel_x_s, node1_rel_y_s, node2_rel_x_s, node2_rel_y_s)
    BEGIN
        -- Default assignments to prevent latches and ensure out-of-bounds is hidden
        node1_rel_x <= TO_UNSIGNED(99, 16);
        node1_rel_y <= TO_UNSIGNED(99, 16);
        node2_rel_x <= TO_UNSIGNED(99, 16);
        node2_rel_y <= TO_UNSIGNED(99, 16);

        IF direction = VERTICAL THEN
            -- Proper 90 degree counter-clockwise rotation for vertical lasers
            -- Only render if the pixel is within the 16x16 bounding box of the node
            IF node1_rel_x_s >= 0 AND node1_rel_x_s < 16 AND node1_rel_y_s >= 0 AND node1_rel_y_s < 16 THEN
                node1_rel_x <= UNSIGNED(node1_rel_y_s);
                node1_rel_y <= TO_UNSIGNED(15 - TO_INTEGER(node1_rel_x_s), 16);
            END IF;
            IF node2_rel_x_s >= 0 AND node2_rel_x_s < 16 AND node2_rel_y_s >= 0 AND node2_rel_y_s < 16 THEN
                node2_rel_x <= UNSIGNED(node2_rel_y_s);
                node2_rel_y <= TO_UNSIGNED(15 - TO_INTEGER(node2_rel_x_s), 16);
            END IF;
        ELSE
            -- Horizontal laser, no rotation
            IF node1_rel_x_s >= 0 AND node1_rel_x_s < 16 AND node1_rel_y_s >= 0 AND node1_rel_y_s < 16 THEN
                node1_rel_x <= UNSIGNED(node1_rel_x_s);
                node1_rel_y <= UNSIGNED(node1_rel_y_s);
            END IF;
            IF node2_rel_x_s >= 0 AND node2_rel_x_s < 16 AND node2_rel_y_s >= 0 AND node2_rel_y_s < 16 THEN
                node2_rel_x <= UNSIGNED(node2_rel_x_s);
                node2_rel_y <= UNSIGNED(node2_rel_y_s);
            END IF;
        END IF;
    END PROCESS rotate_proc;

    -- Instantiate the sprite renderer for node 1
    node1_renderer : ENTITY work.sprite_renderer
        PORT MAP (
            clock          => clock,
            show_djt       => show_djt,
            sprite_id      => SPRITE_LASER_NODE_FLIPPED,
            palette_id     => PALETTE_LASER,
            scale_shift    => 0,
            rel_x          => node1_rel_x,
            rel_y          => node1_rel_y,
            color          => node1_color,
            is_transparent => node1_is_transparent,
            valid          => node1_valid
        );

    -- Instantiate the sprite renderer for node 2
    node2_renderer : ENTITY work.sprite_renderer
        PORT MAP (
            clock          => clock,
            show_djt       => show_djt,
            sprite_id      => SPRITE_LASER_NODE,
            palette_id     => PALETTE_LASER,
            scale_shift    => 0,
            rel_x          => node2_rel_x,
            rel_y          => node2_rel_y,
            color          => node2_color,
            is_transparent => node2_is_transparent,
            valid          => node2_valid
        );
        
    -- Instantiate the beam effect
    beam_renderer : ENTITY work.laser_beam_effect
        PORT MAP (
            clock          => clock,
            pixel_x        => pixel_x,
            pixel_y        => pixel_y,
            x0             => x0_s,
            y0             => y0_s,
            x1             => x1_s,
            y1             => y1_s,
            is_active      => is_active,
            color_out      => beam_color,
            is_transparent => beam_is_transparent
        );

    -- Combine the outputs
    PROCESS(is_active, node1_is_transparent, node1_color, node2_is_transparent, node2_color, beam_is_transparent, beam_color)
    BEGIN
        IF is_active = '1' THEN
            IF node1_is_transparent = '0' THEN
                color_out <= node1_color;
                is_transparent <= '0';
            ELSIF node2_is_transparent = '0' THEN
                color_out <= node2_color;
                is_transparent <= '0';
            ELSIF beam_is_transparent = '0' THEN
                color_out <= beam_color;
                is_transparent <= '0';
            ELSE
                color_out <= (OTHERS => '0');
                is_transparent <= '1';
            END IF;
        ELSE
            color_out <= (OTHERS => '0');
            is_transparent <= '1';
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
