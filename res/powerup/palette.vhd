LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE powerup_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"000",
        x"0FC",
        x"100",
        x"8EE",
        x"B34",
        x"C56",
        x"D6D",
        x"F7E"
    );
END PACKAGE powerup_pkg;
