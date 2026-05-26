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
        random_in        : IN STD_LOGIC_VECTOR(19 DOWNTO 0); -- Using the existing 20-bit LFSR
        world_speed      : IN UNSIGNED(9 DOWNTO 0);
        lasers_out       : OUT laser_pool_t
    );
END ENTITY obstacle_manager;

ARCHITECTURE rtl OF obstacle_manager IS
    CONSTANT BASE_LASER_SPEED_X : INTEGER := 4; -- pixels per frame
    CONSTANT LASER_LENGTH : INTEGER := 100;
    CONSTANT Y_MARGIN : INTEGER := 80; -- Top/bottom margin for laser spawns
    CONSTANT MIN_LASER_DISTANCE : INTEGER := 32; -- Minimum vertical distance between horizontal lasers

    -- Spawning rate constants
    CONSTANT INITIAL_SPAWN_INTERVAL : INTEGER := 180; -- 3 seconds
    CONSTANT MIN_SPAWN_INTERVAL : INTEGER := 60; -- 1 second
    CONSTANT SPAWN_INTERVAL_DECREMENT : INTEGER := 10; -- frames
    CONSTANT RAMP_UP_PERIOD : INTEGER := 600; -- 10 seconds

    SIGNAL pool : laser_pool_t := INACTIVE_LASER_POOL;
    SIGNAL playing_prev : STD_LOGIC := '0';
    
    SIGNAL spawn_counter : INTEGER RANGE 0 TO INITIAL_SPAWN_INTERVAL * 2 := INITIAL_SPAWN_INTERVAL;
    SIGNAL next_spawn_interval : INTEGER RANGE 0 TO INITIAL_SPAWN_INTERVAL * 2 := INITIAL_SPAWN_INTERVAL;
    SIGNAL dynamic_spawn_interval : INTEGER RANGE MIN_SPAWN_INTERVAL TO INITIAL_SPAWN_INTERVAL := INITIAL_SPAWN_INTERVAL;
    SIGNAL ramp_up_counter : INTEGER RANGE 0 TO RAMP_UP_PERIOD := RAMP_UP_PERIOD;

