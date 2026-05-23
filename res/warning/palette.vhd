LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE warning_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
        x"000",
        x"100",
        x"424",
        x"D56",
        x"FE3",
        x"FF7"
    );
END PACKAGE warning_palette_pkg;
