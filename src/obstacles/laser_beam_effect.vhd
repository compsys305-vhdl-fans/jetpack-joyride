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
        x0          : IN UNSIGNED(9 DOWNTO 0);
        y0          : IN UNSIGNED(9 DOWNTO 0);
        x1          : IN UNSIGNED(9 DOWNTO 0);
        y1          : IN UNSIGNED(9 DOWNTO 0);
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
                approx_len := ABS(abx) + ABS(aby);

                IF (len2 > 0) AND (approx_len > 0) THEN
                    dot := (apx * abx) + (apy * aby);
                    cross := (apx * aby) - (apy * abx);
                    IF (dot >= 0) AND (dot <= len2) THEN
                        beam_u := dot / approx_len;
                        beam_v := cross / approx_len;

                        phase_base := (beam_u / (2 ** BEAM_X_SHIFT)) MOD 256;

                        x_scaled1 := phase_base * 2;
                        x_scaled2 := phase_base * 4;
                        x_scaled3 := phase_base * 2;
                        x_scaled4 := phase_base * 4;
                        x_scaled5 := phase_base * 6;

                        t_scaled1 := TO_INTEGER(frame_count) * 10;
                        t_scaled2 := TO_INTEGER(frame_count) * 10;
                        t_scaled3 := TO_INTEGER(frame_count) * 8;
                        t_scaled4 := TO_INTEGER(frame_count) * 12;
                        t_scaled5 := TO_INTEGER(frame_count) * 14;

                        phase1 := wrap8(x_scaled1 - t_scaled1 + 200);
                        phase2 := wrap8(x_scaled2 - t_scaled2 + 164);
                        phase3 := wrap8(x_scaled3 + t_scaled3 + 187);
                        phase4 := wrap8(x_scaled4 - t_scaled4 + 235);
                        phase5 := wrap8(x_scaled5 + t_scaled5 + 184);

                        sin1_i := TO_INTEGER(sin(phase1));
                        sin2_i := TO_INTEGER(sin(phase2));
                        sin3_i := TO_INTEGER(sin(phase3));
                        sin4_i := TO_INTEGER(sin(phase4));
                        sin5_i := TO_INTEGER(sin(phase5));

                        y_pos := beam_v;

                        curve1 := ABS(y_pos - (sin1_i / AMP1_DIV));
                        curve2 := ABS(y_pos - (sin2_i / AMP2_DIV));
                        curve3 := ABS(y_pos - (sin3_i / AMP3_DIV));
                        curve4 := ABS(y_pos - (sin4_i / AMP4_DIV));
                        curve5 := ABS(y_pos - (sin5_i / AMP5_DIV));

                        v1 := 0; IF curve1 < CURVE_LIMIT THEN v1 := 15 - (curve1 * 4); IF curve1 < CURVE_BOOST_LIMIT THEN v1 := v1 + 10; END IF; END IF;
                        v2 := 0; IF curve2 < CURVE_LIMIT THEN v2 := 15 - (curve2 * 4); IF curve2 < CURVE_BOOST_LIMIT THEN v2 := v2 + 10; END IF; END IF;
                        v3 := 0; IF curve3 < CURVE_LIMIT THEN v3 := 15 - (curve3 * 4); IF curve3 < CURVE_BOOST_LIMIT THEN v3 := v3 + 10; END IF; END IF;
                        v4 := 0; IF curve4 < CURVE_LIMIT THEN v4 := 15 - (curve4 * 4); IF curve4 < CURVE_BOOST_LIMIT THEN v4 := v4 + 10; END IF; END IF;
                        v5 := 0; IF curve5 < CURVE_LIMIT THEN v5 := 15 - (curve5 * 4); IF curve5 < CURVE_BOOST_LIMIT THEN v5 := v5 + 10; END IF; END IF;

                        v_r := v1 + v2 + (v2 / 4) + v3 - (v3 / 4) + v4 - (v4 / 4) + v5 + (v5 / 4);
                        v_g := v1 + v2 - (v2 / 4) + v3 + (v3 / 4) + v4 + (v4 / 4) + v5 - (v5 / 4);
                        v_b := v3 + v5;

                        IF v_r > 15 THEN r_out := 15; ELSIF v_r < 0 THEN r_out := 0; ELSE r_out := v_r; END IF;
                        IF v_g > 15 THEN g_out := 15; ELSIF v_g < 0 THEN g_out := 0; ELSE g_out := v_g; END IF;
                        IF v_b > 15 THEN b_out := 15; ELSIF v_b < 0 THEN b_out := 0; ELSE b_out := v_b; END IF;

                        color_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(r_out, 4) & TO_UNSIGNED(g_out, 4) & TO_UNSIGNED(b_out, 4));
                        is_transparent <= '0';
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
