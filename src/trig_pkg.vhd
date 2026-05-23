--+
--+ File: trig_pkg.vhd
--+
--+ Created by: Gemini
--+
--+ Description:
--+ A basic fixed-point trigonometry library with sine and cosine functions.
--+ It uses a 64-entry quarter-wave lookup table for sine and calculates
--+ the other quadrants and cosine through symmetry.
--+
--+ The input angle is an 8-bit unsigned value (0-255), which maps to the
--+ full 360-degree circle. The output is an 8-bit signed value (-127 to 127).
--+------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE trig_pkg IS

    -- Angle is a byte [0-255] mapping to [0, 360) degrees
    -- Output is a signed byte
    FUNCTION sin (angle : UNSIGNED(7 DOWNTO 0)) RETURN SIGNED;
    FUNCTION cos (angle : UNSIGNED(7 DOWNTO 0)) RETURN SIGNED;

END PACKAGE trig_pkg;

PACKAGE BODY trig_pkg IS

    -- 64-entry Sine ROM for the first quadrant [0, 90) degrees
    -- Values are 8-bit signed with amplitude 127
    TYPE sine_rom_type IS ARRAY(0 TO 63) OF SIGNED(7 DOWNTO 0);
    CONSTANT SINE_Q1_ROM : sine_rom_type := (
        TO_SIGNED(0, 8), TO_SIGNED(3, 8), TO_SIGNED(6, 8), TO_SIGNED(9, 8),
        TO_SIGNED(12, 8), TO_SIGNED(16, 8), TO_SIGNED(19, 8), TO_SIGNED(22, 8),
        TO_SIGNED(25, 8), TO_SIGNED(28, 8), TO_SIGNED(31, 8), TO_SIGNED(34, 8),
        TO_SIGNED(37, 8), TO_SIGNED(40, 8), TO_SIGNED(43, 8), TO_SIGNED(46, 8),
        TO_SIGNED(49, 8), TO_SIGNED(51, 8), TO_SIGNED(54, 8), TO_SIGNED(57, 8),
        TO_SIGNED(60, 8), TO_SIGNED(63, 8), TO_SIGNED(65, 8), TO_SIGNED(68, 8),
        TO_SIGNED(71, 8), TO_SIGNED(73, 8), TO_SIGNED(76, 8), TO_SIGNED(78, 8),
        TO_SIGNED(81, 8), TO_SIGNED(83, 8), TO_SIGNED(85, 8), TO_SIGNED(88, 8),
        TO_SIGNED(90, 8), TO_SIGNED(92, 8), TO_SIGNED(94, 8), TO_SIGNED(96, 8),
        TO_SIGNED(98, 8), TO_SIGNED(100, 8), TO_SIGNED(102, 8), TO_SIGNED(104, 8),
        TO_SIGNED(106, 8), TO_SIGNED(107, 8), TO_SIGNED(109, 8), TO_SIGNED(111, 8),
        TO_SIGNED(112, 8), TO_SIGNED(113, 8), TO_SIGNED(115, 8), TO_SIGNED(116, 8),
        TO_SIGNED(117, 8), TO_SIGNED(118, 8), TO_SIGNED(120, 8), TO_SIGNED(121, 8),
        TO_SIGNED(122, 8), TO_SIGNED(122, 8), TO_SIGNED(123, 8), TO_SIGNED(124, 8),
        TO_SIGNED(125, 8), TO_SIGNED(125, 8), TO_SIGNED(126, 8), TO_SIGNED(126, 8),
        TO_SIGNED(126, 8), TO_SIGNED(127, 8), TO_SIGNED(127, 8), TO_SIGNED(127, 8)
    );

    FUNCTION sin (angle : UNSIGNED(7 DOWNTO 0)) RETURN SIGNED IS
        VARIABLE quadrant : UNSIGNED(1 DOWNTO 0);
        VARIABLE phase    : UNSIGNED(5 DOWNTO 0);
        VARIABLE result   : SIGNED(7 DOWNTO 0);
    BEGIN
        quadrant := angle(7 DOWNTO 6);
        phase    := angle(5 DOWNTO 0);

        CASE quadrant IS
            WHEN "00" => -- 0 to 90 degrees
                result := SINE_Q1_ROM(TO_INTEGER(phase));
            WHEN "01" => -- 90 to 180 degrees
                result := SINE_Q1_ROM(TO_INTEGER(NOT phase));
            WHEN "10" => -- 180 to 270 degrees
                result := -SINE_Q1_ROM(TO_INTEGER(phase));
            WHEN OTHERS => -- 270 to 360 degrees
                result := -SINE_Q1_ROM(TO_INTEGER(NOT phase));
        END CASE;
        RETURN result;
    END FUNCTION sin;

    FUNCTION cos (angle : UNSIGNED(7 DOWNTO 0)) RETURN SIGNED IS
    BEGIN
        -- Cosine is just sine with a 90-degree phase shift (64 in our 0-255 range)
        RETURN sin(angle + 64);
    END FUNCTION cos;

END PACKAGE BODY trig_pkg;
