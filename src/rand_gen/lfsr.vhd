LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY lfsr IS
    PORT (
        clock : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        -- mouse position for entropy
        mouse_x : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        mouse_y : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        -- pulse on re-seed
        load : IN STD_LOGIC;
        -- 20 bits of random output
        random_out : OUT STD_LOGIC_VECTOR(19 DOWNTO 0)
    );
END ENTITY lfsr;

-- 20-bit maximal length Galois LFSR
-- taps at 20 and 17 (1-based indexing)

ARCHITECTURE galois of lfsr IS
    SIGNAL lfsr_s : STD_LOGIC_VECTOR(19 DOWNTO 0) := x"DEAD" & "0000";
    SIGNAL load_prev : STD_LOGIC := '0';
BEGIN
    lfsr_process: PROCESS (clock, reset)
        VARIABLE fb : STD_LOGIC;
        VARIABLE lfsr_next : STD_LOGIC_VECTOR(19 DOWNTO 0);
        VARIABLE seed : STD_LOGIC_VECTOR(19 DOWNTO 0);
    BEGIN
        IF reset = '1' THEN
            lfsr_s <= x"DEAD" & "0000";
            load_prev <= '0';
        ELSIF RISING_EDGE(clock) THEN
            load_prev <= load;
            IF load = '1' and load_prev = '0' THEN
                seed := mouse_x & mouse_y;
                IF seed = (OTHERS => '0') THEN
                    lfsr_s <= x"DEAD" & "0000";  -- avoid all-zero state
                ELSE
                    lfsr_s <= seed;
                END IF;
            ELSIF enable = '1' THEN
                -- 20 bit maximal length LFSR
                fb := lfsr_s(0);
                lfsr_next := '0' & lfsr_s(19 downto 1);
                lfsr_next(19) := lfsr_next(19) xor fb;  -- tap 20
                lfsr_next(16) := lfsr_next(16) xor fb;  -- tap 17
                lfsr_s <= lfsr_next;
            END IF;
        END IF;
    END PROCESS lfsr_process;
    
    random_out <= lfsr_s;
END ARCHITECTURE galois;
