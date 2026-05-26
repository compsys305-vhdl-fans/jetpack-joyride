LIBRARY IEEE;
LIBRARY palettes;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE palettes.barry_palette_pkg;
USE palettes.lil_stomper_palette_pkg;
USE palettes.bird_palette_pkg;
USE palettes.teleporter_palette_pkg;
USE palettes.laser_palette_pkg;
USE palettes.background2_palette_pkg;
USE palettes.djt_palette_pkg;
-- USE palettes.death_palette_pkg;
USE palettes.ui_palette_pkg;

PACKAGE sprite_palettes_pkg IS
    -- Palette IDs
    CONSTANT PALETTE_BARRY        : UNSIGNED(7 DOWNTO 0) := x"00";
    CONSTANT PALETTE_LIL_STOMPER  : UNSIGNED(7 DOWNTO 0) := x"01";
    CONSTANT PALETTE_BIRD         : UNSIGNED(7 DOWNTO 0) := x"02";
    CONSTANT PALETTE_TELEPORTER   : UNSIGNED(7 DOWNTO 0) := x"03";
    CONSTANT PALETTE_LASER        : UNSIGNED(7 DOWNTO 0) := x"04";
    CONSTANT PALETTE_BACKGROUND2  : UNSIGNED(7 DOWNTO 0) := x"05";
    CONSTANT PALETTE_DJT          : UNSIGNED(7 DOWNTO 0) := x"06";
    CONSTANT PALETTE_DEATH        : UNSIGNED(7 DOWNTO 0) := x"07";
    CONSTANT PALETTE_UI           : UNSIGNED(7 DOWNTO 0) := x"08";

    -- Sprite IDs
    CONSTANT SPRITE_BARRY_RUN     : UNSIGNED(7 DOWNTO 0) := x"00";
    CONSTANT SPRITE_BARRY_FLY     : UNSIGNED(7 DOWNTO 0) := x"02";

    CONSTANT SPRITE_STOMPER_RUN   : UNSIGNED(7 DOWNTO 0) := x"10";
    CONSTANT SPRITE_STOMPER_FLY   : UNSIGNED(7 DOWNTO 0) := x"11";
    CONSTANT SPRITE_STOMPER_FALL  : UNSIGNED(7 DOWNTO 0) := x"12";

    CONSTANT SPRITE_BIRD_HOLD     : UNSIGNED(7 DOWNTO 0) := x"20";
    CONSTANT SPRITE_BIRD_NOHOLD   : UNSIGNED(7 DOWNTO 0) := x"21";

    CONSTANT SPRITE_TELEPORTER    : UNSIGNED(7 DOWNTO 0) := x"30";

    CONSTANT SPRITE_LASER_NODE  : UNSIGNED(7 DOWNTO 0) := x"40";
    CONSTANT SPRITE_LASER_NODE_FLIPPED  : UNSIGNED(7 DOWNTO 0) := x"41";

    CONSTANT SPRITE_BG2_LIGHT    : UNSIGNED(7 DOWNTO 0) := x"50";
    CONSTANT SPRITE_BG2_PILLAR   : UNSIGNED(7 DOWNTO 0) := x"51";
    CONSTANT SPRITE_BG2_PLAIN    : UNSIGNED(7 DOWNTO 0) := x"52";
    CONSTANT SPRITE_DJT          : UNSIGNED(7 DOWNTO 0) := x"53";
    CONSTANT SPRITE_DEATH_TEXT   : UNSIGNED(7 DOWNTO 0) := x"54";
    CONSTANT SPRITE_PAUSE_TEXT   : UNSIGNED(7 DOWNTO 0) := x"55";

    -- We define a function to retrieve colour to allow dynamic palette arrays seamlessly
    FUNCTION get_sprite_color (
        palette_id : UNSIGNED(7 DOWNTO 0);
        pixel_index : UNSIGNED(7 DOWNTO 0)
    ) RETURN STD_LOGIC_VECTOR;
    
    -- Helper function to map a 10Hz animation tick (0-9) to a specific frame (e.g. 0 or 1)
    FUNCTION get_anim_frame (
        sprite_id : UNSIGNED(7 DOWNTO 0);
        anim_tick : INTEGER RANGE 0 TO 11
    ) RETURN INTEGER;

    CONSTANT TRANSPARENT_COLOR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"100"; -- Matches TRANSPARENT_COLOR_4BIT in image_conv.py
    
END PACKAGE sprite_palettes_pkg;

PACKAGE BODY sprite_palettes_pkg IS
    FUNCTION get_sprite_color (
        palette_id : UNSIGNED(7 DOWNTO 0);
        pixel_index : UNSIGNED(7 DOWNTO 0)
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE idx : INTEGER;
    BEGIN
        idx := TO_INTEGER(pixel_index);
        
        CASE palette_id IS
            WHEN PALETTE_BARRY =>
                RETURN barry_palette_pkg.IMAGE_PALETTE(idx);
            WHEN PALETTE_LIL_STOMPER =>
                RETURN lil_stomper_palette_pkg.IMAGE_PALETTE(idx);
            WHEN PALETTE_BIRD =>
                RETURN bird_palette_pkg.IMAGE_PALETTE(idx);
            WHEN PALETTE_TELEPORTER =>
                RETURN teleporter_palette_pkg.IMAGE_PALETTE(idx);
            WHEN PALETTE_LASER =>
                RETURN laser_palette_pkg.IMAGE_PALETTE(idx);
            WHEN PALETTE_BACKGROUND2 =>
                RETURN background2_palette_pkg.IMAGE_PALETTE(idx);
            WHEN PALETTE_DJT =>
                RETURN djt_palette_pkg.IMAGE_PALETTE(idx);
            WHEN PALETTE_DEATH =>
                RETURN ui_palette_pkg.IMAGE_PALETTE(idx); -- Reuse UI palette for death screen for now
            WHEN PALETTE_UI =>
                RETURN ui_palette_pkg.IMAGE_PALETTE(idx);
            WHEN OTHERS =>
                RETURN TRANSPARENT_COLOR;
        END CASE;
    END FUNCTION;

    FUNCTION get_anim_frame (
        sprite_id : UNSIGNED(7 DOWNTO 0);
        anim_tick : INTEGER RANGE 0 TO 11
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

            WHEN SPRITE_LASER_NODE | SPRITE_LASER_NODE_FLIPPED =>
                -- 1-2-1-2 cycle
                IF (anim_tick MOD 4) < 2 THEN
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
