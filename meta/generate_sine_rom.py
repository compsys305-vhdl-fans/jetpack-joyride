import math

def generate_sine_rom():
    entries = 256
    amplitude = 127
    
    values = []
    for i in range(entries):
        val = int(round(amplitude * math.sin(2 * math.pi * i / entries)))
        values.append(f"TO_SIGNED({val}, 8)")
        
    print("    TYPE sine_rom_type IS ARRAY(0 TO 255) OF SIGNED(7 DOWNTO 0);")
    print("    CONSTANT SINE_ROM : sine_rom_type := (")
    
    lines = []
    for i in range(0, len(values), 8):
        lines.append("        " + ", ".join(values[i:i+8]))
        
    print(",\n".join(lines))
    print("    );")

if __name__ == "__main__":
    generate_sine_rom()