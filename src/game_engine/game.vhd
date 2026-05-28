LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY game IS
    PORT (
        clock_50MHz, vert_sync, reset : IN STD_LOGIC;
        mouse_left : IN STD_LOGIC;
        mouse_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        mouse_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        death_signal : IN STD_LOGIC;
        powerup_collected : IN STD_LOGIC;
        coin_collected : IN STD_LOGIC;
        random_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        screen_flash : OUT STD_LOGIC;
        debug_vehicle_select : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        playing : OUT STD_LOGIC;  -- whether the game is currently being played or not. if not, the physics should not update, and the player should be reset to the starting position.
        is_dead : OUT STD_LOGIC;
        menu_active : OUT STD_LOGIC;
        training_mode : OUT STD_LOGIC;
        player_vehicle : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        player_vy : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        grounded : OUT STD_LOGIC;
        teleporter_preview_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        world_speed : OUT UNSIGNED(9 DOWNTO 0);
        score_out : OUT UNSIGNED(31 DOWNTO 0)
    );
END game;

ARCHITECTURE behaviour OF game IS
    -- this file is the top level of the game engine. it will instantiate the physics engine, and the rendering engine, and connect them together. it will also handle any global game state, such as whether the game is currently being played or not, and the player's current vehicle.
    -- the game starts in a menu state. clicking a menu button switches into play or training, which starts physics updates.

    -- physics component declarations
    COMPONENT physics IS
        PORT (
            vert_sync : IN STD_LOGIC;
            reset : IN STD_LOGIC;
            mouse_left : IN STD_LOGIC;
            playing : IN STD_LOGIC;
            player_vehicle : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        player_vy : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            grounded : OUT STD_LOGIC;
            teleporter_preview_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
        );
    END COMPONENT physics;

    SIGNAL player_y_pos : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL player_vy_pos : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL teleporter_preview_pos : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL is_player_grounded : STD_LOGIC := '0';
    SIGNAL active_vehicle : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    TYPE game_state_t IS (STATE_MENU, STATE_PLAY, STATE_TRAINING, STATE_DEATH);
    SIGNAL game_state : game_state_t := STATE_MENU;
    SIGNAL is_playing : STD_LOGIC := '0';
    SIGNAL is_training : STD_LOGIC := '0';
    SIGNAL mouse_left_prev : STD_LOGIC := '0';
    SIGNAL powerup_collected_prev : STD_LOGIC := '0';
    SIGNAL vert_sync_prev : STD_LOGIC := '0';
    SIGNAL invincibility_timer : INTEGER RANGE 0 TO 30 := 0;
    SIGNAL flash_timer : INTEGER RANGE 0 TO 12 := 0;

    CONSTANT SCREEN_WIDTH : INTEGER := 640;
    CONSTANT SCREEN_HEIGHT : INTEGER := 480;
    CONSTANT MENU_BUTTON_WIDTH : INTEGER := 200;
    CONSTANT MENU_BUTTON_HEIGHT : INTEGER := 48;
    CONSTANT MENU_BUTTON_X_LEFT : INTEGER := (SCREEN_WIDTH - MENU_BUTTON_WIDTH) / 2;
    CONSTANT MENU_PLAY_Y_TOP : INTEGER := 320;
    CONSTANT MENU_TRAIN_Y_TOP : INTEGER := MENU_PLAY_Y_TOP + MENU_BUTTON_HEIGHT + 24;

    SIGNAL play_hit : STD_LOGIC := '0';
    SIGNAL training_hit : STD_LOGIC := '0';

    CONSTANT BASE_WORLD_SPEED : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(4, 10);
    CONSTANT SPEED_UP_INTERVAL : INTEGER := 600; -- frames (~10s at 60Hz)
    SIGNAL world_speed_reg : UNSIGNED(9 DOWNTO 0) := BASE_WORLD_SPEED;
    SIGNAL speed_counter : INTEGER RANGE 0 TO SPEED_UP_INTERVAL := SPEED_UP_INTERVAL;

    SIGNAL distance_reg : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL coin_count_reg : UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL distance_accumulator : INTEGER RANGE 0 TO 100 := 0;
    SIGNAL score_reg : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');

    FUNCTION point_in_rect(
        x : UNSIGNED(9 DOWNTO 0);
        y : UNSIGNED(9 DOWNTO 0);
        left : INTEGER;
        top : INTEGER;
        width : INTEGER;
        height : INTEGER
    ) RETURN STD_LOGIC IS
        VARIABLE xi : INTEGER;
        VARIABLE yi : INTEGER;
    BEGIN
        xi := TO_INTEGER(x);
        yi := TO_INTEGER(y);

        IF (xi >= left) AND (xi < left + width) AND (yi >= top) AND (yi < top + height) THEN
            RETURN '1';
        END IF;

        RETURN '0';
    END FUNCTION;
