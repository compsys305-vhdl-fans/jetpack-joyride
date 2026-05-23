LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE lil_stomper_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"633",
        x"A54",
        x"BBA",
        x"E54",
        x"EB9",
        x"FFF"
    );
END PACKAGE lil_stomper_palette_pkg;
