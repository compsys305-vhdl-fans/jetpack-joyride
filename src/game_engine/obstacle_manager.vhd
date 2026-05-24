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
        lasers_out       : OUT laser_pool_t
    );
END ENTITY obstacle_manager;

ARCHITECTURE rtl OF obstacle_manager IS
    CONSTANT LASER_SPEED_X : INTEGER := 4; -- pixels per frame
    CONSTANT LASER_LENGTH : INTEGER := 100;
    CONSTANT SPAWN_INTERVAL_MIN : INTEGER := 60; -- frames (1 second)
    CONSTANT SPAWN_INTERVAL_VARIATION : INTEGER := 60; -- frames (1 second)
    CONSTANT Y_MARGIN : INTEGER := 40; -- Top/bottom margin for laser spawns

    SIGNAL pool : laser_pool_t := INACTIVE_LASER_POOL;
    SIGNAL spawn_counter : INTEGER RANGE 0 TO SPAWN_INTERVAL_MIN + SPAWN_INTERVAL_VARIATION := SPAWN_INTERVAL_MIN;
    SIGNAL next_spawn_interval : INTEGER RANGE 0 TO SPAWN_INTERVAL_MIN + SPAWN_INTERVAL_VARIATION := SPAWN_INTERVAL_MIN;
BEGIN

    lasers_out <= pool;

    manager_proc: PROCESS(vert_sync, reset, playing)
        VARIABLE temp_pool : laser_pool_t;
        VARIABLE new_spawn : BOOLEAN := FALSE;
        VARIABLE rand_y : UNSIGNED(9 DOWNTO 0);
        VARIABLE current_spawn_counter: INTEGER RANGE 0 TO SPAWN_INTERVAL_MIN + SPAWN_INTERVAL_VARIATION;
        VARIABLE current_next_spawn_interval: INTEGER RANGE 0 TO SPAWN_INTERVAL_MIN + SPAWN_INTERVAL_VARIATION;

    BEGIN
        current_spawn_counter := spawn_counter;
        current_next_spawn_interval := next_spawn_interval;
        temp_pool := pool;
        
        IF RISING_EDGE(vert_sync) THEN
            IF reset = '1' THEN
                temp_pool := INACTIVE_LASER_POOL;
                current_spawn_counter := SPAWN_INTERVAL_MIN;
            ELSIF playing = '1' THEN
                new_spawn := FALSE;

                -- Update existing lasers
                FOR i IN 0 TO MAX_LASERS - 1 LOOP
                    IF temp_pool(i).is_active = '1' THEN
                        IF TO_INTEGER(temp_pool(i).x1) < 0 THEN
                            -- Deactivate if off-screen
                            temp_pool(i) := INACTIVE_LASER;
                        ELSE
                            -- Move left
                            temp_pool(i).x0 := temp_pool(i).x0 - LASER_SPEED_X;
                            temp_pool(i).x1 := temp_pool(i).x1 - LASER_SPEED_X;
                        END IF;
                    END IF;
                END LOOP;

                -- Check for spawning new laser
                IF current_spawn_counter = 0 THEN
                    new_spawn := TRUE;
                    current_next_spawn_interval := SPAWN_INTERVAL_MIN + (TO_INTEGER(UNSIGNED(random_in(3 DOWNTO 0))) * SPAWN_INTERVAL_VARIATION / 15);
                    current_spawn_counter := current_next_spawn_interval;
                ELSE
                    current_spawn_counter := current_spawn_counter - 1;
                END IF;

                -- Find an inactive slot to spawn a new laser
                IF new_spawn THEN
                    FOR i IN 0 TO MAX_LASERS - 1 LOOP
                        IF temp_pool(i).is_active = '0' THEN
                            temp_pool(i).is_active := '1';

                            -- Use 2 bits to determine laser type
                            CASE random_in(15 DOWNTO 14) IS
                                -- Horizontal laser
                                WHEN "00" =>
                                    rand_y := RESIZE(UNSIGNED(random_in(9 DOWNTO 0)), 10);
                                    IF rand_y > SCREEN_HEIGHT - Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(SCREEN_HEIGHT - Y_MARGIN, 10);
                                    ELSIF rand_y < Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(Y_MARGIN, 10);
                                    END IF;
                                    temp_pool(i).y0 := RESIZE(SIGNED('0' & rand_y), 12);
                                    temp_pool(i).y1 := temp_pool(i).y0;

                                    temp_pool(i).x0 := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                                    temp_pool(i).x1 := TO_SIGNED(SCREEN_WIDTH - 1 + LASER_LENGTH, 12);
                                
                                -- Vertical laser
                                WHEN "01" =>
                                    rand_y := RESIZE(UNSIGNED(random_in(9 DOWNTO 0)), 10);
                                    IF rand_y > SCREEN_HEIGHT - LASER_LENGTH - Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(SCREEN_HEIGHT - LASER_LENGTH - Y_MARGIN, 10);
                                    ELSIF rand_y < Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(Y_MARGIN, 10);
                                    END IF;
                                    temp_pool(i).y0 := RESIZE(SIGNED('0' & rand_y), 12);
                                    temp_pool(i).y1 := temp_pool(i).y0 + LASER_LENGTH;

                                    temp_pool(i).x0 := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                                    temp_pool(i).x1 := TO_SIGNED(SCREEN_WIDTH - 1, 12);

                                -- Diagonal (down-right)
                                WHEN "10" =>
                                    rand_y := RESIZE(UNSIGNED(random_in(9 DOWNTO 0)), 10);
                                    IF rand_y > SCREEN_HEIGHT - LASER_LENGTH - Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(SCREEN_HEIGHT - LASER_LENGTH - Y_MARGIN, 10);
                                    ELSIF rand_y < Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(Y_MARGIN, 10);
                                    END IF;
                                    temp_pool(i).y0 := RESIZE(SIGNED('0' & rand_y), 12);
                                    temp_pool(i).y1 := temp_pool(i).y0 + LASER_LENGTH;

                                    temp_pool(i).x0 := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                                    temp_pool(i).x1 := TO_SIGNED(SCREEN_WIDTH - 1 + LASER_LENGTH, 12);

                                -- Diagonal (up-right)
                                WHEN OTHERS =>
                                    rand_y := RESIZE(UNSIGNED(random_in(9 DOWNTO 0)), 10);
                                    IF rand_y < LASER_LENGTH + Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(LASER_LENGTH + Y_MARGIN, 10);
                                    ELSIF rand_y > SCREEN_HEIGHT - Y_MARGIN THEN
                                        rand_y := TO_UNSIGNED(SCREEN_HEIGHT - Y_MARGIN, 10);
                                    END IF;
                                    temp_pool(i).y0 := RESIZE(SIGNED('0' & rand_y), 12);
                                    temp_pool(i).y1 := temp_pool(i).y0 - LASER_LENGTH;
                                    
                                    temp_pool(i).x0 := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                                    temp_pool(i).x1 := TO_SIGNED(SCREEN_WIDTH - 1 + LASER_LENGTH, 12);
                            END CASE;

                            EXIT; -- exit loop after spawning one
                        END IF;
                    END LOOP;
                END IF;

            END IF;
            pool <= temp_pool;
            spawn_counter <= current_spawn_counter;
            next_spawn_interval <= current_next_spawn_interval;
        END IF;
    END PROCESS manager_proc;

END ARCHITECTURE rtl;
