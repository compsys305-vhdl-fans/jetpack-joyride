LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.obstacle_types.ALL;

ENTITY obstacle_manager IS
    PORT (
        vert_sync        : IN STD_LOGIC;
        reset            : IN STD_LOGIC;
        playing          : IN STD_LOGIC;
        random_in        : IN STD_LOGIC_VECTOR(19 DOWNTO 0); -- Using the existing 20-bit LFSR
        world_speed      : IN UNSIGNED(9 DOWNTO 0);
        lasers_out       : OUT laser_pool_t;
        missiles_out     : OUT missile_pool_t;
        coins_out        : OUT coin_pool_t
    );
END ENTITY obstacle_manager;

ARCHITECTURE rtl OF obstacle_manager IS
    CONSTANT BASE_LASER_SPEED_X : INTEGER := 4; -- pixels per frame
    CONSTANT LASER_LENGTH : INTEGER := 100;
    CONSTANT Y_MARGIN : INTEGER := 40; -- Top/bottom margin for laser spawns
    CONSTANT MIN_LASER_DISTANCE : INTEGER := 32; -- Minimum vertical distance between horizontal lasers

    CONSTANT MISSILE_WIDTH : INTEGER := 16;
    CONSTANT MISSILE_HEIGHT : INTEGER := 16;
    CONSTANT MISSILE_DISPLAY_WIDTH : INTEGER := MISSILE_WIDTH * 2;
    CONSTANT MISSILE_OFFSET : INTEGER := 16;
    CONSTANT MISSILE_DISPLAY_HEIGHT : INTEGER := MISSILE_HEIGHT * 2;

    CONSTANT MISSILE_WARNING_DURATION : INTEGER := 180; -- frames (~3s at 60Hz)
    CONSTANT MISSILE_SPAWN_INTERVAL : INTEGER := 240; -- frames (~4s at 60Hz)
    CONSTANT MISSILE_SPAWN_JITTER : INTEGER := 120;
    CONSTANT BASE_MISSILE_SPEED_X : INTEGER := 8; -- fallback if world speed is 0

    CONSTANT COIN_WIDTH : INTEGER := 16;
    CONSTANT COIN_HEIGHT : INTEGER := 16;
    CONSTANT COIN_DISPLAY_WIDTH : INTEGER := COIN_WIDTH * 2;
    CONSTANT COIN_DISPLAY_HEIGHT : INTEGER := COIN_HEIGHT * 2;

    CONSTANT COIN_SPAWN_INTERVAL : INTEGER := 60; -- frames (~1s at 60Hz)
    CONSTANT COIN_SPAWN_JITTER : INTEGER := 60;
    CONSTANT BASE_COIN_SPEED_X : INTEGER := 4;

    -- Spawning rate constants
    CONSTANT INITIAL_SPAWN_INTERVAL : INTEGER := 90; -- 1.5 seconds
    CONSTANT MIN_SPAWN_INTERVAL : INTEGER := 30; -- 0.5 seconds
    CONSTANT SPAWN_INTERVAL_DECREMENT : INTEGER := 10;
    CONSTANT SPAWN_RAMP_RATE : INTEGER := 60; -- Time in frames to wait before decrementing spawn interval

    SIGNAL pool : laser_pool_t := INACTIVE_LASER_POOL;
    SIGNAL missiles : missile_pool_t := INACTIVE_MISSILE_POOL;
    SIGNAL coins : coin_pool_t := INACTIVE_COIN_POOL;
    SIGNAL playing_prev : STD_LOGIC := '0';
    
    SIGNAL spawn_counter : INTEGER RANGE 0 TO INITIAL_SPAWN_INTERVAL * 2;
    SIGNAL dynamic_spawn_interval : INTEGER RANGE MIN_SPAWN_INTERVAL TO INITIAL_SPAWN_INTERVAL := INITIAL_SPAWN_INTERVAL;
    SIGNAL ramp_up_counter : INTEGER RANGE 0 TO SPAWN_RAMP_RATE := SPAWN_RAMP_RATE;

    SIGNAL missile_spawn_counter : INTEGER RANGE 0 TO MISSILE_SPAWN_INTERVAL + MISSILE_SPAWN_JITTER := MISSILE_SPAWN_INTERVAL;
    SIGNAL warning_timer : INTEGER RANGE 0 TO MISSILE_WARNING_DURATION := 0;

    SIGNAL coin_spawn_counter : INTEGER RANGE 0 TO COIN_SPAWN_INTERVAL + COIN_SPAWN_JITTER := COIN_SPAWN_INTERVAL;

