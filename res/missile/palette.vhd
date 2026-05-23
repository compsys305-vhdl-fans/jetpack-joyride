LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE missile_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"424",
        x"666",
        x"9AB",
        x"A33",
        x"BBB",
        x"D56",
        x"D72"
    );
END PACKAGE missile_palette_pkg;
