LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

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

    -- 256-entry Sine ROM containing 8-bit signed values (amplitude 127)
    TYPE sine_rom_type IS ARRAY(0 TO 255) OF SIGNED(7 DOWNTO 0);
    CONSTANT SINE_ROM : sine_rom_type := (
        TO_SIGNED(0, 8), TO_SIGNED(3, 8), TO_SIGNED(6, 8), TO_SIGNED(9, 8), TO_SIGNED(12, 8), TO_SIGNED(16, 8), TO_SIGNED(19, 8), TO_SIGNED(22, 8),
        TO_SIGNED(25, 8), TO_SIGNED(28, 8), TO_SIGNED(31, 8), TO_SIGNED(34, 8), TO_SIGNED(37, 8), TO_SIGNED(40, 8), TO_SIGNED(43, 8), TO_SIGNED(46, 8),
        TO_SIGNED(49, 8), TO_SIGNED(51, 8), TO_SIGNED(54, 8), TO_SIGNED(57, 8), TO_SIGNED(60, 8), TO_SIGNED(63, 8), TO_SIGNED(65, 8), TO_SIGNED(68, 8),
        TO_SIGNED(71, 8), TO_SIGNED(73, 8), TO_SIGNED(76, 8), TO_SIGNED(78, 8), TO_SIGNED(81, 8), TO_SIGNED(83, 8), TO_SIGNED(85, 8), TO_SIGNED(88, 8),
        TO_SIGNED(90, 8), TO_SIGNED(92, 8), TO_SIGNED(94, 8), TO_SIGNED(96, 8), TO_SIGNED(98, 8), TO_SIGNED(100, 8), TO_SIGNED(102, 8), TO_SIGNED(104, 8),
        TO_SIGNED(106, 8), TO_SIGNED(107, 8), TO_SIGNED(109, 8), TO_SIGNED(111, 8), TO_SIGNED(112, 8), TO_SIGNED(113, 8), TO_SIGNED(115, 8), TO_SIGNED(116, 8),
        TO_SIGNED(117, 8), TO_SIGNED(118, 8), TO_SIGNED(120, 8), TO_SIGNED(121, 8), TO_SIGNED(122, 8), TO_SIGNED(122, 8), TO_SIGNED(123, 8), TO_SIGNED(124, 8),
        TO_SIGNED(125, 8), TO_SIGNED(125, 8), TO_SIGNED(126, 8), TO_SIGNED(126, 8), TO_SIGNED(126, 8), TO_SIGNED(127, 8), TO_SIGNED(127, 8), TO_SIGNED(127, 8),
        TO_SIGNED(127, 8), TO_SIGNED(127, 8), TO_SIGNED(127, 8), TO_SIGNED(127, 8), TO_SIGNED(126, 8), TO_SIGNED(126, 8), TO_SIGNED(126, 8), TO_SIGNED(125, 8),
        TO_SIGNED(125, 8), TO_SIGNED(124, 8), TO_SIGNED(123, 8), TO_SIGNED(122, 8), TO_SIGNED(122, 8), TO_SIGNED(121, 8), TO_SIGNED(120, 8), TO_SIGNED(118, 8),
        TO_SIGNED(117, 8), TO_SIGNED(116, 8), TO_SIGNED(115, 8), TO_SIGNED(113, 8), TO_SIGNED(112, 8), TO_SIGNED(111, 8), TO_SIGNED(109, 8), TO_SIGNED(107, 8),
        TO_SIGNED(106, 8), TO_SIGNED(104, 8), TO_SIGNED(102, 8), TO_SIGNED(100, 8), TO_SIGNED(98, 8), TO_SIGNED(96, 8), TO_SIGNED(94, 8), TO_SIGNED(92, 8),
        TO_SIGNED(90, 8), TO_SIGNED(88, 8), TO_SIGNED(85, 8), TO_SIGNED(83, 8), TO_SIGNED(81, 8), TO_SIGNED(78, 8), TO_SIGNED(76, 8), TO_SIGNED(73, 8),
        TO_SIGNED(71, 8), TO_SIGNED(68, 8), TO_SIGNED(65, 8), TO_SIGNED(63, 8), TO_SIGNED(60, 8), TO_SIGNED(57, 8), TO_SIGNED(54, 8), TO_SIGNED(51, 8),
        TO_SIGNED(49, 8), TO_SIGNED(46, 8), TO_SIGNED(43, 8), TO_SIGNED(40, 8), TO_SIGNED(37, 8), TO_SIGNED(34, 8), TO_SIGNED(31, 8), TO_SIGNED(28, 8),
        TO_SIGNED(25, 8), TO_SIGNED(22, 8), TO_SIGNED(19, 8), TO_SIGNED(16, 8), TO_SIGNED(12, 8), TO_SIGNED(9, 8), TO_SIGNED(6, 8), TO_SIGNED(3, 8),
        TO_SIGNED(0, 8), TO_SIGNED(-3, 8), TO_SIGNED(-6, 8), TO_SIGNED(-9, 8), TO_SIGNED(-12, 8), TO_SIGNED(-16, 8), TO_SIGNED(-19, 8), TO_SIGNED(-22, 8),
        TO_SIGNED(-25, 8), TO_SIGNED(-28, 8), TO_SIGNED(-31, 8), TO_SIGNED(-34, 8), TO_SIGNED(-37, 8), TO_SIGNED(-40, 8), TO_SIGNED(-43, 8), TO_SIGNED(-46, 8),
        TO_SIGNED(-49, 8), TO_SIGNED(-51, 8), TO_SIGNED(-54, 8), TO_SIGNED(-57, 8), TO_SIGNED(-60, 8), TO_SIGNED(-63, 8), TO_SIGNED(-65, 8), TO_SIGNED(-68, 8),
        TO_SIGNED(-71, 8), TO_SIGNED(-73, 8), TO_SIGNED(-76, 8), TO_SIGNED(-78, 8), TO_SIGNED(-81, 8), TO_SIGNED(-83, 8), TO_SIGNED(-85, 8), TO_SIGNED(-88, 8),
        TO_SIGNED(-90, 8), TO_SIGNED(-92, 8), TO_SIGNED(-94, 8), TO_SIGNED(-96, 8), TO_SIGNED(-98, 8), TO_SIGNED(-100, 8), TO_SIGNED(-102, 8), TO_SIGNED(-104, 8),
        TO_SIGNED(-106, 8), TO_SIGNED(-107, 8), TO_SIGNED(-109, 8), TO_SIGNED(-111, 8), TO_SIGNED(-112, 8), TO_SIGNED(-113, 8), TO_SIGNED(-115, 8), TO_SIGNED(-116, 8),
        TO_SIGNED(-117, 8), TO_SIGNED(-118, 8), TO_SIGNED(-120, 8), TO_SIGNED(-121, 8), TO_SIGNED(-122, 8), TO_SIGNED(-122, 8), TO_SIGNED(-123, 8), TO_SIGNED(-124, 8),
        TO_SIGNED(-125, 8), TO_SIGNED(-125, 8), TO_SIGNED(-126, 8), TO_SIGNED(-126, 8), TO_SIGNED(-126, 8), TO_SIGNED(-127, 8), TO_SIGNED(-127, 8), TO_SIGNED(-127, 8),
        TO_SIGNED(-127, 8), TO_SIGNED(-127, 8), TO_SIGNED(-127, 8), TO_SIGNED(-127, 8), TO_SIGNED(-126, 8), TO_SIGNED(-126, 8), TO_SIGNED(-126, 8), TO_SIGNED(-125, 8),
        TO_SIGNED(-125, 8), TO_SIGNED(-124, 8), TO_SIGNED(-123, 8), TO_SIGNED(-122, 8), TO_SIGNED(-122, 8), TO_SIGNED(-121, 8), TO_SIGNED(-120, 8), TO_SIGNED(-118, 8),
        TO_SIGNED(-117, 8), TO_SIGNED(-116, 8), TO_SIGNED(-115, 8), TO_SIGNED(-113, 8), TO_SIGNED(-112, 8), TO_SIGNED(-111, 8), TO_SIGNED(-109, 8), TO_SIGNED(-107, 8),
        TO_SIGNED(-106, 8), TO_SIGNED(-104, 8), TO_SIGNED(-102, 8), TO_SIGNED(-100, 8), TO_SIGNED(-98, 8), TO_SIGNED(-96, 8), TO_SIGNED(-94, 8), TO_SIGNED(-92, 8),
        TO_SIGNED(-90, 8), TO_SIGNED(-88, 8), TO_SIGNED(-85, 8), TO_SIGNED(-83, 8), TO_SIGNED(-81, 8), TO_SIGNED(-78, 8), TO_SIGNED(-76, 8), TO_SIGNED(-73, 8),
        TO_SIGNED(-71, 8), TO_SIGNED(-68, 8), TO_SIGNED(-65, 8), TO_SIGNED(-63, 8), TO_SIGNED(-60, 8), TO_SIGNED(-57, 8), TO_SIGNED(-54, 8), TO_SIGNED(-51, 8),
        TO_SIGNED(-49, 8), TO_SIGNED(-46, 8), TO_SIGNED(-43, 8), TO_SIGNED(-40, 8), TO_SIGNED(-37, 8), TO_SIGNED(-34, 8), TO_SIGNED(-31, 8), TO_SIGNED(-28, 8),
        TO_SIGNED(-25, 8), TO_SIGNED(-22, 8), TO_SIGNED(-19, 8), TO_SIGNED(-16, 8), TO_SIGNED(-12, 8), TO_SIGNED(-9, 8), TO_SIGNED(-6, 8), TO_SIGNED(-3, 8)
    );

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
            sin1 <= SINE_ROM(TO_INTEGER(phase1));
            sin2 <= SINE_ROM(TO_INTEGER(phase2));
            sin3 <= SINE_ROM(TO_INTEGER(phase3));
            sin4 <= SINE_ROM(TO_INTEGER(phase4));
            sin5 <= SINE_ROM(TO_INTEGER(phase5));
            
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