BEGIN

    lasers_out <= pool;
    missiles_out <= missiles;
    coins_out <= coins;

    manager_proc: PROCESS(vert_sync)
        VARIABLE temp_pool : laser_pool_t;
        VARIABLE rand_y : UNSIGNED(9 DOWNTO 0);
        VARIABLE speed_x : INTEGER;
        VARIABLE safe_to_spawn : BOOLEAN;
        VARIABLE is_horizontal : BOOLEAN;
        VARIABLE temp_missiles : missile_pool_t;
        VARIABLE missile_speed_x : INTEGER;
        VARIABLE rand_missile_y : INTEGER;
        VARIABLE jitter : INTEGER;
        VARIABLE temp_coins : coin_pool_t;
        VARIABLE coin_speed_x : INTEGER;
        VARIABLE rand_coin_y : INTEGER;
        VARIABLE jitter_coin : INTEGER;
        VARIABLE coin_spawned : BOOLEAN;
    BEGIN
        temp_pool := pool;
        temp_missiles := missiles;
        temp_coins := coins;
        
        IF RISING_EDGE(vert_sync) THEN
            IF reset = '1' THEN
                temp_pool := INACTIVE_LASER_POOL;
                temp_missiles := INACTIVE_MISSILE_POOL;
                temp_coins := INACTIVE_COIN_POOL;
                spawn_counter <= INITIAL_SPAWN_INTERVAL;
                dynamic_spawn_interval <= INITIAL_SPAWN_INTERVAL;
                missile_spawn_counter <= MISSILE_SPAWN_INTERVAL;
                warning_timer <= 0;
                coin_spawn_counter <= COIN_SPAWN_INTERVAL;
                 ramp_up_counter <= SPAWN_RAMP_RATE;
                spawn_counter <= 0; -- Start spawning immediately on next playing frame
            ELSIF playing = '1' THEN
                IF playing_prev = '0' THEN -- Game just started
                    spawn_counter <= 0; -- Trigger immediate spawn
                END IF;

                -- Ramp up spawn rate
                IF ramp_up_counter = 0 THEN
                    IF dynamic_spawn_interval > MIN_SPAWN_INTERVAL THEN
                        dynamic_spawn_interval <= dynamic_spawn_interval - SPAWN_INTERVAL_DECREMENT;
                    END IF;
                    ramp_up_counter <= SPAWN_RAMP_RATE;
                ELSE
                    ramp_up_counter <= ramp_up_counter - 1;
                END IF;

                speed_x := TO_INTEGER(world_speed);
                IF speed_x = 0 THEN
                    speed_x := BASE_LASER_SPEED_X;
                END IF;

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

                -- Update existing missiles
                FOR i IN 0 TO MAX_MISSILES - 1 LOOP
                    IF temp_missiles(i).is_active = '1' THEN
                        missile_speed_x := TO_INTEGER(world_speed) * 2;
                        IF missile_speed_x < 1 THEN
                            missile_speed_x := BASE_MISSILE_SPEED_X;
                        END IF;

                        temp_missiles(i).x := temp_missiles(i).x - missile_speed_x;

                        IF TO_INTEGER(temp_missiles(i).x) < -MISSILE_DISPLAY_WIDTH THEN
                            temp_missiles(i) := INACTIVE_MISSILE;
                        END IF;
                    END IF;

                    IF temp_missiles(i).is_warning = '1' THEN
                        IF warning_timer = 0 THEN
                            temp_missiles(i).is_warning := '0';
                            temp_missiles(i).is_active := '1';
                        ELSE
                            warning_timer <= warning_timer - 1;
                        END IF;
                    END IF;
                END LOOP;

                -- Update existing coins
                coin_speed_x := TO_INTEGER(world_speed);
                IF coin_speed_x < 1 THEN
                    coin_speed_x := BASE_COIN_SPEED_X;
                END IF;

                FOR i IN 0 TO MAX_COINS - 1 LOOP
                    IF temp_coins(i).is_active = '1' THEN
                        temp_coins(i).x := temp_coins(i).x - coin_speed_x;

                        IF TO_INTEGER(temp_coins(i).x) < -COIN_DISPLAY_WIDTH THEN
                            temp_coins(i) := INACTIVE_COIN;
                        END IF;
                    END IF;
                END LOOP;

                -- Check for spawning new laser
                IF spawn_counter = 0 THEN
                    -- Set timer for next spawn. Add a small random value to vary the timing.
                    spawn_counter <= dynamic_spawn_interval + TO_INTEGER(UNSIGNED(random_in(3 DOWNTO 0)));
                    
                    -- Find an inactive slot to spawn a new laser
                    -- This is inside the spawn_counter=0 block to ensure we only try to spawn one per trigger.
                    FOR i IN 0 TO MAX_LASERS - 1 LOOP
                        IF temp_pool(i).is_active = '0' THEN
                            
                            -- Generate a candidate new laser
                            is_horizontal := FALSE;
                            CASE random_in(15 DOWNTO 14) IS
                                WHEN "00" | "10" => is_horizontal := TRUE;
                                WHEN OTHERS => is_horizontal := FALSE;
                            END CASE;

                            -- Generate a y-coordinate within the margins.
                            -- Using modulo prevents clustering at the edges that happens with clamping.
                            IF is_horizontal THEN
                                -- Range: Y_MARGIN to SCREEN_HEIGHT - Y_MARGIN
                                rand_y := TO_UNSIGNED(Y_MARGIN, 10) + (RESIZE(UNSIGNED(random_in(9 DOWNTO 0)), 10) MOD TO_UNSIGNED(SCREEN_HEIGHT - 2 * Y_MARGIN, 10));
                            ELSE
                                -- Range: Y_MARGIN to SCREEN_HEIGHT - LASER_LENGTH - Y_MARGIN
                                rand_y := TO_UNSIGNED(Y_MARGIN, 10) + (RESIZE(UNSIGNED(random_in(9 DOWNTO 0)), 10) MOD TO_UNSIGNED(SCREEN_HEIGHT - LASER_LENGTH - 2 * Y_MARGIN, 10));
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
                ELSE
                    spawn_counter <= spawn_counter - 1;
                END IF;

                -- Spawn a missile warning when idle
                IF (temp_missiles(0).is_active = '0') AND (temp_missiles(0).is_warning = '0') THEN
                    IF missile_spawn_counter = 0 THEN
                        rand_missile_y := TO_INTEGER(UNSIGNED(random_in(9 DOWNTO 0)));
                        IF rand_missile_y > SCREEN_HEIGHT - MISSILE_DISPLAY_HEIGHT THEN
                            rand_missile_y := SCREEN_HEIGHT - MISSILE_DISPLAY_HEIGHT;
                        ELSIF rand_missile_y < 0 THEN
                            rand_missile_y := 0;
                        END IF;

                        temp_missiles(0).is_warning := '1';
                        temp_missiles(0).is_active := '0';
                        temp_missiles(0).x := TO_SIGNED(SCREEN_WIDTH - MISSILE_DISPLAY_WIDTH - MISSILE_OFFSET, 12);
                        temp_missiles(0).y := TO_SIGNED(rand_missile_y, 12);
                        warning_timer <= MISSILE_WARNING_DURATION;

                        jitter := TO_INTEGER(UNSIGNED(random_in(7 DOWNTO 0))) MOD MISSILE_SPAWN_JITTER;
                        missile_spawn_counter <= MISSILE_SPAWN_INTERVAL + jitter;
                    ELSE
                        missile_spawn_counter <= missile_spawn_counter - 1;
                    END IF;
                END IF;

                -- Spawn coins continuously
                IF coin_spawn_counter = 0 THEN
                    coin_spawned := FALSE;
                    FOR i IN 0 TO MAX_COINS - 1 LOOP
                        IF (NOT coin_spawned) AND (temp_coins(i).is_active = '0') THEN
                            rand_coin_y := TO_INTEGER(UNSIGNED(random_in(9 DOWNTO 0)));
                            IF rand_coin_y > SCREEN_HEIGHT - COIN_DISPLAY_HEIGHT THEN
                                rand_coin_y := SCREEN_HEIGHT - COIN_DISPLAY_HEIGHT;
                            ELSIF rand_coin_y < 0 THEN
                                rand_coin_y := 0;
                            END IF;

                            temp_coins(i).is_active := '1';
                            temp_coins(i).x := TO_SIGNED(SCREEN_WIDTH - 1, 12);
                            temp_coins(i).y := TO_SIGNED(rand_coin_y, 12);
                            coin_spawned := TRUE;
                        END IF;
                    END LOOP;

                    jitter_coin := TO_INTEGER(UNSIGNED(random_in(7 DOWNTO 0))) MOD COIN_SPAWN_JITTER;
                    coin_spawn_counter <= COIN_SPAWN_INTERVAL + jitter_coin;
                ELSE
                    coin_spawn_counter <= coin_spawn_counter - 1;
                END IF;
            ELSE
                temp_pool := INACTIVE_LASER_POOL;
                temp_missiles := INACTIVE_MISSILE_POOL;
                temp_coins := INACTIVE_COIN_POOL;
                missile_spawn_counter <= MISSILE_SPAWN_INTERVAL;
                warning_timer <= 0;
                coin_spawn_counter <= COIN_SPAWN_INTERVAL;
            END IF;
            pool <= temp_pool;
            missiles <= temp_missiles;
            coins <= temp_coins;
            playing_prev <= playing;
        END IF;
    END PROCESS manager_proc;

END ARCHITECTURE rtl;
