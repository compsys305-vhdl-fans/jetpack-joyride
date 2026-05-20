LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;

ENTITY physics IS
    PORT (
        clock_50MHz, vert_sync : IN STD_LOGIC;
        mouse_left : IN STD_LOGIC;
        playing : IN STD_LOGIC;  -- whether the game is currently being played or not. if not, the physics should not update, and the player should be reset to the starting position.
        -- player specific signals
        player_vehicle : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        player_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
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
        -- 01: lil stomper (ls) -> has a thrust that is stronger than gravity, but only for a short time. 
            -- if the player holds the mouse button down for too long, the thrust will run out and they will fall at a reduced rate, until they hit the ground, at which point the thrust will reset.
            -- if the player is falling, and they start holding again, they will fall at the reduced rate, even if they have thrust again
            -- the player is allowed to not take the full thrust of the lil stomper, and can release the mouse button early to start falling sooner, but they will still fall at the reduced rate until they hit the ground.
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
    CONSTANT PLAYER_MIN_Y : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000001010";
    CONSTANT PLAYER_MAX_Y : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0111001100";
    CONSTANT PLAYER_Y_ACCELERATION : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
    CONSTANT PLAYER_MIN_Y_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1111110000"; -- -16 pixels/frame
    CONSTANT PLAYER_MAX_Y_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000010000"; -- +16 pixels/frame

    CONSTANT LS_JUMP_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1111110100"; -- -12 pixels/frame
    CONSTANT LS_THRUSTER_START_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1111111100"; -- -4 pixels/frame
    CONSTANT LS_THRUSTER_ACCELERATION : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000010";
    CONSTANT LS_GLIDE_SPEED : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000011";
    CONSTANT LS_THRUST_FRAMES : INTEGER := 10;

    CONSTANT PB_FLAP_BOOST : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000001100";  -- upward speed magnitude added by each profit bird flap (12)

    SIGNAL ls_thrust : INTEGER RANGE 0 TO LS_THRUST_FRAMES := LS_THRUST_FRAMES;
    SIGNAL player_y_pos : STD_LOGIC_VECTOR(9 DOWNTO 0) := PLAYER_MAX_Y;
    SIGNAL player_y_speed : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mouse_left_prev : STD_LOGIC := '0';
BEGIN
    -- some stuff goes here
    PROCESS (vert_sync)
        VARIABLE next_y_pos : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE next_y_speed : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE next_ls_thrust : INTEGER RANGE 0 TO LS_THRUST_FRAMES;
    BEGIN
        IF RISING_EDGE(vert_sync) THEN
            IF playing = '1' THEN
                next_y_pos := player_y_pos;
                next_y_speed := player_y_speed;
                next_ls_thrust := ls_thrust;

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
                        IF player_y_pos = PLAYER_MAX_Y AND mouse_left = '1' THEN
                            next_y_speed := LS_JUMP_SPEED;
                            next_ls_thrust := LS_THRUST_FRAMES;
                        ELSIF mouse_left = '1' THEN
                            IF next_y_speed >= "0000000000" THEN
                                next_y_speed := LS_GLIDE_SPEED;
                                next_ls_thrust := 0;
                            ELSIF next_ls_thrust > 0 AND next_y_speed >= LS_THRUSTER_START_SPEED THEN
                                next_y_speed := next_y_speed - LS_THRUSTER_ACCELERATION;
                                next_ls_thrust := next_ls_thrust - 1;
                            ELSE
                                next_y_speed := next_y_speed + PLAYER_Y_ACCELERATION;
                            END IF;
                        ELSE
                            next_y_speed := next_y_speed + PLAYER_Y_ACCELERATION;
                        END IF;
                    WHEN "10" =>  -- profit bird
                        IF mouse_left = '1' AND mouse_left_prev = '0' THEN
                            next_y_speed := "0000000000" - PB_FLAP_BOOST;
                        ELSE
                            next_y_speed := next_y_speed + PLAYER_Y_ACCELERATION;
                        END IF;
                    WHEN "11" =>  -- crazy freaking teleporter
                        NULL;
                    WHEN OTHERS =>
                        -- ignore the other cases for now
                        NULL;
                END CASE;

                IF (next_y_speed < PLAYER_MIN_Y_SPEED) THEN
                    next_y_speed := PLAYER_MIN_Y_SPEED;
                ELSIF (next_y_speed > PLAYER_MAX_Y_SPEED) THEN
                    next_y_speed := PLAYER_MAX_Y_SPEED;
                END IF;

                next_y_pos := next_y_pos + next_y_speed;

                -- make sure the player is not clipped to the ground or ceiling
                IF (next_y_pos < PLAYER_MIN_Y) THEN
                    next_y_pos := PLAYER_MIN_Y;
                    next_y_speed := (OTHERS => '0');
                ELSIF (next_y_pos > PLAYER_MAX_Y) THEN
                    next_y_pos := PLAYER_MAX_Y;
                    next_y_speed := (OTHERS => '0');
                    next_ls_thrust := LS_THRUST_FRAMES;
                END IF;

                player_y_pos <= next_y_pos;
                player_y_speed <= next_y_speed;
                ls_thrust <= next_ls_thrust;
                mouse_left_prev <= mouse_left;
            ELSE
                player_y_pos <= PLAYER_MAX_Y;
                player_y_speed <= (OTHERS => '0');
                ls_thrust <= LS_THRUST_FRAMES;
                mouse_left_prev <= '0';
            END IF;
        END IF;
    END PROCESS;

    player_y <= player_y_pos;
END ARCHITECTURE behaviour;
