LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY laser_beam_effect IS
    PORT (
        clock       : IN STD_LOGIC;
        pixel_x     : IN UNSIGNED(9 DOWNTO 0);
        pixel_y     : IN UNSIGNED(9 DOWNTO 0);
        x0          : IN SIGNED(11 DOWNTO 0);
        y0          : IN SIGNED(11 DOWNTO 0);
        x1          : IN SIGNED(11 DOWNTO 0);
        y1          : IN SIGNED(11 DOWNTO 0);
        is_active   : IN STD_LOGIC;
        
        color_out   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        is_transparent : OUT STD_LOGIC
    );
END ENTITY laser_beam_effect;

ARCHITECTURE rtl OF laser_beam_effect IS

    CONSTANT BEAM_HALF_WIDTH : INTEGER := 7;

BEGIN

    PROCESS (clock)
        VARIABLE ax, ay, bx, by : INTEGER;
        VARIABLE px, py : INTEGER;
        VARIABLE min_x, max_x, min_y, max_y : INTEGER;
    BEGIN
        IF RISING_EDGE(clock) THEN
            color_out <= (OTHERS => '0');
            is_transparent <= '1';

            IF is_active = '1' THEN
                ax := TO_INTEGER(x0);
                ay := TO_INTEGER(y0);
                bx := TO_INTEGER(x1);
                by := TO_INTEGER(y1);
                px := TO_INTEGER(pixel_x);
                py := TO_INTEGER(pixel_y);

                IF ax = bx THEN
                    -- Vertical laser: compute min/max Y to handle either ordering
                    IF ay < by THEN
                        min_y := ay;
                        max_y := by;
                    ELSE
                        min_y := by;
                        max_y := ay;
                    END IF;
                    IF (ABS(px - ax) < BEAM_HALF_WIDTH) AND (py >= min_y) AND (py <= max_y) THEN
                        color_out <= x"FF0";
                        is_transparent <= '0';
                    END IF;
                ELSIF ay = by THEN
                    -- Horizontal laser: compute min/max X to handle either ordering
                    IF ax < bx THEN
                        min_x := ax;
                        max_x := bx;
                    ELSE
                        min_x := bx;
                        max_x := ax;
                    END IF;
                    IF (ABS(py - ay) < BEAM_HALF_WIDTH) AND (px >= min_x) AND (px <= max_x) THEN
                        color_out <= x"FF0";
                        is_transparent <= '0';
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
