LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE sprite_palettes_pkg IS
    -- Palette IDs
    CONSTANT PALETTE_BARRY        : UNSIGNED(7 DOWNTO 0) := x"00";
    CONSTANT PALETTE_LIL_STOMPER  : UNSIGNED(7 DOWNTO 0) := x"01";
    CONSTANT PALETTE_BIRD         : UNSIGNED(7 DOWNTO 0) := x"02";
    CONSTANT PALETTE_TELEPORTER   : UNSIGNED(7 DOWNTO 0) := x"03";

    -- Sprite IDs
    CONSTANT SPRITE_BARRY_RUN     : UNSIGNED(7 DOWNTO 0) := x"00";
    CONSTANT SPRITE_BARRY_FLY     : UNSIGNED(7 DOWNTO 0) := x"02";

    CONSTANT SPRITE_STOMPER_RUN   : UNSIGNED(7 DOWNTO 0) := x"10";
    CONSTANT SPRITE_STOMPER_FLY   : UNSIGNED(7 DOWNTO 0) := x"11";
    CONSTANT SPRITE_STOMPER_FALL  : UNSIGNED(7 DOWNTO 0) := x"12";

    CONSTANT SPRITE_BIRD_HOLD     : UNSIGNED(7 DOWNTO 0) := x"20";
    CONSTANT SPRITE_BIRD_NOHOLD   : UNSIGNED(7 DOWNTO 0) := x"21";

    CONSTANT SPRITE_TELEPORTER    : UNSIGNED(7 DOWNTO 0) := x"30";

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

    CONSTANT LIL_STOMPER_PALETTE : palette_array_t(0 TO 6) := (
        x"0F0", -- Transparent (was x"100")
        x"A54",
        x"E54",
        x"FFF",
        x"633",
        x"BBA",
        x"EB9"
    );

    CONSTANT BIRD_PALETTE : palette_array_t(0 TO 7) := (
        x"0F0", -- Transparent (was x"100")
        x"633",
        x"EB9",
        x"FFF",
        x"AAF",
        x"C74",
        x"A33",
        x"A53"
    );

    CONSTANT TELEPORTER_PALETTE : palette_array_t(0 TO 7) := (
        x"0F0", -- Transparent (was x"100")
        x"635",
        x"978",
        x"EBD",
        x"859",
        x"EB7",
        x"957",
        x"DAA"
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
            WHEN PALETTE_LIL_STOMPER =>
                IF idx >= 0 AND idx <= 6 THEN
                    RETURN LIL_STOMPER_PALETTE(idx);
                ELSE
                    RETURN TRANSPARENT_COLOR;
                END IF;
            WHEN PALETTE_BIRD =>
                IF idx >= 0 AND idx <= 7 THEN
                    RETURN BIRD_PALETTE(idx);
                ELSE
                    RETURN TRANSPARENT_COLOR;
                END IF;
            WHEN PALETTE_TELEPORTER =>
                IF idx >= 0 AND idx <= 7 THEN
                    RETURN TELEPORTER_PALETTE(idx);
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
            WHEN SPRITE_BARRY_RUN | SPRITE_BARRY_FLY | SPRITE_STOMPER_FLY | SPRITE_STOMPER_FALL => 
                -- 200ms per frame (3 ticks, 12Hz)
                IF (anim_tick MOD 6) < 3 THEN
                    RETURN 0;
                ELSE
                    RETURN 1;
                END IF;

            WHEN SPRITE_STOMPER_RUN =>
                -- 200ms per frame (3 ticks, 12Hz)
                IF (anim_tick MOD 6) < 3 THEN
                    RETURN 0;
                ELSE
                    RETURN 1;
                END IF;

            WHEN SPRITE_TELEPORTER =>
                -- 500ms per frame (6 ticks, 12Hz)
                IF anim_tick < 6 THEN
                    RETURN 0;
                ELSE
                    RETURN 1;
                END IF;

            WHEN OTHERS =>
                -- Non-animated sprites (e.g., Bird)
                RETURN 0;
        END CASE;
    END FUNCTION get_anim_frame;
    
END PACKAGE BODY sprite_palettes_pkg;
