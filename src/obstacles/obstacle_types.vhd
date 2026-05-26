LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE obstacle_types IS
    CONSTANT MAX_LASERS : INTEGER := 8;
    CONSTANT MAX_MISSILES : INTEGER := 1;
    CONSTANT MAX_COINS : INTEGER := 6;
    CONSTANT MAX_POWERUPS : INTEGER := 1;
    CONSTANT SCREEN_WIDTH : INTEGER := 640;
    CONSTANT SCREEN_HEIGHT : INTEGER := 480;

    TYPE laser_t IS RECORD
        is_active : STD_LOGIC;
        x0 : SIGNED(11 DOWNTO 0);
        y0 : SIGNED(11 DOWNTO 0);
        x1 : SIGNED(11 DOWNTO 0);
        y1 : SIGNED(11 DOWNTO 0);
    END RECORD laser_t;

    TYPE laser_pool_t IS ARRAY (0 TO MAX_LASERS - 1) OF laser_t;

    TYPE missile_t IS RECORD
        is_active : STD_LOGIC;
        is_warning : STD_LOGIC;
        x : SIGNED(11 DOWNTO 0);
        y : SIGNED(11 DOWNTO 0);
    END RECORD missile_t;

    TYPE missile_pool_t IS ARRAY (0 TO MAX_MISSILES - 1) OF missile_t;

    TYPE coin_t IS RECORD
        is_active : STD_LOGIC;
        x : SIGNED(11 DOWNTO 0);
        y : SIGNED(11 DOWNTO 0);
    END RECORD coin_t;

    TYPE coin_pool_t IS ARRAY (0 TO MAX_COINS - 1) OF coin_t;

    TYPE powerup_t IS RECORD
        is_active : STD_LOGIC;
        x : SIGNED(11 DOWNTO 0);
        y : SIGNED(11 DOWNTO 0);
    END RECORD powerup_t;

    TYPE powerup_pool_t IS ARRAY (0 TO MAX_POWERUPS - 1) OF powerup_t;

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

    CONSTANT INACTIVE_MISSILE : missile_t := (
        is_active => '0',
        is_warning => '0',
        x => (OTHERS => '0'),
        y => (OTHERS => '0')
    );

    CONSTANT INACTIVE_MISSILE_POOL : missile_pool_t := (OTHERS => INACTIVE_MISSILE);

    CONSTANT INACTIVE_COIN : coin_t := (
        is_active => '0',
        x => (OTHERS => '0'),
        y => (OTHERS => '0')
    );

    CONSTANT INACTIVE_COIN_POOL : coin_pool_t := (OTHERS => INACTIVE_COIN);

    CONSTANT INACTIVE_POWERUP : powerup_t := (
        is_active => '0',
        x => (OTHERS => '0'),
        y => (OTHERS => '0')
    );

    CONSTANT INACTIVE_POWERUP_POOL : powerup_pool_t := (OTHERS => INACTIVE_POWERUP);

END PACKAGE obstacle_types;
