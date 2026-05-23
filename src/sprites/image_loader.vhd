library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity image_loader is
    generic (
        IMAGE_WIDTH : positive;
        IMAGE_HEIGHT : positive;
        FLIP_X : boolean := false
    );
    port (
        x : in unsigned(15 downto 0);
        y : in unsigned(15 downto 0);
        pixel_index : out unsigned(7 downto 0);
        valid : out std_logic
    );
end entity image_loader;

architecture rtl of image_loader is
    function clog2(value : natural) return natural is
        variable result : natural := 0;
        variable tmp : natural := value - 1;
    begin
        while tmp > 0 loop
            tmp := tmp / 2;
            result := result + 1;
        end loop;
        return result;
    end function;

    constant IMAGE_DEPTH : natural := IMAGE_WIDTH * IMAGE_HEIGHT;
    constant ADDR_WIDTH : natural := clog2(IMAGE_DEPTH);

    signal rom_addr : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal rom_q : std_logic_vector(11 downto 0) := (others => '0');
    signal rom_q_u : unsigned(11 downto 0) := (others => '0');
    signal in_range : std_logic := '0';
begin
    rom_inst : altsyncram
        generic map (
            operation_mode => "ROM",
            width_a => 12,
            numwords_a => IMAGE_DEPTH,
            widthad_a => ADDR_WIDTH,
            outdata_reg_a => "UNREGISTERED",
            init_file => MIF_FILE
        )
        port map (
            address_a => std_logic_vector(rom_addr),
            clock0 => clock,
            q_a => rom_q,
            data_a => (others => '0'),
            wren_a => '0',
            rden_a => '1'
        );

    rom_q_u <= unsigned(rom_q);

    process(x, y)
        variable pixel_addr : natural;
        variable x_coord : unsigned(15 downto 0);
    begin
        if FLIP_X then
            x_coord := to_unsigned(IMAGE_WIDTH - 1, 16) - x;
        else
            x_coord := x;
        end if;

        if (x < IMAGE_WIDTH and y < IMAGE_HEIGHT) then
            in_range <= '1';
            pixel_addr := to_integer(y) * IMAGE_WIDTH + to_integer(x_coord);
            rom_addr <= to_unsigned(pixel_addr, ADDR_WIDTH);
        else
            in_range <= '0';
            rom_addr <= (others => '0');
        end if;
    end process;

    process(rom_q_u, in_range)
    begin
        if in_range = '1' then
            pixel_index <= resize(rom_q_u, pixel_index'length);
            valid <= '1';
        else
            pixel_index <= (others => '0');
            valid <= '0';
        end if;
    end process;
    
end architecture rtl;
