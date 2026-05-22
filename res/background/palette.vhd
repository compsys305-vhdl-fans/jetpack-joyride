LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE image_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"878",
        x"000",
        x"9AB",
        x"455",
        x"334",
        x"C44",
        x"F44"
    );
END PACKAGE image_palette_pkg;
