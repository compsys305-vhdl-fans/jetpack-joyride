LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE bird_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"633",
        x"A33",
        x"A53",
        x"AAF",
        x"C74",
        x"EB9",
        x"FFF"
    );
END PACKAGE bird_palette_pkg;
