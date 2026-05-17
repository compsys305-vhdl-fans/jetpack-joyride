LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY top_jetpack_joyride IS
    PORT (
        clock_50 : IN STD_LOGIC;

        key : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        sw : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

        ledr : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        hex0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex3 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex4 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex5 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);

        vga_r : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        vga_g : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        vga_b : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        vga_hsync : OUT STD_LOGIC;
        vga_vsync : OUT STD_LOGIC
    );
END ENTITY top_jetpack_joyride;

ARCHITECTURE port_map OF top_jetpack_joyride IS
    -- here we would declare components
BEGIN
    -- placeholder; we should have port maps and stuff, but ideally no logic here (apart from logic inversion for active-low buttons and stuff)
END ARCHITECTURE port_map;