BEGIN
    -- Vehicle choice is now managed by state machine.
    screen_flash <= '1' WHEN flash_timer > 0 ELSE '0';

    is_playing <= '1' WHEN game_state = STATE_PLAY OR game_state = STATE_TRAINING ELSE '0';
    is_training <= '1' WHEN game_state = STATE_TRAINING ELSE '0';
    is_dead <= '1' WHEN game_state = STATE_DEATH ELSE '0';
    menu_active <= '1' WHEN game_state = STATE_MENU ELSE '0';
    training_mode <= is_training;

    play_hit <= point_in_rect(UNSIGNED(mouse_x), UNSIGNED(mouse_y), MENU_BUTTON_X_LEFT, MENU_PLAY_Y_TOP, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT);
    training_hit <= point_in_rect(UNSIGNED(mouse_x), UNSIGNED(mouse_y), MENU_BUTTON_X_LEFT, MENU_TRAIN_Y_TOP, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT);

    -- instantiate the physics engine
    -- the physics engine takes care of update the player's y position. because we are currently just testing, we can just send the y position to the top level entity, which can render it. 
    physics_inst : physics
        PORT MAP (
        vert_sync => vert_sync,
        reset => reset,
        mouse_left => mouse_left,
        playing => is_playing,
        player_vehicle => active_vehicle,
        player_y => player_y_pos,
        player_vy => player_vy_pos,
        grounded => is_player_grounded,
        teleporter_preview_y => teleporter_preview_pos
    );

    menu_state: PROCESS (clock_50MHz)
        VARIABLE death_timer : INTEGER RANGE 0 TO 100000000 := 0; -- ~2 second delay
    BEGIN
        IF RISING_EDGE(clock_50MHz) THEN
            vert_sync_prev <= vert_sync;
            IF reset = '1' THEN
                game_state <= STATE_MENU;
                mouse_left_prev <= '0';
                powerup_collected_prev <= '0';
                active_vehicle <= "00";
                invincibility_timer <= 0;
                flash_timer <= 0;
            ELSE
                IF vert_sync = '0' AND vert_sync_prev = '1' THEN
                    IF invincibility_timer > 0 THEN
                        invincibility_timer <= invincibility_timer - 1;
                    END IF;
                    IF flash_timer > 0 THEN
                        flash_timer <= flash_timer - 1;
                    END IF;
                END IF;

                CASE game_state IS
                    WHEN STATE_MENU =>
                        death_timer := 100000000; -- reset timer for next time
                        active_vehicle <= "00";
                        IF mouse_left = '1' AND mouse_left_prev = '0' THEN
                            IF play_hit = '1' THEN
                                game_state <= STATE_PLAY;
                            ELSIF training_hit = '1' THEN
                                game_state <= STATE_TRAINING;
                            END IF;
                        END IF;
                    WHEN STATE_PLAY | STATE_TRAINING =>
                        IF powerup_collected = '1' AND powerup_collected_prev = '0' AND active_vehicle = "00" THEN
                            IF random_in = "00" THEN
                                active_vehicle <= "01";
                            ELSIF random_in = "01" THEN
                                active_vehicle <= "10";
                            ELSE
                                active_vehicle <= "11";
                            END IF;
                            invincibility_timer <= 30;
                        END IF;

                        IF death_signal = '1' THEN
                            IF invincibility_timer > 0 THEN
                                NULL;
                            ELSIF active_vehicle /= "00" THEN
                                active_vehicle <= "00";
                                invincibility_timer <= 30;
                                flash_timer <= 12;
                            ELSE
                                game_state <= STATE_DEATH;
                            END IF;
                        END IF;
                    WHEN STATE_DEATH =>
                        IF death_timer > 0 THEN
                            death_timer := death_timer - 1;
                        ELSE
                            game_state <= STATE_MENU;
                        END IF;
                END CASE;

                mouse_left_prev <= mouse_left;
                powerup_collected_prev <= powerup_collected;
            END IF;
        END IF;
    END PROCESS menu_state;

    speed_ramp: PROCESS (vert_sync)
    BEGIN
        IF RISING_EDGE(vert_sync) THEN
            IF is_playing = '1' AND is_training = '0' THEN
                IF speed_counter = 0 THEN
                    world_speed_reg <= world_speed_reg + 1;
                    speed_counter <= SPEED_UP_INTERVAL;
                ELSE
                    speed_counter <= speed_counter - 1;
                END IF;
            ELSE
                world_speed_reg <= BASE_WORLD_SPEED;
                speed_counter <= SPEED_UP_INTERVAL;
            END IF;
        END IF;
    END PROCESS speed_ramp;

    score_proc: PROCESS (vert_sync)
    BEGIN
        IF RISING_EDGE(vert_sync) THEN
            IF reset = '1' OR game_state = STATE_MENU THEN
                distance_reg <= (OTHERS => '0');
                coin_count_reg <= (OTHERS => '0');
                distance_accumulator <= 0;
            ELSIF is_playing = '1' THEN
                distance_accumulator <= distance_accumulator + TO_INTEGER(world_speed_reg);
                IF distance_accumulator >= 100 THEN
                    distance_accumulator <= distance_accumulator - 100;
                    distance_reg <= distance_reg + 1;
                END IF;

                IF coin_collected = '1' THEN
                    coin_count_reg <= coin_count_reg + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS score_proc;

    score_calc_proc: PROCESS(vert_sync)
    BEGIN
        IF RISING_EDGE(vert_sync) THEN
            IF reset = '1' OR game_state = STATE_MENU THEN
                score_reg <= (OTHERS => '0');
            ELSIF is_playing = '1' THEN
                score_reg <= distance_reg + RESIZE(coin_count_reg * 10, 32);
            END IF;
        END IF;
    END PROCESS score_calc_proc;

    -- some stuff goes here, such as handling the global game state, and connecting the physics and rendering engines together.
    
    playing <= is_playing;
    player_vehicle <= active_vehicle;
    player_y <= player_y_pos;
    player_vy <= player_vy_pos;
    grounded <= is_player_grounded;
    teleporter_preview_y <= teleporter_preview_pos;
    world_speed <= world_speed_reg;
    score_out <= score_reg;
END ARCHITECTURE behaviour;
