LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE image_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"A33",
        x"D56",
        x"9AB",
        x"BBB",
        x"D72",
        x"424",
        x"666"
    );
END PACKAGE image_palette_pkg;
