LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE golden_skull_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"233",
        x"344",
        x"441",
        x"552",
        x"AA4",
        x"CC6",
        x"FFF"
    );
END PACKAGE golden_skull_palette_pkg;
