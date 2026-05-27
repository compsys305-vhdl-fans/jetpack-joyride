LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE title_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"56D",
        x"69F",
        x"6CD",
        x"F53",
        x"F93",
        x"FB3",
        x"FE3"
    );
END PACKAGE title_palette_pkg;
