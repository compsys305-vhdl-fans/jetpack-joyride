LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.obstacle_types.ALL;

ENTITY obstacle_manager IS
    PORT (
        clock_50MHz      : IN STD_LOGIC;
        vert_sync        : IN STD_LOGIC;
        reset            : IN STD_LOGIC;
        playing          : IN STD_LOGIC;
        random_in        : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        player_y         : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        world_speed      : IN UNSIGNED(9 DOWNTO 0);
        lasers_out       : OUT laser_pool_t;
        missiles_out     : OUT missile_pool_t;
        coins_out        : OUT coin_pool_t
    );
END ENTITY obstacle_manager;

ARCHITECTURE rtl OF obstacle_manager IS
    -- Internal signals to hold the state of obstacles
    SIGNAL missile_pool_s : missile_pool_t := INACTIVE_MISSILE_POOL;
    SIGNAL laser_pool_s   : laser_pool_t := INACTIVE_LASER_POOL;
    SIGNAL coin_pool_s    : coin_pool_t := INACTIVE_COIN_POOL;

    -- Timer to control missile spawning frequency
    SIGNAL missile_spawn_timer : INTEGER RANGE 0 TO 500 := 200;

BEGIN

    -- Main process to manage all obstacles
    PROCESS(clock_50MHz, reset)
        -- Variables for calculations
        VARIABLE missile_y_s : SIGNED(10 DOWNTO 0);
        VARIABLE player_y_s  : SIGNED(10 DOWNTO 0);
        VARIABLE diff_y      : SIGNED(10 DOWNTO 0);
    BEGIN
        IF reset = '1' THEN
            -- Reset all obstacles to their initial, inactive state
            missile_pool_s      <= INACTIVE_MISSILE_POOL;
            laser_pool_s        <= INACTIVE_LASER_POOL;
            coin_pool_s         <= INACTIVE_COIN_POOL;
            missile_spawn_timer <= 200;

        ELSIF RISING_EDGE(clock_50MHz) THEN
            IF vert_sync = '1' THEN
                IF playing = '1' THEN
                    -- ==================================================
                    -- == MISSILE LOGIC
                    -- ==================================================

                    -- If the missile is not currently active or in a warning state
                    IF missile_pool_s(0).is_active = '0' AND missile_pool_s(0).is_warning = '0' THEN
                        -- Decrement spawn timer until it's time to spawn a new one
                        IF missile_spawn_timer > 0 THEN
                            missile_spawn_timer <= missile_spawn_timer - 1;
                        ELSE
                            -- 1. SPAWN AT PLAYER Y
                            missile_pool_s(0).is_warning <= '1';
                            missile_pool_s(0).y          <= UNSIGNED(player_y);
                            missile_pool_s(0).x          <= TO_UNSIGNED(620, 10); -- Spawn just off-screen to the right
                            
                            -- 2. LESS WARNING TIME (30 frames = 0.5s at 60Hz)
                            missile_pool_s(0).warning_timer <= 30;

                            -- Reset the spawn timer for the next missile
                            missile_spawn_timer <= 180 + TO_INTEGER(UNSIGNED(random_in(7 DOWNTO 0))); -- 3 to 7 seconds
                        END IF;
                    END IF;

                    -- If missile is in its warning phase
                    IF missile_pool_s(0).is_warning = '1' THEN
                        IF missile_pool_s(0).warning_timer > 0 THEN
                            -- 3. SLOWLY FOLLOW PLAYER Y (LINEAR INTERPOLATION)
                            -- Convert missile and player Y to signed for subtraction
                            missile_y_s := RESIZE(SIGNED(missile_pool_s(0).y), 11);
                            player_y_s  := RESIZE(SIGNED(UNSIGNED(player_y)), 11);
                            
                            -- Calculate the difference and move the missile 1/4 of the way to the player
                            diff_y      := player_y_s - missile_y_s;
                            missile_y_s := missile_y_s + SHIFT_RIGHT(diff_y, 2);

                            -- Update the missile's Y position
                            missile_pool_s(0).y <= RESIZE(UNSIGNED(missile_y_s), 10);

                            -- Decrement the warning timer
                            missile_pool_s(0).warning_timer <= missile_pool_s(0).warning_timer - 1;
                        ELSE
                            -- Warning time is over, launch the missile
                            missile_pool_s(0).is_warning <= '0';
                            missile_pool_s(0).is_active  <= '1';
                        END IF;
                    
                    -- If missile is active (flying across the screen)
                    ELSIF missile_pool_s(0).is_active = '1' THEN
                        -- Move missile left. It moves faster than the world scroll speed.
                        missile_pool_s(0).x <= missile_pool_s(0).x - RESIZE(world_speed, 10) - 5;

                        -- Deactivate missile if it goes off-screen
                        IF missile_pool_s(0).x > 1000 THEN -- Wraps around from negative
                            missile_pool_s(0).is_active <= '0';
                        END IF;
                    END IF;

                    -- ==================================================
                    -- == LASER & COIN LOGIC (PLACEHOLDER)
                    -- ==================================================
                    -- TODO: Add logic for managing lasers and coins here

                ELSE -- Not playing
                    -- If not in the 'playing' state, reset all obstacles
                    missile_pool_s      <= INACTIVE_MISSILE_POOL;
                    laser_pool_s        <= INACTIVE_LASER_POOL;
                    coin_pool_s         <= INACTIVE_COIN_POOL;
                    missile_spawn_timer <= 200;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Connect internal signals to the output ports
    missiles_out <= missile_pool_s;
    lasers_out   <= laser_pool_s;
    coins_out    <= coin_pool_s;

END ARCHITECTURE rtl;
