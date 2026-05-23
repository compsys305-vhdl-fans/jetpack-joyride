LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.trig_pkg.ALL;

ENTITY strand_effect IS
    PORT (
        clock       : IN STD_LOGIC;
        pixel_x     : IN UNSIGNED(9 DOWNTO 0);
        pixel_y     : IN UNSIGNED(9 DOWNTO 0);
        frame_count : IN UNSIGNED(7 DOWNTO 0);
        r_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        g_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        b_out       : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY strand_effect;

ARCHITECTURE rtl OF strand_effect IS

    -- Pipelined signals for calculating the strands
    SIGNAL phase1, phase2, phase3, phase4, phase5 : UNSIGNED(7 DOWNTO 0);
    SIGNAL sin1, sin2, sin3, sin4, sin5 : SIGNED(7 DOWNTO 0);
    
    SIGNAL curve1, curve2, curve3, curve4, curve5 : SIGNED(11 DOWNTO 0);

BEGIN

    PROCESS (clock)
        VARIABLE x_scaled1, x_scaled2, x_scaled3, x_scaled4, x_scaled5 : UNSIGNED(15 DOWNTO 0);
        VARIABLE t_scaled1, t_scaled2, t_scaled3, t_scaled4, t_scaled5 : UNSIGNED(15 DOWNTO 0);
        VARIABLE y_pos : SIGNED(11 DOWNTO 0);
        VARIABLE v1, v2, v3, v4, v5 : INTEGER RANGE 0 TO 63;
        VARIABLE v_r, v_g, v_b : INTEGER RANGE -64 TO 511;
    BEGIN
        IF RISING_EDGE(clock) THEN
            -- First stage: Calculate phase of each sine wave
            -- Parameters scaled down to fit in 8-bit phase [0, 255]
            x_scaled1 := pixel_x * TO_UNSIGNED(1, 6);
            x_scaled2 := pixel_x * TO_UNSIGNED(2, 6);
            x_scaled3 := pixel_x * TO_UNSIGNED(1, 6);
            x_scaled4 := pixel_x * TO_UNSIGNED(2, 6);
            x_scaled5 := pixel_x * TO_UNSIGNED(3, 6);
            
            t_scaled1 := frame_count * 10;
            t_scaled2 := frame_count * 10;
            t_scaled3 := frame_count * 8;
            t_scaled4 := frame_count * 12;
            t_scaled5 := frame_count * 14;
            
            phase1 <= x_scaled1(7 DOWNTO 0) - t_scaled1(7 DOWNTO 0) + TO_UNSIGNED(200, 8);
            phase2 <= x_scaled2(7 DOWNTO 0) - t_scaled2(7 DOWNTO 0) + TO_UNSIGNED(164, 8);
            phase3 <= x_scaled3(7 DOWNTO 0) + t_scaled3(7 DOWNTO 0) + TO_UNSIGNED(187, 8);
            phase4 <= x_scaled4(7 DOWNTO 0) - t_scaled4(7 DOWNTO 0) + TO_UNSIGNED(235, 8);
            phase5 <= x_scaled5(7 DOWNTO 0) + t_scaled5(7 DOWNTO 0) + TO_UNSIGNED(184, 8);

            -- Second stage: Lookup Sine values
            sin1 <= sin(phase1);
            sin2 <= sin(phase2);
            sin3 <= sin(phase3);
            sin4 <= sin(phase4);
            sin5 <= sin(phase5);
            
            -- Keep Y pos ready for the curve math
            y_pos := SIGNED(RESIZE(pixel_y, 12));
            
            -- Third stage: Calculate the curve difference (absolute distance)
            -- We roughly approximate the y center and sine amplitude scale
            curve1 <= ABS(y_pos - (TO_SIGNED(240, 12) + RESIZE(sin1 * 1, 12)));
            curve2 <= ABS(y_pos - (TO_SIGNED(240, 12) + RESIZE(sin2 / 2, 12)));
            curve3 <= ABS(y_pos - (TO_SIGNED(240, 12) + RESIZE(sin3 / 2, 12)));
            curve4 <= ABS(y_pos - (TO_SIGNED(240, 12) + RESIZE(sin4 * 1, 12)));
            curve5 <= ABS(y_pos - (TO_SIGNED(240, 12) + RESIZE(sin5 / 4, 12)));
            
            -- Fourth stage: Map distance to glow/intensity (simple clamping/inversion)
            v1 := 0; IF curve1 < 32 THEN v1 := 15 - (TO_INTEGER(curve1) / 2); IF curve1 < 2 THEN v1 := v1 + 10; END IF; END IF;
            v2 := 0; IF curve2 < 32 THEN v2 := 15 - (TO_INTEGER(curve2) / 2); IF curve2 < 2 THEN v2 := v2 + 10; END IF; END IF;
            v3 := 0; IF curve3 < 32 THEN v3 := 15 - (TO_INTEGER(curve3) / 2); IF curve3 < 2 THEN v3 := v3 + 10; END IF; END IF;
            v4 := 0; IF curve4 < 32 THEN v4 := 15 - (TO_INTEGER(curve4) / 2); IF curve4 < 2 THEN v4 := v4 + 10; END IF; END IF;
            v5 := 0; IF curve5 < 32 THEN v5 := 15 - (TO_INTEGER(curve5) / 2); IF curve5 < 2 THEN v5 := v5 + 10; END IF; END IF;
            
            -- Combine strands with their color mix
            v_r := v1 + v2 + (v2 / 4) + v3 - (v3 / 4) + v4 - (v4 / 4) + v5 + (v5 / 4);
            v_g := v1 + v2 - (v2 / 4) + v3 + (v3 / 4) + v4 + (v4 / 4) + v5 - (v5 / 4);
            v_b := v3 + v5;
            
            -- Final output bounds checking mapping
            IF v_r > 15 THEN r_out <= x"F"; ELSIF v_r < 0 THEN r_out <= x"0"; ELSE r_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(v_r, 4)); END IF;
            IF v_g > 15 THEN g_out <= x"F"; ELSIF v_g < 0 THEN g_out <= x"0"; ELSE g_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(v_g, 4)); END IF;
            IF v_b > 15 THEN b_out <= x"F"; ELSIF v_b < 0 THEN b_out <= x"0"; ELSE b_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(v_b, 4)); END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;