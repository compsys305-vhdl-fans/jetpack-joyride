LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE coin_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"633",
        x"853",
        x"EC4",
        x"EE4",
        x"FE9",
        x"FFF"
    );
END PACKAGE coin_palette_pkg;
