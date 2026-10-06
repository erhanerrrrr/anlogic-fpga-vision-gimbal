"""Independent integer rule. No hardware-width arithmetic or DUT-derived expected values."""
def classify(rgb, color, limits=(80, 40, 40)):
    if color not in (0, 1, 2):
        return 0
    dominant = rgb[color]
    others = [value for index, value in enumerate(rgb) if index != color]
    return int(dominant >= limits[0] and
               dominant - others[0] >= limits[1] and
               dominant - others[1] >= limits[2])
