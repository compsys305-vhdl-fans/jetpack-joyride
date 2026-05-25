LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;

ENTITY physics IS
    PORT (
        vert_sync : IN STD_LOGIC;
        mouse_left : IN STD_LOGIC;
        playing : IN STD_LOGIC;  -- whether the game is currently being played or not. if not, the physics should not update, and the player should be reset to the starting position.
        -- player specific signals
        player_vehicle : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        player_vy : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        grounded : OUT STD_LOGIC;
        teleporter_preview_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
    );
END physics;

-- this file is the physics engine. it currently does not care about obstacle collisions; it only models each vehicles movement, and ground / ceiling collisions. it will also take in mouse input to control the jetpack, and output the player's y position for rendering purposes.

ARCHITECTURE behaviour OF physics IS
    -- note, this is a sidescroller with no vertical scrolling, so we only need to keep track of the player's y position, and not their x position. the player's x position is fixed, and the obstacles will move towards the player from the right side of the screen.
    -- the physics update every vertical sync, which is 60 times per second. this means that the physics will update every 16.67 milliseconds, but we will offload the computation to a separate process that runs at 50MHz, and only update the player's position every 16.67 milliseconds, to ensure that the physics are consistent and not affected by any potential lag or performance issues, and also ensure that we do not have tearing or other visual artifacts that can occur when the physics update rate is not consistent with the rendering update rate.
    -- some vehicles have different physics.
    -- there are (currently) 4 vehicles that the player can be using;
        -- 00: jetpack (jj) -> moves up when mouse is held down
            -- the gravity and jetpack thrust are the same, just in opposite directions, so the player movement is sinusoidal.
        -- 01: lil stomper (ls) -> jumps from the ground, then uses thrusters to counteract gravity while the mouse is held.
            -- holding changes the jump height and greatly slows the fall, but the jump is tuned so it should not reach the ceiling.
        -- 10: profit bird (pb) -> flaps
            -- click to flap, no holding mechanics
            -- quite similar to flappy bird
            -- repeated clicks in a short time will make each consecutive flap go slightly higher, up to a certain point, to allow the player to gain more height if they are in a pinch. this is because the profit bird is quite slow, and it can be difficult to gain height quickly with it.
            -- this could probably be implemented by just adding momentum to the current momentum, which closely models (if not exactly) the behavior of the profit bird.
        -- 11: crazy freaking teleporter (cft) -> no gravity
            -- has a hologram in front of the player that moves up and down in a sinusoidal pattern, and the player can teleport to the hologram's position by clicking down.
            -- no holding mechanics
    -----------------------------------
    -- i need to add more stuff here --
    -----------------------------------
    CONSTANT SCREEN_HEIGHT : INTEGER := 480;
    CONSTANT TOP_MARGIN : INTEGER := -22;
    CONSTANT BOTTOM_MARGIN : INTEGER := 10;

    SIGNAL current_player_height : INTEGER := 32;
    SIGNAL player_max_y_int : INTEGER;
    SIGNAL player_max_y : STD_LOGIC_VECTOR(9 DOWNTO 0);

    CONSTANT PLAYER_Y_ACCELERATION : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
    CONSTANT PLAYER_MIN_Y_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1111110000"; -- -16 pixels/frame
    CONSTANT PLAYER_MAX_Y_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000010000"; -- +16 pixels/frame

    CONSTANT LS_MIN_Y_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1111101010"; -- -22 pixels/frame
    CONSTANT LS_JUMP_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1111101100"; -- -20 pixels/frame
    CONSTANT LS_THRUSTER_ACCELERATION : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
    CONSTANT LS_FALL_BRAKE_ACCELERATION : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000010";
    CONSTANT LS_HELD_MAX_FALL_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000101"; -- +5 pixels/frame

    CONSTANT PB_FLAP_BOOST : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000001100";  -- upward speed magnitude added by each profit bird flap (12)

    CONSTANT TELEPORTER_PREVIEW_ACCELERATION : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
    CONSTANT TELEPORTER_PREVIEW_MIN_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := PLAYER_MIN_Y_SPEED;
    CONSTANT TELEPORTER_PREVIEW_MAX_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := PLAYER_MAX_Y_SPEED;
    SIGNAL teleporter_preview_mid_y : STD_LOGIC_VECTOR(9 DOWNTO 0);

    SIGNAL player_y_pos : STD_LOGIC_VECTOR(9 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(SCREEN_HEIGHT - 32 - BOTTOM_MARGIN, 10);
    SIGNAL player_y_speed : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL teleporter_preview_pos : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL teleporter_preview_speed : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL ls_thruster_tick : STD_LOGIC := '0';
    SIGNAL mouse_left_prev : STD_LOGIC := '0';

    signal player_min_y_int : INTEGER;
    signal player_min_y : STD_LOGIC_VECTOR(9 DOWNTO 0);

BEGIN
    player_height_calc: PROCESS(player_vehicle)
    BEGIN
        CASE player_vehicle IS
            WHEN "00" => -- Jetpack
                current_player_height <= 32;
            WHEN "01" => -- Lil Stomper
                current_player_height <= 128;
            WHEN "10" => -- Bird
                current_player_height <= 64;
            WHEN "11" => -- Teleporter
                current_player_height <= 64;
            WHEN OTHERS =>
                current_player_height <= 32;
        END CASE;
    END PROCESS player_height_calc;

    player_max_y_int <= SCREEN_HEIGHT - 128 - BOTTOM_MARGIN; -- we want all floors to be the same, and lil stomper 'just works'
    player_max_y <= CONV_STD_LOGIC_VECTOR(player_max_y_int, 10);
    player_min_y_int <= TOP_MARGIN + current_player_height;
    player_min_y <= CONV_STD_LOGIC_VECTOR(player_min_y_int, 10);
    teleporter_preview_mid_y <= CONV_STD_LOGIC_VECTOR((player_min_y_int + player_max_y_int) / 2, 10);
    
    -- teleporter_preview_pos <= player_max_y;
    -- some stuff goes here
    PROCESS (vert_sync)
        VARIABLE next_y_pos : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE next_y_speed : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE next_preview_pos : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE next_preview_speed : STD_LOGIC_VECTOR(9 DOWNTO 0);
    BEGIN
        IF RISING_EDGE(vert_sync) THEN
            IF playing = '1' THEN
                next_y_pos := player_y_pos;
                next_y_speed := player_y_speed;
                ls_thruster_tick <= '0';

                next_preview_pos := teleporter_preview_pos;
                next_preview_speed := teleporter_preview_speed;

                -- calculate the player's new speed and position based on;
                    -- the current speed and position
                    -- the player's current vehicle
                    -- whether the mouse button is currently held down or not
                CASE player_vehicle IS
                    WHEN "00" =>  -- jetpack
                        IF mouse_left = '1' THEN
                            -- screen space has 0 at the top, so thrust is negative y
                            next_y_speed := next_y_speed - PLAYER_Y_ACCELERATION;
                        ELSE
                            -- gravity is positive y
                            next_y_speed := next_y_speed + PLAYER_Y_ACCELERATION;
                        END IF;
                    WHEN "01" =>  -- lil stomper
                        IF player_y_pos = PLAYER_MAX_Y AND mouse_left = '1' AND mouse_left_prev = '0' THEN
                            next_y_speed := LS_JUMP_SPEED;
                            ls_thruster_tick <= '0';
                        ELSE
                            next_y_speed := next_y_speed + PLAYER_Y_ACCELERATION;

                            IF mouse_left = '1' THEN
                                IF next_y_speed > LS_HELD_MAX_FALL_SPEED THEN
                                    next_y_speed := next_y_speed - LS_FALL_BRAKE_ACCELERATION;
                                ELSIF ls_thruster_tick = '1' THEN
                                    next_y_speed := next_y_speed - LS_THRUSTER_ACCELERATION;
                                END IF;

                                ls_thruster_tick <= NOT ls_thruster_tick;
                            ELSE
                                ls_thruster_tick <= '0';
                            END IF;
                        END IF;
                    WHEN "10" =>  -- profit bird
                        IF mouse_left = '1' AND mouse_left_prev = '0' THEN
                            next_y_speed := "0000000000" - PB_FLAP_BOOST;
                        ELSE
                            next_y_speed := next_y_speed + PLAYER_Y_ACCELERATION;
                        END IF;
                    WHEN "11" =>  -- crazy freaking teleporter
                        IF next_preview_pos > TELEPORTER_PREVIEW_MID_Y THEN
                            next_preview_speed := next_preview_speed - TELEPORTER_PREVIEW_ACCELERATION;
                        ELSIF next_preview_pos < TELEPORTER_PREVIEW_MID_Y THEN
                            next_preview_speed := next_preview_speed + TELEPORTER_PREVIEW_ACCELERATION;
                        END IF;

                        IF mouse_left = '1' AND mouse_left_prev = '0' THEN
                            next_y_pos := next_preview_pos;
                            next_y_speed := (OTHERS => '0');
                        END IF;
                END CASE;

                IF player_vehicle = "01" AND next_y_speed < LS_MIN_Y_SPEED THEN
                    next_y_speed := LS_MIN_Y_SPEED;
                ELSIF player_vehicle /= "01" AND next_y_speed < PLAYER_MIN_Y_SPEED THEN
                    next_y_speed := PLAYER_MIN_Y_SPEED;
                ELSIF next_y_speed > PLAYER_MAX_Y_SPEED THEN
                    next_y_speed := PLAYER_MAX_Y_SPEED;
                END IF;

                next_y_pos := next_y_pos + next_y_speed;

                -- make sure the player is not clipped to the ground or ceiling
                IF (next_y_pos < player_min_y) THEN
                    next_y_pos := player_min_y;
                    next_y_speed := (OTHERS => '0');
                ELSIF (next_y_pos > PLAYER_MAX_Y) THEN
                    next_y_pos := PLAYER_MAX_Y;
                    next_y_speed := (OTHERS => '0');
                END IF;

                player_y_pos <= next_y_pos;
                player_y_speed <= next_y_speed;

                IF player_vehicle = "11" THEN
                    IF next_preview_speed < TELEPORTER_PREVIEW_MIN_SPEED THEN
                        next_preview_speed := TELEPORTER_PREVIEW_MIN_SPEED;
                    ELSIF next_preview_speed > TELEPORTER_PREVIEW_MAX_SPEED THEN
                        next_preview_speed := TELEPORTER_PREVIEW_MAX_SPEED;
                    END IF;

                    next_preview_pos := next_preview_pos + next_preview_speed;

                    IF next_preview_pos < player_min_y THEN
                        next_preview_pos := player_min_y;
                        next_preview_speed := (OTHERS => '0');
                    ELSIF next_preview_pos > PLAYER_MAX_Y THEN
                        next_preview_pos := PLAYER_MAX_Y;
                        next_preview_speed := (OTHERS => '0');
                    END IF;

                    teleporter_preview_pos <= next_preview_pos;
                    teleporter_preview_speed <= next_preview_speed;
                ELSE
                    teleporter_preview_pos <= PLAYER_MAX_Y;
                    teleporter_preview_speed <= (OTHERS => '0');
                END IF;

                mouse_left_prev <= mouse_left;
            ELSE
                player_y_pos <= PLAYER_MAX_Y;
                player_y_speed <= (OTHERS => '0');
                teleporter_preview_pos <= PLAYER_MAX_Y;
                teleporter_preview_speed <= (OTHERS => '0');
                ls_thruster_tick <= '0';
                mouse_left_prev <= '0';
            END IF;
        END IF;
    END PROCESS;

    player_y <= player_y_pos;
    player_vy <= player_y_speed;
    grounded <= '1' WHEN player_y_pos = PLAYER_MAX_Y ELSE '0';
    teleporter_preview_y <= teleporter_preview_pos;
END ARCHITECTURE behaviour;
