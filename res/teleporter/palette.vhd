LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE teleporter1_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"635",
        x"859",
        x"957",
        x"978",
        x"DAA",
        x"EB7",
        x"EBD"
    );
END PACKAGE teleporter1_pkg;
