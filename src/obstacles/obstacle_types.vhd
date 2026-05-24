LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE obstacle_types IS
    CONSTANT MAX_LASERS : INTEGER := 8;
    CONSTANT SCREEN_WIDTH : INTEGER := 640;
    CONSTANT SCREEN_HEIGHT : INTEGER := 480;

    TYPE laser_t IS RECORD
        is_active : STD_LOGIC;
        x0 : UNSIGNED(9 DOWNTO 0);
        y0 : UNSIGNED(9 DOWNTO 0);
        x1 : UNSIGNED(9 DOWNTO 0);
        y1 : UNSIGNED(9 DOWNTO 0);
    END RECORD laser_t;

    TYPE laser_pool_t IS ARRAY (0 TO MAX_LASERS - 1) OF laser_t;

    -- Default value for an inactive laser
    CONSTANT INACTIVE_LASER : laser_t := (
        is_active => '0',
        x0        => (OTHERS => '0'),
        y0        => (OTHERS => '0'),
        x1        => (OTHERS => '0'),
        y1        => (OTHERS => '0')
    );
    
    -- Default value for a whole pool of inactive lasers
    CONSTANT INACTIVE_LASER_POOL : laser_pool_t := (OTHERS => INACTIVE_LASER);

END PACKAGE obstacle_types;