BEGIN

    lasers_out <= pool;

    manager_proc: PROCESS(vert_sync)
        VARIABLE temp_pool : laser_pool_t;
        VARIABLE new_spawn : BOOLEAN := FALSE;
        VARIABLE rand_y : UNSIGNED(9 DOWNTO 0);
        VARIABLE speed_x : INTEGER;
        VARIABLE safe_to_spawn : BOOLEAN;
        VARIABLE is_horizontal : BOOLEAN;
    BEGIN
        temp_pool := pool;
        
        IF RISING_EDGE(vert_sync) THEN
            IF reset = '1' THEN
                temp_pool := INACTIVE_LASER_POOL;
                spawn_counter <= INITIAL_SPAWN_INTERVAL;
                dynamic_spawn_interval <= INITIAL_SPAWN_INTERVAL;
                ramp_up_counter <= RAMP_UP_PERIOD;
            ELSIF playing = '1' THEN
                -- Ramp up spawn rate
                IF ramp_up_counter = 0 THEN
                    IF dynamic_spawn_interval > MIN_SPAWN_INTERVAL THEN
                        dynamic_spawn_interval <= dynamic_spawn_interval - SPAWN_INTERVAL_DECREMENT;
                    END IF;
                    ramp_up_counter <= RAMP_UP_PERIOD;
                ELSE
                    ramp_up_counter <= ramp_up_counter - 1;
                END IF;

                speed_x := TO_INTEGER(world_speed);
                IF speed_x < 1 THEN
                    speed_x := BASE_LASER_SPEED_X;
                END IF;
                new_spawn := FALSE;

                -- Update existing lasers
                FOR i IN 0 TO MAX_LASERS - 1 LOOP
                    IF temp_pool(i).is_active = '1' THEN
                        IF TO_INTEGER(temp_pool(i).x1) < 0 THEN
                            -- Deactivate if off-screen
                            temp_pool(i) := INACTIVE_LASER;
                        ELSE
                            -- Move left
                            temp_pool(i).x0 := temp_pool(i).x0 - speed_x;
                            temp_pool(i).x1 := temp_pool(i).x1 - speed_x;
                        END IF;
                    END IF;
                END LOOP;

                -- Check for spawning new laser
                IF spawn_counter = 0 THEN
                    new_spawn := TRUE;
                    next_spawn_interval <= dynamic_spawn_interval + TO_INTEGER(UNSIGNED(random_in(3 DOWNTO 0)));
                    spawn_counter <= next_spawn_interval;
                ELSE
                    spawn_counter <= spawn_counter - 1;
                END IF;

                -- Find an inactive slot to spawn a new laser
                IF new_spawn THEN
                    FOR i IN 0 TO MAX_LASERS - 1 LOOP
                        IF temp_pool(i).is_active = '0' THEN
                            
                            -- Generate a candidate new laser
                            is_horizontal := FALSE;
                            CASE random_in(15 DOWNTO 14) IS
                                WHEN "00" | "10" => is_horizontal := TRUE;
                                WHEN OTHERS => is_horizontal := FALSE;
                            END CASE;

                            rand_y := RESIZE(UNSIGNED(random_in(9 DOWNTO 0)), 10);
                            IF is_horizontal THEN
                                IF rand_y > SCREEN_HEIGHT - Y_MARGIN THEN
                                    rand_y := TO_UNSIGNED(SCREEN_HEIGHT - Y_MARGIN, 10);
                                ELSIF rand_y < Y_MARGIN THEN
                                    rand_y := TO_UNSIGNED(Y_MARGIN, 10);
                                END IF;
                            ELSE
                                IF rand_y > SCREEN_HEIGHT - LASER_LENGTH - Y_MARGIN THEN
                                    rand_y := TO_UNSIGNED(SCREEN_HEIGHT - LASER_LENGTH - Y_MARGIN, 10);
                                ELSIF rand_y < Y_MARGIN THEN
                                    rand_y := TO_UNSIGNED(Y_MARGIN, 10);
                                END IF;
                            END IF;

                            safe_to_spawn := true;
                            -- Check if it collides with existing lasers
                            IF is_horizontal THEN
                                FOR j IN 0 TO MAX_LASERS - 1 LOOP
                                    IF i /= j AND temp_pool(j).is_active = '1' AND temp_pool(j).y0 = temp_pool(j).y1 THEN
                                        IF ABS(TO_INTEGER(SIGNED(rand_y)) - TO_INTEGER(temp_pool(j).y0)) < MIN_LASER_DISTANCE THEN
                                            safe_to_spawn := false;
                                        END IF;
                                    END IF;
                                END LOOP;
                            END IF;
                            
                            IF safe_to_spawn THEN
                                temp_pool(i).is_active := '1';
                                IF is_horizontal THEN
                                    temp_pool(i).y0 := RESIZE(SIGNED('0' & rand_y), 12);
                                    temp_pool(i).y1 := temp_pool(i).y0;
                                    temp_pool(i).x0 := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                                    temp_pool(i).x1 := TO_SIGNED(SCREEN_WIDTH - 1 + LASER_LENGTH, 12);
                                ELSE
                                    temp_pool(i).y0 := RESIZE(SIGNED('0' & rand_y), 12);
                                    temp_pool(i).y1 := temp_pool(i).y0 + LASER_LENGTH;
                                    temp_pool(i).x0 := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                                    temp_pool(i).x1 := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                                END IF;
                                EXIT; -- exit loop after spawning one
                            END IF;
                        END IF;
                    END LOOP;
                END IF;
            ELSE
                temp_pool := INACTIVE_LASER_POOL;
            END IF;
            pool <= temp_pool;
            playing_prev <= playing;
        END IF;
    END PROCESS manager_proc;

END ARCHITECTURE rtl;
