LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY game IS
    PORT (
        clock_50MHz, vert_sync, reset : IN STD_LOGIC;
        mouse_left : IN STD_LOGIC;
        mouse_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        mouse_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        debug_vehicle_select : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        playing : OUT STD_LOGIC;  -- whether the game is currently being played or not. if not, the physics should not update, and the player should be reset to the starting position.
        menu_active : OUT STD_LOGIC;
        training_mode : OUT STD_LOGIC;
        player_vehicle : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        player_vy : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        grounded : OUT STD_LOGIC;
        teleporter_preview_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        world_speed : OUT UNSIGNED(9 DOWNTO 0)
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
    TYPE game_state_t IS (STATE_MENU, STATE_PLAY, STATE_TRAINING);
    SIGNAL game_state : game_state_t := STATE_MENU;
    SIGNAL is_playing : STD_LOGIC := '0';
    SIGNAL is_training : STD_LOGIC := '0';
    SIGNAL mouse_left_prev : STD_LOGIC := '0';

    CONSTANT SCREEN_WIDTH : INTEGER := 640;
    CONSTANT SCREEN_HEIGHT : INTEGER := 480;
    CONSTANT MENU_BUTTON_WIDTH : INTEGER := 200;
    CONSTANT MENU_BUTTON_HEIGHT : INTEGER := 48;
    CONSTANT MENU_BUTTON_X_LEFT : INTEGER := (SCREEN_WIDTH - MENU_BUTTON_WIDTH) / 2;
    CONSTANT MENU_PLAY_Y_TOP : INTEGER := 170;
    CONSTANT MENU_TRAIN_Y_TOP : INTEGER := MENU_PLAY_Y_TOP + MENU_BUTTON_HEIGHT + 24;

    SIGNAL play_hit : STD_LOGIC := '0';
    SIGNAL training_hit : STD_LOGIC := '0';

    CONSTANT BASE_WORLD_SPEED : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(4, 10);
    CONSTANT SPEED_UP_INTERVAL : INTEGER := 600; -- frames (~10s at 60Hz)
    SIGNAL world_speed_reg : UNSIGNED(9 DOWNTO 0) := BASE_WORLD_SPEED;
    SIGNAL speed_counter : INTEGER RANGE 0 TO SPEED_UP_INTERVAL := SPEED_UP_INTERVAL;

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
    -- Vehicle choice is centralized here. Replace this with powerup/game-state logic later.
    active_vehicle <= debug_vehicle_select;

    is_playing <= '1' WHEN game_state /= STATE_MENU ELSE '0';
    is_training <= '1' WHEN game_state = STATE_TRAINING ELSE '0';
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

    menu_state: PROCESS (clock_50MHz) BEGIN
        IF RISING_EDGE(clock_50MHz) THEN
            IF reset = '1' THEN
                game_state <= STATE_MENU;
                mouse_left_prev <= '0';
            ELSE
                IF game_state = STATE_MENU THEN
                    IF mouse_left = '1' AND mouse_left_prev = '0' THEN
                        IF play_hit = '1' THEN
                            game_state <= STATE_PLAY;
                        ELSIF training_hit = '1' THEN
                            game_state <= STATE_TRAINING;
                        END IF;
                    END IF;
                END IF;
                mouse_left_prev <= mouse_left;
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

    -- some stuff goes here, such as handling the global game state, and connecting the physics and rendering engines together.
    
    playing <= is_playing;
    player_vehicle <= active_vehicle;
    player_y <= player_y_pos;
    player_vy <= player_vy_pos;
    grounded <= is_player_grounded;
    teleporter_preview_y <= teleporter_preview_pos;
    world_speed <= world_speed_reg;
END ARCHITECTURE behaviour;
