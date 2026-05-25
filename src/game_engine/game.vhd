LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY game IS
    PORT (
        clock_50MHz, vert_sync : IN STD_LOGIC;
        mouse_left : IN STD_LOGIC;
        debug_vehicle_select : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        playing : OUT STD_LOGIC;  -- whether the game is currently being played or not. if not, the physics should not update, and the player should be reset to the starting position.
        player_vehicle : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        player_vy : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        grounded : OUT STD_LOGIC;
        teleporter_preview_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        world_speed : OUT UNSIGNED(5 DOWNTO 0)
    );
END game;

ARCHITECTURE behaviour OF game IS
    -- this file is the top level of the game engine. it will instantiate the physics engine, and the rendering engine, and connect them together. it will also handle any global game state, such as whether the game is currently being played or not, and the player's current vehicle.
    -- the game should start in a non-playing state, but currently we'll just let it start for testing purposes. the player can start the game by clicking the mouse button, which will set the playing signal to '1', and the physics engine will start updating the player's position.

    -- physics component declarations
    COMPONENT physics IS
        PORT (
            vert_sync : IN STD_LOGIC;
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
    SIGNAL is_playing : STD_LOGIC := '0';

    CONSTANT BASE_WORLD_SPEED : UNSIGNED(5 DOWNTO 0) := TO_UNSIGNED(4, 6);
    CONSTANT MAX_WORLD_SPEED : UNSIGNED(5 DOWNTO 0) := TO_UNSIGNED(12, 6);
    CONSTANT SPEED_UP_INTERVAL : INTEGER := 180; -- frames
    SIGNAL world_speed_reg : UNSIGNED(5 DOWNTO 0) := BASE_WORLD_SPEED;
    SIGNAL speed_counter : INTEGER RANGE 0 TO SPEED_UP_INTERVAL := SPEED_UP_INTERVAL;
BEGIN
    -- Vehicle choice is centralized here. Replace this with powerup/game-state logic later.
    active_vehicle <= debug_vehicle_select;

    -- instantiate the physics engine
    -- the physics engine takes care of update the player's y position. because we are currently just testing, we can just send the y position to the top level entity, which can render it. 
    physics_inst : physics
        PORT MAP (
        vert_sync => vert_sync,
        mouse_left => mouse_left,
        playing => is_playing,
        player_vehicle => active_vehicle,
        player_y => player_y_pos,
        player_vy => player_vy_pos,
        grounded => is_player_grounded,
        teleporter_preview_y => teleporter_preview_pos
    );

    -- start the physics on mouse click
    start: PROCESS (clock_50MHz) BEGIN
        IF RISING_EDGE(clock_50MHz) THEN
            IF mouse_left = '1' THEN
                is_playing <= '1';
            END IF;
        END IF;
    END PROCESS start;

    speed_ramp: PROCESS (vert_sync)
    BEGIN
        IF RISING_EDGE(vert_sync) THEN
            IF is_playing = '1' THEN
                IF speed_counter = 0 THEN
                    IF world_speed_reg < MAX_WORLD_SPEED THEN
                        world_speed_reg <= world_speed_reg + 1;
                    END IF;
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
