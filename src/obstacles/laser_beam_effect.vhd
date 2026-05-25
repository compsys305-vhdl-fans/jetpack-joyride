LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.trig_pkg.ALL;

ENTITY laser_beam_effect IS
    PORT (
        clock       : IN STD_LOGIC;
        pixel_x     : IN UNSIGNED(9 DOWNTO 0);
        pixel_y     : IN UNSIGNED(9 DOWNTO 0);
        frame_count : IN UNSIGNED(7 DOWNTO 0);
        beam_rect_mode : IN STD_LOGIC;
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

    CONSTANT BEAM_X_SHIFT : INTEGER := 2;
    CONSTANT AMP1_DIV : INTEGER := 16;
    CONSTANT AMP2_DIV : INTEGER := 32;
    CONSTANT AMP3_DIV : INTEGER := 32;
    CONSTANT AMP4_DIV : INTEGER := 16;
    CONSTANT AMP5_DIV : INTEGER := 64;
    CONSTANT CURVE_LIMIT : INTEGER := 3;
    CONSTANT CURVE_BOOST_LIMIT : INTEGER := 2;

    FUNCTION wrap8(value : INTEGER) RETURN UNSIGNED IS
        VARIABLE tmp : INTEGER;
    BEGIN
        tmp := value MOD 256;
        IF tmp < 0 THEN
            tmp := tmp + 256;
        END IF;
        RETURN TO_UNSIGNED(tmp, 8);
    END FUNCTION;

BEGIN

    PROCESS (clock)
        VARIABLE ax, ay, bx, by : INTEGER;
        VARIABLE px, py : INTEGER;
        VARIABLE abx, aby : INTEGER;
        VARIABLE apx, apy : INTEGER;
        VARIABLE len2 : INTEGER;
        VARIABLE approx_len : INTEGER;
        VARIABLE dot : INTEGER;
        VARIABLE cross : INTEGER;
        VARIABLE beam_u : INTEGER;
        VARIABLE beam_v : INTEGER;
        VARIABLE phase1, phase2, phase3, phase4, phase5 : UNSIGNED(7 DOWNTO 0);
        VARIABLE x_scaled1, x_scaled2, x_scaled3, x_scaled4, x_scaled5 : INTEGER;
        VARIABLE t_scaled1, t_scaled2, t_scaled3, t_scaled4, t_scaled5 : INTEGER;
        VARIABLE sin1_i, sin2_i, sin3_i, sin4_i, sin5_i : INTEGER;
        VARIABLE y_pos : INTEGER;
        VARIABLE curve1, curve2, curve3, curve4, curve5 : INTEGER;
        VARIABLE v1, v2, v3, v4, v5 : INTEGER RANGE 0 TO 63;
        VARIABLE v_r, v_g, v_b : INTEGER RANGE -64 TO 511;
        VARIABLE r_out, g_out, b_out : INTEGER;
        VARIABLE phase_base : INTEGER;
        -- Variables for approx_len calculation
        VARIABLE a, b : NATURAL;
        VARIABLE maximum, minimum : NATURAL;
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

                abx := bx - ax;
                aby := by - ay;
                apx := px - ax;
                apy := py - ay;

                len2 := (abx * abx) + (aby * aby);
                
                -- More accurate and hardware-friendly approximation for vector length
                -- approx_len = max(abs(abx), abs(aby)) + min(abs(abx), abs(aby)) / 2
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
                        beam_u := dot / approx_len;
                        beam_v := cross / approx_len;

                        IF beam_rect_mode = '1' THEN
                            IF -7 < beam_v AND 7 > beam_v THEN
                                color_out <= x"FF0";
                                is_transparent <= '0';
                            END IF;
                        ELSE
                            IF -7 < beam_v AND 7 > beam_v THEN
                                color_out <= x"FF0";
                                is_transparent <= '0';
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
