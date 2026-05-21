library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
library std;
use std.textio.all;

use work.image_palette_pkg.all;

entity image_loader is
    generic (
        IMAGE_WIDTH : positive;
        IMAGE_HEIGHT : positive;
        MIF_FILE : string
    );
    port (
        x : in unsigned(15 downto 0);
        y : in unsigned(15 downto 0);
        pixel_index : out unsigned(7 downto 0);
        color : out std_logic_vector(11 downto 0);
        valid : out std_logic
    );
end entity image_loader;

architecture rtl of image_loader is
    
    type image_data_t is array (natural range <>) of unsigned(11 downto 0);
    
    impure function init_image return image_data_t is
        file mif_handle : text open read_mode is MIF_FILE;
        variable row_line : line;
        variable addr : integer;
        variable separator : character;
        variable data_word : std_logic_vector(11 downto 0);
        variable image_data : image_data_t(0 to IMAGE_WIDTH * IMAGE_HEIGHT - 1) := (others => (others => '0'));
        variable has_data : boolean;
        variable line_count : natural := 0;
        constant MAX_MIF_LINES : natural := 10000;
    begin
        while (not endfile(mif_handle)) and (line_count < MAX_MIF_LINES) loop
            readline(mif_handle, row_line);
            line_count := line_count + 1;

            has_data := false;
            if row_line /= null then
                if row_line.all'length > 0 then
                    if (row_line.all(row_line.all'low) >= '0')
                        and (row_line.all(row_line.all'low) <= '9') then
                        has_data := true;
                    end if;
                end if;
            end if;

            if has_data then
                read(row_line, addr);
                read(row_line, separator);
                if separator = ':' then
                    hread(row_line, data_word);
                    if addr >= image_data'low and addr <= image_data'high then
                        image_data(addr) := unsigned(data_word);
                    end if;
                end if;
            end if;
        end loop;

        return image_data;
    end function;

    constant image_data : image_data_t(0 to IMAGE_WIDTH * IMAGE_HEIGHT - 1) := init_image;
    
begin

    process(x, y)
        variable pixel_addr : natural;
        variable palette_index : natural;
    begin
        if (x < IMAGE_WIDTH and y < IMAGE_HEIGHT) then
            pixel_addr := to_integer(y) * IMAGE_WIDTH + to_integer(x);
            palette_index := to_integer(image_data(pixel_addr)(2 downto 0));

            pixel_index <= resize(image_data(pixel_addr), pixel_index'length);
            color <= IMAGE_PALETTE(palette_index);
            valid <= '1';
        else
            pixel_index <= (others => '0');
            color <= (others => '0');
            valid <= '0';
        end if;
    end process;
    
end architecture rtl;
