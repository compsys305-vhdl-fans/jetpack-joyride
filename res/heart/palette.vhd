LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE heart_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"A33",
        x"C45",
        x"D56",
        x"E78",
        x"FAA"
    );
END PACKAGE heart_palette_pkg;
