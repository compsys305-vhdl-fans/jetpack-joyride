LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE run1_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"000",
        x"100",
        x"447",
        x"633",
        x"666",
        x"EB9",
        x"FE3",
        x"FFF"
    );
END PACKAGE run1_pkg;
