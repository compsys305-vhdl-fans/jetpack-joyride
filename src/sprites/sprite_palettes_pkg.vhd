LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE sprite_palettes_pkg IS
    -- Palette IDs
    CONSTANT PALETTE_BARRY : UNSIGNED(7 DOWNTO 0) := x"00";

    -- We define a function to retrieve colour to allow dynamic palette arrays seamlessly
    FUNCTION get_sprite_color (
        palette_id : UNSIGNED(7 DOWNTO 0);
        pixel_index : UNSIGNED(7 DOWNTO 0)
    ) RETURN STD_LOGIC_VECTOR;
    
    -- Helper function to map a 10Hz animation tick (0-9) to a specific frame (e.g. 0 or 1)
    FUNCTION get_anim_frame (
        sprite_id : UNSIGNED(7 DOWNTO 0);
        anim_tick : INTEGER RANGE 0 TO 9
    ) RETURN INTEGER;

    CONSTANT TRANSPARENT_COLOR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"0F0"; -- Ugly green
    
END PACKAGE sprite_palettes_pkg;

PACKAGE BODY sprite_palettes_pkg IS
    -- We define arrays for our palettes
    TYPE palette_array_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    
    CONSTANT BARRY_PALETTE : palette_array_t(0 TO 7) := (
        x"0F0", -- index 0 was x"100", changed to our standard transparent color
        x"633",
        x"FE3",
        x"EB9",
        x"666",
        x"FFF",
        x"000",
        x"447"
    );

    FUNCTION get_sprite_color (
        palette_id : UNSIGNED(7 DOWNTO 0);
        pixel_index : UNSIGNED(7 DOWNTO 0)
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE idx : INTEGER;
    BEGIN
        idx := TO_INTEGER(pixel_index);
        
        CASE palette_id IS
            WHEN PALETTE_BARRY =>
                IF idx >= 0 AND idx <= 7 THEN
                    RETURN BARRY_PALETTE(idx);
                ELSE
                    RETURN TRANSPARENT_COLOR;
                END IF;
            WHEN OTHERS =>
                RETURN TRANSPARENT_COLOR;
        END CASE;
    END FUNCTION;

    FUNCTION get_anim_frame (
        sprite_id : UNSIGNED(7 DOWNTO 0);
        anim_tick : INTEGER RANGE 0 TO 9
    ) RETURN INTEGER IS
    BEGIN
        CASE sprite_id IS
            WHEN x"00" | x"02" => -- Barry (Running or Active)
                -- Map ticks 0-9 into a frame index.
                -- We want to swap every 200 ms, which means every 2 ticks.
                -- Ticks 0,1 -> 0
                -- Ticks 2,3 -> 1
                -- Ticks 4,5 -> 0
                -- Ticks 6,7 -> 1
                -- Ticks 8,9 -> 0
                IF (anim_tick MOD 4) < 2 THEN
                    RETURN 0;
                ELSE
                    RETURN 1;
                END IF;
            WHEN OTHERS =>
                RETURN 0;
        END CASE;
    END FUNCTION get_anim_frame;
    
END PACKAGE BODY sprite_palettes_pkg;
