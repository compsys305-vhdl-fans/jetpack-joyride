LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE image_palette_pkg IS
    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
	CONSTANT IMAGE_PALETTE : rgb444_palette_t := (
		x"100",
		x"000",
		x"8EE",
		x"0FC",
		x"D6D",
		x"F7E",
		x"C56",
		x"B34",
	);
END PACKAGE image_palette_pkg;
