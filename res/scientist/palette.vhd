LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE scientist_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"000",
        x"100",
        x"89F",
        x"AA9",
        x"AAF",
        x"DDA",
        x"DDF",
        x"FFD"
    );
END PACKAGE scientist_palette_pkg;
