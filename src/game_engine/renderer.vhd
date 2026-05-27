LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY HARDWARE;
USE HARDWARE.VGA_TYPES.ALL;
USE work.sprite_palettes_pkg.ALL;
USE work.obstacle_types.ALL;

ENTITY renderer IS
    PORT (
        clock_25MHz          : IN STD_LOGIC;
        show_djt             : IN STD_LOGIC;
        pixel_x              : IN UNSIGNED(9 DOWNTO 0);
        pixel_y              : IN UNSIGNED(9 DOWNTO 0);

        player_y             : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        player_vehicle       : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        left_button          : IN STD_LOGIC;
        player_grounded      : IN STD_LOGIC;
        player_vy            : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        teleporter_preview_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        death                : IN STD_LOGIC;
        paused               : IN STD_LOGIC;
        menu_active          : IN STD_LOGIC;
        mouse_x              : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        mouse_y              : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

        laser_pool           : IN laser_pool_t;
        missile_pool         : IN missile_pool_t;
        coin_pool            : IN coin_pool_t;
        powerup_pool         : IN powerup_pool_t;
        screen_flash         : IN STD_LOGIC;
        score_value          : IN UNSIGNED(31 DOWNTO 0);
        frame_count          : IN UNSIGNED(7 DOWNTO 0);
        random_in            : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        world_speed          : IN UNSIGNED(9 DOWNTO 0);
        
        -- Output pixel color
        red_out              : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        green_out            : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        blue_out             : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY renderer;

ARCHITECTURE rtl OF renderer IS
    COMPONENT sprite_renderer IS
        PORT (
            clock          : IN STD_LOGIC;
            show_djt       : IN STD_LOGIC;
            sprite_id      : IN UNSIGNED(7 DOWNTO 0);
            palette_id     : IN UNSIGNED(7 DOWNTO 0);
            scale_shift    : IN NATURAL;
            rel_x          : IN UNSIGNED(15 DOWNTO 0);
            rel_y          : IN UNSIGNED(15 DOWNTO 0);
            color          : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            is_transparent : OUT STD_LOGIC;
            valid          : OUT STD_LOGIC
        );
    END COMPONENT sprite_renderer;

    -- Signals for player sprite calculation
    SIGNAL player_x_anchor      : UNSIGNED(9 DOWNTO 0) := TO_UNSIGNED(120, 10);
    SIGNAL player_sprite_width  : POSITIVE;
    SIGNAL player_sprite_height : POSITIVE;
    SIGNAL player_scale_shift   : NATURAL;
    SIGNAL player_display_width : POSITIVE;
    SIGNAL player_display_height: POSITIVE;
    SIGNAL player_palette_id    : UNSIGNED(7 DOWNTO 0);
    SIGNAL player_sprite_id     : UNSIGNED(7 DOWNTO 0);

    SIGNAL player_x_render     : UNSIGNED(9 DOWNTO 0);
    SIGNAL player_y_render     : UNSIGNED(9 DOWNTO 0);
    SIGNAL player_rel_x        : UNSIGNED(15 DOWNTO 0);
    SIGNAL player_rel_y        : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_player_sprite    : STD_LOGIC;
    SIGNAL player_is_transparent : STD_LOGIC;
    SIGNAL sprite_valid        : STD_LOGIC;
    SIGNAL sprite_color        : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL player_drawn        : STD_LOGIC;
    SIGNAL in_player_sprite_d  : STD_LOGIC := '0';

    -- Signals for laser calculation
    TYPE laser_color_array IS ARRAY (0 TO MAX_LASERS - 1) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    TYPE laser_transparency_array IS ARRAY (0 TO MAX_LASERS - 1) OF STD_LOGIC;
    TYPE laser_sprite_pixel_array IS ARRAY (0 TO MAX_LASERS - 1) OF STD_LOGIC;
    SIGNAL laser_colors        : laser_color_array;
    SIGNAL laser_transparencies: laser_transparency_array;
    SIGNAL laser_sprite_pixels : laser_sprite_pixel_array;
    SIGNAL combined_laser_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL combined_laser_is_transparent : STD_LOGIC;
    SIGNAL combined_laser_is_sprite_pixel : STD_LOGIC;

    -- Background sprite signals
    SIGNAL bg_sprite_id : UNSIGNED(7 DOWNTO 0);
    SIGNAL bg_palette_id : UNSIGNED(7 DOWNTO 0);
    SIGNAL bg_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL bg_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL bg_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL bg_is_transparent : STD_LOGIC;
    SIGNAL bg_valid : STD_LOGIC;
    SIGNAL bg_drawn : STD_LOGIC;
    SIGNAL bg_seed : UNSIGNED(1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL bg_seed_valid : STD_LOGIC := '0';
    SIGNAL frame_count_d : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL bg_scroll_accum : UNSIGNED(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL bg_parallax_step : UNSIGNED(9 DOWNTO 0);

    CONSTANT DEATH_SPRITE_WIDTH : NATURAL := 42;
    CONSTANT DEATH_SPRITE_HEIGHT : NATURAL := 13;
    CONSTANT DEATH_SCALE_SHIFT : NATURAL := 1;
    CONSTANT DEATH_DISPLAY_WIDTH : NATURAL := DEATH_SPRITE_WIDTH * 2;
    CONSTANT DEATH_DISPLAY_HEIGHT : NATURAL := DEATH_SPRITE_HEIGHT * 2;
    CONSTANT DEATH_X_LEFT : NATURAL := (640 - DEATH_DISPLAY_WIDTH) / 2;
    CONSTANT DEATH_Y_TOP : NATURAL := (480 - DEATH_DISPLAY_HEIGHT) / 2;

    CONSTANT PAUSE_SPRITE_WIDTH : NATURAL := 34;
    CONSTANT PAUSE_SPRITE_HEIGHT : NATURAL := 13;
    CONSTANT PAUSE_SCALE_SHIFT : NATURAL := 1;
    CONSTANT PAUSE_DISPLAY_WIDTH : NATURAL := PAUSE_SPRITE_WIDTH * 2;
    CONSTANT PAUSE_DISPLAY_HEIGHT : NATURAL := PAUSE_SPRITE_HEIGHT * 2;
    CONSTANT PAUSE_X_LEFT : NATURAL := (640 - PAUSE_DISPLAY_WIDTH) / 2;
    CONSTANT PAUSE_Y_TOP : NATURAL := (480 - PAUSE_DISPLAY_HEIGHT) / 2;

    CONSTANT WARNING_SPRITE_WIDTH : NATURAL := 16;
    CONSTANT WARNING_SPRITE_HEIGHT : NATURAL := 16;
    CONSTANT WARNING_SCALE_SHIFT : NATURAL := 1;
    CONSTANT WARNING_DISPLAY_WIDTH : NATURAL := WARNING_SPRITE_WIDTH * 2;
    CONSTANT WARNING_DISPLAY_HEIGHT : NATURAL := WARNING_SPRITE_HEIGHT * 2;

    CONSTANT MISSILE_SPRITE_WIDTH : NATURAL := 16;
    CONSTANT MISSILE_SPRITE_HEIGHT : NATURAL := 16;
    CONSTANT MISSILE_SCALE_SHIFT : NATURAL := 1;
    CONSTANT MISSILE_DISPLAY_WIDTH : NATURAL := MISSILE_SPRITE_WIDTH * 2;
    CONSTANT MISSILE_DISPLAY_HEIGHT : NATURAL := MISSILE_SPRITE_HEIGHT * 2;

    CONSTANT COIN_SPRITE_WIDTH : NATURAL := 16;
    CONSTANT COIN_SPRITE_HEIGHT : NATURAL := 16;
    CONSTANT COIN_SCALE_SHIFT : NATURAL := 1;
    CONSTANT COIN_DISPLAY_WIDTH : NATURAL := COIN_SPRITE_WIDTH * 2;
    CONSTANT COIN_DISPLAY_HEIGHT : NATURAL := COIN_SPRITE_HEIGHT * 2;

    CONSTANT POWERUP_SPRITE_WIDTH : NATURAL := 32;
    CONSTANT POWERUP_SPRITE_HEIGHT : NATURAL := 32;
    CONSTANT POWERUP_SCALE_SHIFT : NATURAL := 1;
    CONSTANT POWERUP_DISPLAY_WIDTH : NATURAL := POWERUP_SPRITE_WIDTH * 2;
    CONSTANT POWERUP_DISPLAY_HEIGHT : NATURAL := POWERUP_SPRITE_HEIGHT * 2;

    SIGNAL death_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL death_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_death_sprite : STD_LOGIC;
    SIGNAL in_death_sprite_d : STD_LOGIC := '0';
    SIGNAL death_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL death_sprite_is_transparent : STD_LOGIC;
    SIGNAL death_sprite_valid : STD_LOGIC;
    SIGNAL death_drawn : STD_LOGIC;

    SIGNAL pause_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL pause_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_pause_sprite : STD_LOGIC;
    SIGNAL in_pause_sprite_d : STD_LOGIC := '0';
    SIGNAL pause_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL pause_sprite_is_transparent : STD_LOGIC;
    SIGNAL pause_sprite_valid : STD_LOGIC;
    SIGNAL pause_drawn : STD_LOGIC;

    SIGNAL missile_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL missile_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_missile_sprite : STD_LOGIC;
    SIGNAL in_missile_sprite_d : STD_LOGIC := '0';
    SIGNAL missile_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL missile_sprite_is_transparent : STD_LOGIC;
    SIGNAL missile_sprite_valid : STD_LOGIC;
    SIGNAL missile_drawn : STD_LOGIC;

    SIGNAL missile_sprite_id : UNSIGNED(7 DOWNTO 0) := SPRITE_MISSILE;
    SIGNAL missile_palette_id : UNSIGNED(7 DOWNTO 0) := PALETTE_MISSILE;
    SIGNAL missile_scale_sel : NATURAL := MISSILE_SCALE_SHIFT;

    SIGNAL coin_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL coin_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_coin_sprite : STD_LOGIC;
    SIGNAL in_coin_sprite_d : STD_LOGIC := '0';
    SIGNAL coin_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL coin_sprite_is_transparent : STD_LOGIC;
    SIGNAL coin_sprite_valid : STD_LOGIC;
    SIGNAL coin_drawn : STD_LOGIC;

    SIGNAL powerup_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL powerup_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_powerup_sprite : STD_LOGIC;
    SIGNAL in_powerup_sprite_d : STD_LOGIC := '0';
    SIGNAL powerup_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL powerup_sprite_is_transparent : STD_LOGIC;
    SIGNAL powerup_sprite_valid : STD_LOGIC;
    SIGNAL powerup_drawn : STD_LOGIC;

    CONSTANT SCREEN_WIDTH : NATURAL := 640;
    CONSTANT MENU_BUTTON_WIDTH : NATURAL := 200;
    CONSTANT MENU_BUTTON_HEIGHT : NATURAL := 48;
    CONSTANT MENU_BUTTON_X_LEFT : NATURAL := (SCREEN_WIDTH - MENU_BUTTON_WIDTH) / 2;
    CONSTANT MENU_PLAY_Y_TOP : NATURAL := 320;
    CONSTANT MENU_TRAIN_Y_TOP : NATURAL := MENU_PLAY_Y_TOP + MENU_BUTTON_HEIGHT + 24;
    CONSTANT MENU_BORDER_THICKNESS : NATURAL := 2;

    CONSTANT TITLE_SPRITE_WIDTH : NATURAL := 480;
    CONSTANT TITLE_SPRITE_HEIGHT : NATURAL := 120;
    CONSTANT TITLE_SPRITE_LEFT : NATURAL := (SCREEN_WIDTH - TITLE_SPRITE_WIDTH) / 2;
    CONSTANT TITLE_SPRITE_TOP : NATURAL := 100;
    CONSTANT TITLE_SCALE_SHIFT : NATURAL := 1;
    SIGNAL title_rel_x : UNSIGNED(15 DOWNTO 0);
    SIGNAL title_rel_y : UNSIGNED(15 DOWNTO 0);
    SIGNAL in_title_sprite : STD_LOGIC;
    SIGNAL in_title_sprite_d : STD_LOGIC := '0';
    SIGNAL title_sprite_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL title_sprite_color_d : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL title_sprite_is_transparent : STD_LOGIC;
    SIGNAL title_sprite_valid : STD_LOGIC;
    SIGNAL title_drawn : STD_LOGIC;

    CONSTANT FONT_W : NATURAL := 5;
    CONSTANT FONT_H : NATURAL := 7;
    CONSTANT FONT_SCALE : NATURAL := 2;
    CONSTANT FONT_SPACING : NATURAL := 1;
    CONSTANT SCORE_FONT_SPACING : NATURAL := 3;

    CONSTANT PLAY_LEN : NATURAL := 4;
    CONSTANT TRAIN_LEN : NATURAL := 8;
    CONSTANT PLAY_TEXT_WIDTH : NATURAL := (PLAY_LEN * FONT_W + (PLAY_LEN - 1) * FONT_SPACING) * FONT_SCALE;
    CONSTANT TRAIN_TEXT_WIDTH : NATURAL := (TRAIN_LEN * FONT_W + (TRAIN_LEN - 1) * FONT_SPACING) * FONT_SCALE;
    CONSTANT TEXT_HEIGHT : NATURAL := FONT_H * FONT_SCALE;

    CONSTANT PLAY_TEXT_X_LEFT : NATURAL := MENU_BUTTON_X_LEFT + (MENU_BUTTON_WIDTH - PLAY_TEXT_WIDTH) / 2;
    CONSTANT PLAY_TEXT_Y_TOP : NATURAL := MENU_PLAY_Y_TOP + (MENU_BUTTON_HEIGHT - TEXT_HEIGHT) / 2;
    CONSTANT TRAIN_TEXT_X_LEFT : NATURAL := MENU_BUTTON_X_LEFT + (MENU_BUTTON_WIDTH - TRAIN_TEXT_WIDTH) / 2;
    CONSTANT TRAIN_TEXT_Y_TOP : NATURAL := MENU_TRAIN_Y_TOP + (MENU_BUTTON_HEIGHT - TEXT_HEIGHT) / 2;

    CONSTANT MENU_FILL_COLOR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"222";
    CONSTANT MENU_BORDER_COLOR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"EEE";
    CONSTANT MENU_TEXT_COLOR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"FFF";

    CONSTANT LETTER_P : INTEGER := 0;
    CONSTANT LETTER_L : INTEGER := 1;
    CONSTANT LETTER_A : INTEGER := 2;
    CONSTANT LETTER_Y : INTEGER := 3;
    CONSTANT LETTER_T : INTEGER := 4;
    CONSTANT LETTER_R : INTEGER := 5;
    CONSTANT LETTER_I : INTEGER := 6;
    CONSTANT LETTER_N : INTEGER := 7;
    CONSTANT LETTER_G : INTEGER := 8;

    CONSTANT WORD_PLAY : INTEGER := 0;
    CONSTANT WORD_TRAINING : INTEGER := 1;

    FUNCTION font_row(letter_id : INTEGER; row : INTEGER) RETURN STD_LOGIC_VECTOR IS
        VARIABLE bits : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        CASE letter_id IS
            WHEN LETTER_P =>
                CASE row IS
                    WHEN 0 => bits := "11110";
                    WHEN 1 => bits := "10001";
                    WHEN 2 => bits := "10001";
                    WHEN 3 => bits := "11110";
                    WHEN 4 => bits := "10000";
                    WHEN 5 => bits := "10000";
                    WHEN 6 => bits := "10000";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_L =>
                CASE row IS
                    WHEN 0 => bits := "10000";
                    WHEN 1 => bits := "10000";
                    WHEN 2 => bits := "10000";
                    WHEN 3 => bits := "10000";
                    WHEN 4 => bits := "10000";
                    WHEN 5 => bits := "10000";
                    WHEN 6 => bits := "11111";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_A =>
                CASE row IS
                    WHEN 0 => bits := "01110";
                    WHEN 1 => bits := "10001";
                    WHEN 2 => bits := "10001";
                    WHEN 3 => bits := "11111";
                    WHEN 4 => bits := "10001";
                    WHEN 5 => bits := "10001";
                    WHEN 6 => bits := "10001";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_Y =>
                CASE row IS
                    WHEN 0 => bits := "10001";
                    WHEN 1 => bits := "10001";
                    WHEN 2 => bits := "01010";
                    WHEN 3 => bits := "00100";
                    WHEN 4 => bits := "00100";
                    WHEN 5 => bits := "00100";
                    WHEN 6 => bits := "00100";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_T =>
                CASE row IS
                    WHEN 0 => bits := "11111";
                    WHEN 1 => bits := "00100";
                    WHEN 2 => bits := "00100";
                    WHEN 3 => bits := "00100";
                    WHEN 4 => bits := "00100";
                    WHEN 5 => bits := "00100";
                    WHEN 6 => bits := "00100";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_R =>
                CASE row IS
                    WHEN 0 => bits := "11110";
                    WHEN 1 => bits := "10001";
                    WHEN 2 => bits := "10001";
                    WHEN 3 => bits := "11110";
                    WHEN 4 => bits := "10100";
                    WHEN 5 => bits := "10010";
                    WHEN 6 => bits := "10001";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_I =>
                CASE row IS
                    WHEN 0 => bits := "11111";
                    WHEN 1 => bits := "00100";
                    WHEN 2 => bits := "00100";
                    WHEN 3 => bits := "00100";
                    WHEN 4 => bits := "00100";
                    WHEN 5 => bits := "00100";
                    WHEN 6 => bits := "11111";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_N =>
                CASE row IS
                    WHEN 0 => bits := "10001";
                    WHEN 1 => bits := "11001";
                    WHEN 2 => bits := "10101";
                    WHEN 3 => bits := "10011";
                    WHEN 4 => bits := "10001";
                    WHEN 5 => bits := "10001";
                    WHEN 6 => bits := "10001";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN LETTER_G =>
                CASE row IS
                    WHEN 0 => bits := "01110";
                    WHEN 1 => bits := "10001";
                    WHEN 2 => bits := "10000";
                    WHEN 3 => bits := "10111";
                    WHEN 4 => bits := "10001";
                    WHEN 5 => bits := "10001";
                    WHEN 6 => bits := "01110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN OTHERS =>
                bits := (OTHERS => '0');
        END CASE;

        RETURN bits;
    END FUNCTION;

    FUNCTION word_letter(word_id : INTEGER; idx : INTEGER) RETURN INTEGER IS
    BEGIN
        IF word_id = WORD_PLAY THEN
            CASE idx IS
                WHEN 0 => RETURN LETTER_P;
                WHEN 1 => RETURN LETTER_L;
                WHEN 2 => RETURN LETTER_A;
                WHEN 3 => RETURN LETTER_Y;
                WHEN OTHERS => RETURN LETTER_A;
            END CASE;
        ELSE
            CASE idx IS
                WHEN 0 => RETURN LETTER_T;
                WHEN 1 => RETURN LETTER_R;
                WHEN 2 => RETURN LETTER_A;
                WHEN 3 => RETURN LETTER_I;
                WHEN 4 => RETURN LETTER_N;
                WHEN 5 => RETURN LETTER_I;
                WHEN 6 => RETURN LETTER_N;
                WHEN 7 => RETURN LETTER_G;
                WHEN OTHERS => RETURN LETTER_A;
            END CASE;
        END IF;
    END FUNCTION;

    FUNCTION text_pixel(
        word_id : INTEGER;
        s_x : INTEGER;
        s_y : INTEGER;
        origin_x : INTEGER;
        origin_y : INTEGER
    ) RETURN BOOLEAN IS
        CONSTANT CELL_W : INTEGER := (FONT_W + FONT_SPACING) * FONT_SCALE;
        VARIABLE local_x : INTEGER;
        VARIABLE local_y : INTEGER;
        VARIABLE letter_idx : INTEGER;
        VARIABLE letter_x : INTEGER;
        VARIABLE row : INTEGER;
        VARIABLE col : INTEGER;
        VARIABLE letter_id : INTEGER;
        VARIABLE row_bits : STD_LOGIC_VECTOR(4 DOWNTO 0);
        VARIABLE max_len : INTEGER;
    BEGIN
        local_x := s_x - origin_x;
        local_y := s_y - origin_y;

        IF local_x < 0 OR local_y < 0 THEN
            RETURN FALSE;
        END IF;

        IF local_y >= FONT_H * FONT_SCALE THEN
            RETURN FALSE;
        END IF;

        letter_idx := local_x / CELL_W;
        IF word_id = WORD_PLAY THEN
            max_len := PLAY_LEN;
        ELSE
            max_len := TRAIN_LEN;
        END IF;

        IF letter_idx < 0 OR letter_idx >= max_len THEN
            RETURN FALSE;
        END IF;

        letter_x := local_x MOD CELL_W;
        IF letter_x >= FONT_W * FONT_SCALE THEN
            RETURN FALSE;
        END IF;

        row := local_y / FONT_SCALE;
        col := letter_x / FONT_SCALE;
        letter_id := word_letter(word_id, letter_idx);
        row_bits := font_row(letter_id, row);

        IF row_bits(FONT_W - 1 - col) = '1' THEN
            RETURN TRUE;
        END IF;

        RETURN FALSE;
    END FUNCTION;

    CONSTANT SCORE_DIGITS : NATURAL := 7;
    CONSTANT SCORE_MARGIN_X : NATURAL := 16;
    CONSTANT SCORE_MARGIN_Y : NATURAL := 16;
    CONSTANT SCORE_TEXT_WIDTH : NATURAL := (SCORE_DIGITS * FONT_W + (SCORE_DIGITS - 1) * SCORE_FONT_SPACING) * FONT_SCALE;
    CONSTANT SCORE_TEXT_HEIGHT : NATURAL := FONT_H * FONT_SCALE;

    FUNCTION pow10(exp : INTEGER) RETURN INTEGER IS
    BEGIN
        CASE exp IS
            WHEN 0 => RETURN 1;
            WHEN 1 => RETURN 10;
            WHEN 2 => RETURN 100;
            WHEN 3 => RETURN 1000;
            WHEN 4 => RETURN 10000;
            WHEN 5 => RETURN 100000;
            WHEN 6 => RETURN 1000000;
            WHEN OTHERS => RETURN 1; -- Default case, though should not be hit with current logic
        END CASE;
    END FUNCTION;

    FUNCTION digit_row(digit : INTEGER; row : INTEGER) RETURN STD_LOGIC_VECTOR IS
        VARIABLE bits : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        CASE digit IS
            WHEN 0 =>
                CASE row IS
                    WHEN 0 => bits := "01110";
                    WHEN 1 | 2 | 3 | 4 | 5 => bits := "10001";
                    WHEN 6 => bits := "01110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 1 =>
                CASE row IS
                    WHEN 0 => bits := "00100";
                    WHEN 1 => bits := "01100";
                    WHEN 2 | 3 | 4 | 5 => bits := "00100";
                    WHEN 6 => bits := "01110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 2 =>
                CASE row IS
                    WHEN 0 => bits := "01110";
                    WHEN 1 => bits := "10001";
                    WHEN 2 => bits := "00001";
                    WHEN 3 => bits := "00010";
                    WHEN 4 => bits := "00100";
                    WHEN 5 => bits := "01000";
                    WHEN 6 => bits := "11111";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 3 =>
                CASE row IS
                    WHEN 0 => bits := "11110";
                    WHEN 1 | 2 => bits := "00001";
                    WHEN 3 => bits := "01110";
                    WHEN 4 | 5 => bits := "00001";
                    WHEN 6 => bits := "11110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 4 =>
                CASE row IS
                    WHEN 0 => bits := "00010";
                    WHEN 1 => bits := "00110";
                    WHEN 2 => bits := "01010";
                    WHEN 3 => bits := "10010";
                    WHEN 4 => bits := "11111";
                    WHEN 5 | 6 => bits := "00010";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 5 =>
                CASE row IS
                    WHEN 0 => bits := "11111";
                    WHEN 1 | 2 => bits := "10000";
                    WHEN 3 => bits := "11110";
                    WHEN 4 | 5 => bits := "00001";
                    WHEN 6 => bits := "11110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 6 =>
                CASE row IS
                    WHEN 0 => bits := "01110";
                    WHEN 1 | 2 => bits := "10000";
                    WHEN 3 => bits := "11110";
                    WHEN 4 | 5 => bits := "10001";
                    WHEN 6 => bits := "01110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 7 =>
                CASE row IS
                    WHEN 0 => bits := "11111";
                    WHEN 1 => bits := "00001";
                    WHEN 2 => bits := "00010";
                    WHEN 3 => bits := "00100";
                    WHEN 4 | 5 | 6 => bits := "01000";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 8 =>
                CASE row IS
                    WHEN 0 => bits := "01110";
                    WHEN 1 | 2 => bits := "10001";
                    WHEN 3 => bits := "01110";
                    WHEN 4 | 5 => bits := "10001";
                    WHEN 6 => bits := "01110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN 9 =>
                CASE row IS
                    WHEN 0 => bits := "01110";
                    WHEN 1 | 2 => bits := "10001";
                    WHEN 3 => bits := "01111";
                    WHEN 4 | 5 => bits := "00001";
                    WHEN 6 => bits := "01110";
                    WHEN OTHERS => bits := (OTHERS => '0');
                END CASE;
            WHEN OTHERS =>
                bits := (OTHERS => '0');
        END CASE;

        RETURN bits;
    END FUNCTION;

    FUNCTION score_pixel(score_val : INTEGER; s_x : INTEGER; s_y : INTEGER; origin_x : INTEGER; origin_y : INTEGER) RETURN BOOLEAN IS
        CONSTANT CELL_W : INTEGER := (FONT_W + SCORE_FONT_SPACING) * FONT_SCALE;
        VARIABLE local_x : INTEGER;
        VARIABLE local_y : INTEGER;
        VARIABLE digit_idx : INTEGER;
        VARIABLE digit_x : INTEGER;
        VARIABLE row : INTEGER;
        VARIABLE col : INTEGER;
        VARIABLE digit_place : INTEGER;
        VARIABLE digit_val : INTEGER;
        VARIABLE row_bits : STD_LOGIC_VECTOR(4 DOWNTO 0);
        VARIABLE div : INTEGER;
    BEGIN
        local_x := s_x - origin_x;
        local_y := s_y - origin_y;

        IF local_x < 0 OR local_y < 0 THEN
            RETURN FALSE;
        END IF;

        IF local_y >= FONT_H * FONT_SCALE THEN
            RETURN FALSE;
        END IF;

        digit_idx := local_x / CELL_W;
        IF digit_idx < 0 OR digit_idx >= INTEGER(SCORE_DIGITS) THEN
            RETURN FALSE;
        END IF;

        digit_x := local_x MOD CELL_W;
        IF digit_x >= FONT_W * FONT_SCALE THEN
            RETURN FALSE;
        END IF;

        row := local_y / FONT_SCALE;
        col := digit_x / FONT_SCALE;
        digit_place := INTEGER(SCORE_DIGITS) - 1 - digit_idx;
        div := pow10(digit_place);

        IF (score_val < div) AND (digit_idx < INTEGER(SCORE_DIGITS) - 1) THEN
            RETURN FALSE;
        END IF;

        digit_val := (score_val / div) MOD 10;
        row_bits := digit_row(digit_val, row);

        IF row_bits(FONT_W - 1 - col) = '1' THEN
            RETURN TRUE;
        END IF;

        RETURN FALSE;
    END FUNCTION;

    SIGNAL menu_drawn : STD_LOGIC;
    SIGNAL menu_drawn_d : STD_LOGIC := '0';
    SIGNAL menu_color : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL menu_color_d : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

    SIGNAL score_drawn : STD_LOGIC;
    SIGNAL score_drawn_d : STD_LOGIC := '0';
    SIGNAL score_value_reg : UNSIGNED(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL frame_count_prev : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');

    CONSTANT CURSOR_HALF_SIZE : INTEGER := 2;
    CONSTANT CURSOR_COLOR : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"FFF";
    SIGNAL cursor_on : STD_LOGIC := '0';
    SIGNAL cursor_on_d : STD_LOGIC := '0';

    SIGNAL laser_beam_rect_mode : STD_LOGIC := '0';

    -- Pipelining registers
    SIGNAL pixel_y_lookahead       : UNSIGNED(9 DOWNTO 0);
    SIGNAL base_color              : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL base_color_d            : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL laser_colors_reg        : laser_color_array;
    SIGNAL laser_transparencies_reg: laser_transparency_array;
    SIGNAL laser_sprite_pixels_reg : laser_sprite_pixel_array;

BEGIN
    pixel_y_lookahead <= pixel_y + 1;
        bg_parallax_step <= world_speed;

    PROCESS(player_vehicle, left_button, player_grounded, player_vy)
    BEGIN
        IF player_vehicle = "00" THEN
            -- Jetpack gamemode: active sprite only when holding down
            player_palette_id <= PALETTE_BARRY;
            player_scale_shift <= 1;
            player_sprite_width <= 16;
            player_sprite_height <= 16;
            IF left_button = '1' THEN
                player_sprite_id <= SPRITE_BARRY_FLY;
            ELSE
                player_sprite_id <= SPRITE_BARRY_RUN;
            END IF;
        ELSIF player_vehicle = "01" THEN
            player_palette_id <= PALETTE_LIL_STOMPER;
            player_scale_shift <= 1;
            player_sprite_width <= 64;
            player_sprite_height <= 64;
            -- Lil Stomper gamemode: flying sprite when player holding down and in the air, and if not holding, falling sprite, but if on ground, show running sprite
            IF player_grounded = '1' THEN
                player_sprite_id <= SPRITE_STOMPER_RUN;
            ELSIF left_button = '1' THEN
                player_sprite_id <= SPRITE_STOMPER_FLY;
            ELSE
                player_sprite_id <= SPRITE_STOMPER_FALL;
            END IF;
        ELSIF player_vehicle = "10" THEN -- Bird
            player_palette_id <= PALETTE_BIRD;
            player_scale_shift <= 1;
            player_sprite_width <= 32;
            player_sprite_height <= 32;
            IF player_vy(9) = '1' THEN
                player_sprite_id <= SPRITE_BIRD_NOHOLD;
            ELSE
                player_sprite_id <= SPRITE_BIRD_HOLD;
            END IF;
        ELSIF player_vehicle = "11" THEN -- Teleporter
            player_palette_id <= PALETTE_TELEPORTER;
            player_scale_shift <= 1;
            player_sprite_width <= 32;
            player_sprite_height <= 32;
            player_sprite_id <= SPRITE_TELEPORTER;
        ELSE
            -- Default case to prevent latches
            player_palette_id <= PALETTE_BARRY;
            player_scale_shift <= 1;
            player_sprite_width <= 16;
            player_sprite_height <= 16;
            player_sprite_id <= SPRITE_BARRY_RUN;
        END IF;
    END PROCESS;

    player_display_width <= player_sprite_width * 2;
    player_display_height <= player_sprite_height * 2;

    PROCESS (player_display_width, player_x_anchor)
        VARIABLE center_x : INTEGER;
        VARIABLE left_x : INTEGER;
    BEGIN
        center_x := TO_INTEGER(player_x_anchor);
        left_x := center_x - (player_display_width / 2);

        IF left_x < 0 THEN
            left_x := 0;
        END IF;

        player_x_render <= TO_UNSIGNED(left_x, 10);
    END PROCESS;

    PROCESS (player_y, player_display_height, player_vehicle)
        CONSTANT MAX_PLAYER_DISPLAY_HEIGHT : NATURAL := 128;
        VARIABLE offset : NATURAL;
    BEGIN
        -- Offset the rendered Y position to bottom-align all sprites, except the teleporter
        IF player_vehicle = "11" THEN -- is teleporter
            offset := 0;
        ELSE
            offset := MAX_PLAYER_DISPLAY_HEIGHT - player_display_height;
        END IF;
        player_y_render <= UNSIGNED(player_y) + TO_UNSIGNED(offset, 10);
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, player_x_render, player_y_render, player_display_width, player_display_height)
        VARIABLE s_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE p_y : UNSIGNED(15 DOWNTO 0);
    BEGIN
        s_x := RESIZE(pixel_x, 16);
        s_y := RESIZE(pixel_y_lookahead, 16);
        p_x := RESIZE(player_x_render, 16);
        p_y := RESIZE(player_y_render, 16);
        
        IF (s_x >= p_x) AND (s_x < p_x + TO_UNSIGNED(player_display_width, 16)) AND
           (s_y >= p_y) AND (s_y < p_y + TO_UNSIGNED(player_display_height, 16)) THEN
            in_player_sprite <= '1';
            player_rel_x <= s_x - p_x;
            player_rel_y <= s_y - p_y;
        ELSE
            in_player_sprite <= '0';
            player_rel_x <= (OTHERS => '0');
            player_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, death)
        VARIABLE s_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y : UNSIGNED(15 DOWNTO 0);
        VARIABLE left_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE top_y : UNSIGNED(15 DOWNTO 0);
    BEGIN
        s_x := RESIZE(pixel_x, 16);
        s_y := RESIZE(pixel_y_lookahead, 16);
        left_x := TO_UNSIGNED(DEATH_X_LEFT, 16);
        top_y := TO_UNSIGNED(DEATH_Y_TOP, 16);

        IF (death = '1') AND
           (s_x >= left_x) AND (s_x < left_x + TO_UNSIGNED(DEATH_DISPLAY_WIDTH, 16)) AND
           (s_y >= top_y) AND (s_y < top_y + TO_UNSIGNED(DEATH_DISPLAY_HEIGHT, 16)) THEN
            in_death_sprite <= '1';
            death_rel_x <= s_x - left_x;
            death_rel_y <= s_y - top_y;
        ELSE
            in_death_sprite <= '0';
            death_rel_x <= (OTHERS => '0');
            death_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, paused)
        VARIABLE s_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y : UNSIGNED(15 DOWNTO 0);
        VARIABLE left_x : UNSIGNED(15 DOWNTO 0);
        VARIABLE top_y : UNSIGNED(15 DOWNTO 0);
    BEGIN
        s_x := RESIZE(pixel_x, 16);
        s_y := RESIZE(pixel_y_lookahead, 16);
        left_x := TO_UNSIGNED(PAUSE_X_LEFT, 16);
        top_y := TO_UNSIGNED(PAUSE_Y_TOP, 16);

        IF (paused = '1') AND (menu_active = '0') AND (death = '0') AND
           (s_x >= left_x) AND (s_x < left_x + TO_UNSIGNED(PAUSE_DISPLAY_WIDTH, 16)) AND
           (s_y >= top_y) AND (s_y < top_y + TO_UNSIGNED(PAUSE_DISPLAY_HEIGHT, 16)) THEN
            in_pause_sprite <= '1';
            pause_rel_x <= s_x - left_x;
            pause_rel_y <= s_y - top_y;
        ELSE
            in_pause_sprite <= '0';
            pause_rel_x <= (OTHERS => '0');
            pause_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    PROCESS(missile_pool)
    BEGIN
        missile_sprite_id <= SPRITE_MISSILE;
        missile_palette_id <= PALETTE_MISSILE;
        missile_scale_sel <= MISSILE_SCALE_SHIFT;

        IF missile_pool(0).is_warning = '1' THEN
            missile_sprite_id <= SPRITE_WARNING;
            missile_palette_id <= PALETTE_WARNING;
            missile_scale_sel <= WARNING_SCALE_SHIFT;
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, missile_pool, missile_sprite_id)
        VARIABLE s_x, s_y : INTEGER;
        VARIABLE m_x, m_y : INTEGER;
        VARIABLE disp_w, disp_h : INTEGER;
    BEGIN
        s_x := TO_INTEGER(pixel_x);
        s_y := TO_INTEGER(pixel_y_lookahead);
        m_x := TO_INTEGER(missile_pool(0).x);
        m_y := TO_INTEGER(missile_pool(0).y);

        IF missile_sprite_id = SPRITE_WARNING THEN
            disp_w := WARNING_DISPLAY_WIDTH;
            disp_h := WARNING_DISPLAY_HEIGHT;
        ELSE
            disp_w := MISSILE_DISPLAY_WIDTH;
            disp_h := MISSILE_DISPLAY_HEIGHT;
        END IF;

        IF (missile_pool(0).is_warning = '1') OR (missile_pool(0).is_active = '1') THEN
            IF (s_x >= m_x) AND (s_x < m_x + disp_w) AND (s_y >= m_y) AND (s_y < m_y + disp_h) THEN
                in_missile_sprite <= '1';
                missile_rel_x <= TO_UNSIGNED(s_x - m_x, 16);
                missile_rel_y <= TO_UNSIGNED(s_y - m_y, 16);
            ELSE
                in_missile_sprite <= '0';
                missile_rel_x <= (OTHERS => '0');
                missile_rel_y <= (OTHERS => '0');
            END IF;
        ELSE
            in_missile_sprite <= '0';
            missile_rel_x <= (OTHERS => '0');
            missile_rel_y <= (OTHERS => '0');
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, coin_pool)
        VARIABLE s_x, s_y : INTEGER;
        VARIABLE c_x, c_y : INTEGER;
        VARIABLE found : BOOLEAN;
    BEGIN
        s_x := TO_INTEGER(pixel_x);
        s_y := TO_INTEGER(pixel_y_lookahead);
        found := false;
        in_coin_sprite <= '0';
        coin_rel_x <= (OTHERS => '0');
        coin_rel_y <= (OTHERS => '0');

        FOR i IN 0 TO MAX_COINS - 1 LOOP
            IF (NOT found) AND (coin_pool(i).is_active = '1') THEN
                c_x := TO_INTEGER(coin_pool(i).x);
                c_y := TO_INTEGER(coin_pool(i).y);

                IF (s_x >= c_x) AND (s_x < c_x + COIN_DISPLAY_WIDTH) AND
                   (s_y >= c_y) AND (s_y < c_y + COIN_DISPLAY_HEIGHT) THEN
                    found := true;
                    in_coin_sprite <= '1';
                    coin_rel_x <= TO_UNSIGNED(s_x - c_x, 16);
                    coin_rel_y <= TO_UNSIGNED(s_y - c_y, 16);
                END IF;
            END IF;
        END LOOP;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, powerup_pool)
        VARIABLE s_x, s_y : INTEGER;
        VARIABLE p_x, p_y : INTEGER;
    BEGIN
        s_x := TO_INTEGER(pixel_x);
        s_y := TO_INTEGER(pixel_y_lookahead);
        in_powerup_sprite <= '0';
        powerup_rel_x <= (OTHERS => '0');
        powerup_rel_y <= (OTHERS => '0');

        IF powerup_pool(0).is_active = '1' THEN
            p_x := TO_INTEGER(powerup_pool(0).x);
            p_y := TO_INTEGER(powerup_pool(0).y);

            IF (s_x >= p_x) AND (s_x < p_x + POWERUP_DISPLAY_WIDTH) AND
               (s_y >= p_y) AND (s_y < p_y + POWERUP_DISPLAY_HEIGHT) THEN
                in_powerup_sprite <= '1';
                powerup_rel_x <= TO_UNSIGNED(s_x - p_x, 16);
                powerup_rel_y <= TO_UNSIGNED(s_y - p_y, 16);
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, menu_active)
        VARIABLE s_x : INTEGER;
        VARIABLE s_y : INTEGER;
        VARIABLE in_play : BOOLEAN;
        VARIABLE in_training : BOOLEAN;
        VARIABLE on_border : BOOLEAN;
        VARIABLE text_on : BOOLEAN;
        VARIABLE left_x : INTEGER;
        VARIABLE top_y : INTEGER;

        VARIABLE s_x_u : UNSIGNED(15 DOWNTO 0);
        VARIABLE s_y_u : UNSIGNED(15 DOWNTO 0);
        VARIABLE left_x_u : UNSIGNED(15 DOWNTO 0);
        VARIABLE top_y_u : UNSIGNED(15 DOWNTO 0);
    BEGIN
        -- Default assignments
        menu_drawn <= '0';
        menu_color <= (OTHERS => '0');
        in_title_sprite <= '0';
        title_rel_x <= (OTHERS => '0');
        title_rel_y <= (OTHERS => '0');

        IF menu_active = '1' THEN
            s_x := TO_INTEGER(pixel_x);
            s_y := TO_INTEGER(pixel_y_lookahead);

            -- Title sprite logic
            s_x_u := RESIZE(pixel_x, 16);
            s_y_u := RESIZE(pixel_y_lookahead, 16);
            left_x_u := TO_UNSIGNED(TITLE_SPRITE_LEFT, 16);
            top_y_u := TO_UNSIGNED(TITLE_SPRITE_TOP, 16);

            IF (s_x_u >= left_x_u) AND (s_x_u < left_x_u + TO_UNSIGNED(TITLE_SPRITE_WIDTH, 16)) AND
               (s_y_u >= top_y_u) AND (s_y_u < top_y_u + TO_UNSIGNED(TITLE_SPRITE_HEIGHT, 16)) THEN
                in_title_sprite <= '1';
                title_rel_x <= s_x_u - left_x_u;
                title_rel_y <= s_y_u - top_y_u;
            END IF;

            -- Menu buttons logic
            in_play := (s_x >= MENU_BUTTON_X_LEFT) AND (s_x < MENU_BUTTON_X_LEFT + MENU_BUTTON_WIDTH) AND
                       (s_y >= MENU_PLAY_Y_TOP) AND (s_y < MENU_PLAY_Y_TOP + MENU_BUTTON_HEIGHT);
            in_training := (s_x >= MENU_BUTTON_X_LEFT) AND (s_x < MENU_BUTTON_X_LEFT + MENU_BUTTON_WIDTH) AND
                           (s_y >= MENU_TRAIN_Y_TOP) AND (s_y < MENU_TRAIN_Y_TOP + MENU_BUTTON_HEIGHT);

            IF in_play OR in_training THEN
                menu_drawn <= '1';

                IF in_play THEN
                    left_x := MENU_BUTTON_X_LEFT;
                    top_y := MENU_PLAY_Y_TOP;
                    text_on := text_pixel(WORD_PLAY, s_x, s_y, PLAY_TEXT_X_LEFT, PLAY_TEXT_Y_TOP);
                ELSE
                    left_x := MENU_BUTTON_X_LEFT;
                    top_y := MENU_TRAIN_Y_TOP;
                    text_on := text_pixel(WORD_TRAINING, s_x, s_y, TRAIN_TEXT_X_LEFT, TRAIN_TEXT_Y_TOP);
                END IF;

                on_border := (s_x < left_x + MENU_BORDER_THICKNESS) OR
                             (s_x >= left_x + MENU_BUTTON_WIDTH - MENU_BORDER_THICKNESS) OR
                             (s_y < top_y + MENU_BORDER_THICKNESS) OR
                             (s_y >= top_y + MENU_BUTTON_HEIGHT - MENU_BORDER_THICKNESS);

                IF text_on THEN
                    menu_color <= MENU_TEXT_COLOR;
                ELSIF on_border THEN
                    menu_color <= MENU_BORDER_COLOR;
                ELSE
                    menu_color <= MENU_FILL_COLOR;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, score_value_reg, menu_active)
        VARIABLE s_x : INTEGER;
        VARIABLE s_y : INTEGER;
        VARIABLE score_int : INTEGER;
    BEGIN
        score_drawn <= '0';

        IF menu_active = '0' THEN
            s_x := TO_INTEGER(pixel_x);
            s_y := TO_INTEGER(pixel_y_lookahead);
            score_int := TO_INTEGER(score_value_reg);

            IF score_pixel(score_int, s_x, s_y, SCORE_MARGIN_X, SCORE_MARGIN_Y) THEN
                score_drawn <= '1';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pixel_x, pixel_y_lookahead, mouse_x, mouse_y)
        VARIABLE px : INTEGER;
        VARIABLE py : INTEGER;
        VARIABLE mx : INTEGER;
        VARIABLE my : INTEGER;
    BEGIN
        px := TO_INTEGER(pixel_x);
        py := TO_INTEGER(pixel_y_lookahead);
        mx := TO_INTEGER(UNSIGNED(mouse_x));
        my := TO_INTEGER(UNSIGNED(mouse_y));

        IF (ABS(px - mx) <= CURSOR_HALF_SIZE) AND (ABS(py - my) <= CURSOR_HALF_SIZE) THEN
            cursor_on <= '1';
        ELSE
            cursor_on <= '0';
        END IF;
    END PROCESS;

    player_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => show_djt,
            sprite_id      => player_sprite_id,
            palette_id     => player_palette_id,
            scale_shift    => player_scale_shift,
            rel_x          => player_rel_x,
            rel_y          => player_rel_y,
            color          => sprite_color,
            is_transparent => player_is_transparent,
            valid          => sprite_valid
        );

    background_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => show_djt,
            sprite_id      => bg_sprite_id,
            palette_id     => bg_palette_id,
            scale_shift    => 1,
            rel_x          => bg_rel_x,
            rel_y          => bg_rel_y,
            color          => bg_color,
            is_transparent => bg_is_transparent,
            valid          => bg_valid
        );

    death_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => '0',
            sprite_id      => SPRITE_DEATH_TEXT,
            palette_id     => PALETTE_DEATH,
            scale_shift    => DEATH_SCALE_SHIFT,
            rel_x          => death_rel_x,
            rel_y          => death_rel_y,
            color          => death_sprite_color,
            is_transparent => death_sprite_is_transparent,
            valid          => death_sprite_valid
        );

    pause_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => '0',
            sprite_id      => SPRITE_PAUSE_TEXT,
            palette_id     => PALETTE_UI,
            scale_shift    => PAUSE_SCALE_SHIFT,
            rel_x          => pause_rel_x,
            rel_y          => pause_rel_y,
            color          => pause_sprite_color,
            is_transparent => pause_sprite_is_transparent,
            valid          => pause_sprite_valid
        );

    missile_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => '0',
            sprite_id      => missile_sprite_id,
            palette_id     => missile_palette_id,
            scale_shift    => missile_scale_sel,
            rel_x          => missile_rel_x,
            rel_y          => missile_rel_y,
            color          => missile_sprite_color,
            is_transparent => missile_sprite_is_transparent,
            valid          => missile_sprite_valid
        );

    coin_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => '0',
            sprite_id      => SPRITE_COIN,
            palette_id     => PALETTE_COIN,
            scale_shift    => COIN_SCALE_SHIFT,
            rel_x          => coin_rel_x,
            rel_y          => coin_rel_y,
            color          => coin_sprite_color,
            is_transparent => coin_sprite_is_transparent,
            valid          => coin_sprite_valid
        );

    powerup_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => '0',
            sprite_id      => SPRITE_POWERUP,
            palette_id     => PALETTE_POWERUP,
            scale_shift    => POWERUP_SCALE_SHIFT,
            rel_x          => powerup_rel_x,
            rel_y          => powerup_rel_y,
            color          => powerup_sprite_color,
            is_transparent => powerup_sprite_is_transparent,
            valid          => powerup_sprite_valid
        );

    title_sprite_renderer: sprite_renderer
        PORT MAP (
            clock          => clock_25MHz,
            show_djt       => '0',
            sprite_id      => SPRITE_TITLE,
            palette_id     => PALETTE_TITLE,
            scale_shift    => TITLE_SCALE_SHIFT,
            rel_x          => title_rel_x,
            rel_y          => title_rel_y,
            color          => title_sprite_color,
            is_transparent => title_sprite_is_transparent,
            valid          => title_sprite_valid
        );

    PROCESS(clock_25MHz)
    BEGIN
        IF RISING_EDGE(clock_25MHz) THEN
            IF frame_count /= frame_count_d THEN
                IF bg_seed_valid = '0' THEN
                    bg_seed <= UNSIGNED(random_in(1 DOWNTO 0));
                    bg_seed_valid <= '1';
                END IF;

                IF bg_parallax_step = TO_UNSIGNED(0, bg_parallax_step'length) THEN
                    bg_scroll_accum <= bg_scroll_accum + 1;
                ELSE
                    bg_scroll_accum <= bg_scroll_accum + RESIZE(bg_parallax_step, 12);
                END IF;
            END IF;
            frame_count_d <= frame_count;
            in_player_sprite_d <= in_player_sprite;
            in_death_sprite_d <= in_death_sprite;
            in_pause_sprite_d <= in_pause_sprite;
            in_missile_sprite_d <= in_missile_sprite;
            in_title_sprite_d <= in_title_sprite;
            title_sprite_color_d <= title_sprite_color;
            menu_drawn_d <= menu_drawn;
            menu_color_d <= menu_color;
            score_drawn_d <= score_drawn;
            IF frame_count /= frame_count_prev THEN
                score_value_reg <= score_value;
            END IF;
            frame_count_prev <= frame_count;
            in_coin_sprite_d <= in_coin_sprite;
            in_powerup_sprite_d <= in_powerup_sprite;
            cursor_on_d <= cursor_on;
            laser_colors_reg <= laser_colors;
            laser_transparencies_reg <= laser_transparencies;
            laser_sprite_pixels_reg <= laser_sprite_pixels;
            base_color_d <= base_color;
        END IF;
    END PROCESS;

    player_drawn <= in_player_sprite_d AND sprite_valid AND (NOT player_is_transparent);
    death_drawn <= in_death_sprite_d AND death_sprite_valid AND (NOT death_sprite_is_transparent);
    pause_drawn <= in_pause_sprite_d AND pause_sprite_valid AND (NOT pause_sprite_is_transparent);
    missile_drawn <= in_missile_sprite_d AND missile_sprite_valid AND (NOT missile_sprite_is_transparent);
    coin_drawn <= in_coin_sprite_d AND coin_sprite_valid AND (NOT coin_sprite_is_transparent);
    powerup_drawn <= in_powerup_sprite_d AND powerup_sprite_valid AND (NOT powerup_sprite_is_transparent);
    title_drawn <= in_title_sprite_d AND title_sprite_valid AND (NOT title_sprite_is_transparent);
    bg_drawn <= bg_valid AND (NOT bg_is_transparent);

    PROCESS(pixel_x, pixel_y_lookahead, bg_seed, bg_scroll_accum, show_djt)
        VARIABLE tile_x : INTEGER;
        VARIABLE sel : INTEGER;
        VARIABLE scrolled_x : UNSIGNED(11 DOWNTO 0);
    BEGIN
        IF show_djt = '1' THEN
            bg_sprite_id <= SPRITE_DJT;
            bg_palette_id <= PALETTE_DJT;
            bg_rel_x <= RESIZE(pixel_x, 16) SLL 1;
            bg_rel_y <= RESIZE(pixel_y_lookahead, 16) SLL 1;
        ELSE
            bg_palette_id <= PALETTE_BACKGROUND2;
            scrolled_x := RESIZE(pixel_x, 12) + bg_scroll_accum;
            bg_rel_x <= RESIZE(scrolled_x(6 DOWNTO 0), 16);
            bg_rel_y <= RESIZE(pixel_y_lookahead, 16);

            tile_x := TO_INTEGER(scrolled_x(9 DOWNTO 7));
            sel := (tile_x + TO_INTEGER(bg_seed)) MOD 3;

            CASE sel IS
                WHEN 0 =>
                    bg_sprite_id <= SPRITE_BG2_LIGHT;
                WHEN 1 =>
                    bg_sprite_id <= SPRITE_BG2_PILLAR;
                WHEN OTHERS =>
                    bg_sprite_id <= SPRITE_BG2_PLAIN;
            END CASE;
        END IF;
    END PROCESS;

    laser_gen: FOR i IN 0 TO MAX_LASERS - 1 GENERATE
        laser_inst: ENTITY work.laser
            PORT MAP(
                clock => clock_25MHz,
                show_djt => show_djt,
                pixel_x => pixel_x,
                pixel_y => pixel_y_lookahead,
                pos => laser_pool(i).pos,
                direction => laser_pool(i).direction,
                length => laser_pool(i).length,
                is_active => laser_pool(i).is_active,
                color_out => laser_colors(i),
                is_transparent => laser_transparencies(i),
                is_sprite_pixel => laser_sprite_pixels(i)
            );
    END GENERATE;
    
    PROCESS(laser_colors_reg, laser_transparencies_reg, laser_sprite_pixels_reg)
        VARIABLE found : BOOLEAN := false;
    BEGIN
        combined_laser_color <= (OTHERS => '0');
        combined_laser_is_transparent <= '1';
        combined_laser_is_sprite_pixel <= '0';
        found := false;

        FOR idx IN 0 TO MAX_LASERS - 1 LOOP
            IF (NOT found) AND (laser_transparencies_reg(idx) = '0') THEN
                combined_laser_color <= laser_colors_reg(idx);
                combined_laser_is_transparent <= '0';
                combined_laser_is_sprite_pixel <= laser_sprite_pixels_reg(idx);
                found := true;
            END IF;
        END LOOP;
    END PROCESS;

    PROCESS (pixel_y_lookahead, teleporter_preview_y, bg_drawn, bg_color, show_djt, player_vehicle)
        VARIABLE r,g,b : INTEGER RANGE 0 TO 15;
    BEGIN
        IF bg_drawn = '1' THEN
            r := TO_INTEGER(UNSIGNED(bg_color(11 DOWNTO 8)));
            g := TO_INTEGER(UNSIGNED(bg_color(7 DOWNTO 4)));
            b := TO_INTEGER(UNSIGNED(bg_color(3 DOWNTO 0)));
        ELSE
            r := 0;  g := 0; b := 0; -- Black
        END IF;

        IF show_djt = '0' AND player_vehicle = "11" THEN
            IF UNSIGNED(pixel_y_lookahead) = UNSIGNED(teleporter_preview_y) THEN
                 r := 15; g := 6; b := 0; -- Orange
            END IF;
        END IF;
        base_color <= STD_LOGIC_VECTOR(TO_UNSIGNED(r,4) & TO_UNSIGNED(g,4) & TO_UNSIGNED(b,4));
    END PROCESS;

    PROCESS (cursor_on_d, menu_drawn_d, menu_color_d, death_drawn, death_sprite_color, pause_drawn, pause_sprite_color,
             score_drawn_d, show_djt, player_drawn, sprite_color, missile_drawn, missile_sprite_color,
             coin_drawn, coin_sprite_color, powerup_drawn, powerup_sprite_color, base_color_d,
             combined_laser_is_transparent, combined_laser_is_sprite_pixel, combined_laser_color, screen_flash, title_drawn, title_sprite_color_d)
        VARIABLE base_r, base_g, base_b : INTEGER RANGE 0 TO 15;
        VARIABLE add_r, add_g, add_b : INTEGER;
        VARIABLE final_r, final_g, final_b : INTEGER RANGE 0 TO 15;
    BEGIN
        IF screen_flash = '1' THEN
            final_r := 15;
            final_g := 15;
            final_b := 15;
        ELSIF cursor_on_d = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(CURSOR_COLOR(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(CURSOR_COLOR(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(CURSOR_COLOR(3 DOWNTO 0)));
        ELSIF title_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(title_sprite_color_d(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(title_sprite_color_d(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(title_sprite_color_d(3 DOWNTO 0)));
        ELSIF menu_drawn_d = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(menu_color_d(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(menu_color_d(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(menu_color_d(3 DOWNTO 0)));
        ELSIF death_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(death_sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(death_sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(death_sprite_color(3 DOWNTO 0)));
        ELSIF pause_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(pause_sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(pause_sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(pause_sprite_color(3 DOWNTO 0)));
        ELSIF score_drawn_d = '1' THEN
            final_r := 15;
            final_g := 15;
            final_b := 15;
        ELSIF show_djt = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(base_color_d(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(base_color_d(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(base_color_d(3 DOWNTO 0)));
        ELSIF player_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(sprite_color(3 DOWNTO 0)));
        ELSIF missile_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(missile_sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(missile_sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(missile_sprite_color(3 DOWNTO 0)));
        ELSIF coin_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(coin_sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(coin_sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(coin_sprite_color(3 DOWNTO 0)));
        ELSIF powerup_drawn = '1' THEN
            final_r := TO_INTEGER(UNSIGNED(powerup_sprite_color(11 DOWNTO 8)));
            final_g := TO_INTEGER(UNSIGNED(powerup_sprite_color(7 DOWNTO 4)));
            final_b := TO_INTEGER(UNSIGNED(powerup_sprite_color(3 DOWNTO 0)));
        ELSE
            -- Determine base color
            base_r := TO_INTEGER(UNSIGNED(base_color_d(11 DOWNTO 8)));
            base_g := TO_INTEGER(UNSIGNED(base_color_d(7 DOWNTO 4)));
            base_b := TO_INTEGER(UNSIGNED(base_color_d(3 DOWNTO 0)));

            -- Add laser color
            IF combined_laser_is_transparent = '1' THEN
                final_r := base_r;
                final_g := base_g;
                final_b := base_b;
            ELSIF combined_laser_is_sprite_pixel = '1' THEN
                final_r := TO_INTEGER(UNSIGNED(combined_laser_color(11 DOWNTO 8)));
                final_g := TO_INTEGER(UNSIGNED(combined_laser_color(7 DOWNTO 4)));
                final_b := TO_INTEGER(UNSIGNED(combined_laser_color(3 DOWNTO 0)));
            ELSE
                add_r := base_r + TO_INTEGER(UNSIGNED(combined_laser_color(11 DOWNTO 8)));
                add_g := base_g + TO_INTEGER(UNSIGNED(combined_laser_color(7 DOWNTO 4)));
                add_b := base_b + TO_INTEGER(UNSIGNED(combined_laser_color(3 DOWNTO 0)));

                IF add_r > 15 THEN final_r := 15; ELSE final_r := add_r; END IF;
                IF add_g > 15 THEN final_g := 15; ELSE final_g := add_g; END IF;
                IF add_b > 15 THEN final_b := 15; ELSE final_b := add_b; END IF;
            END IF;
        END IF;

        red_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(final_r, 4));
        green_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(final_g, 4));
        blue_out <= STD_LOGIC_VECTOR(TO_UNSIGNED(final_b, 4));
    END PROCESS;

END ARCHITECTURE rtl;
