LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE spin_token_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"100",
        x"554",
        x"786",
        x"AA9",
        x"AB8",
        x"CB4",
        x"DD8",
        x"EE5"
    );
END PACKAGE spin_token_palette_pkg;
