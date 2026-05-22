LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE image_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"635",
        x"978",
        x"EBD",
        x"859",
        x"EB7",
        x"957",
        x"DAA"
    );
END PACKAGE image_palette_pkg;
