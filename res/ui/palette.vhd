LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE ui_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"000",
        x"100",
        x"69F",
        x"9D5",
        x"C7A",
        x"E55",
        x"E96",
        x"FE3"
    );
END PACKAGE ui_palette_pkg;
