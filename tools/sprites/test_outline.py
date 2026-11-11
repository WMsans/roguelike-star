# Run: python3 tools/sprites/test_outline.py
import os, struct, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from outline import outline_image


def png_bytes(rows):
    """RGBA8 PNG, filter 0, from a list of rows of (r, g, b, a) tuples."""
    h = len(rows)
    w = len(rows[0])
    raw = b"".join(b"\x00" + b"".join(bytes(p) for p in row) for row in rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw))
            + chunk(b"IEND", b""))


def png_rows(data):
    """(w, h, rows) for an RGBA8, non-interlaced PNG — all five filters."""
    pos, idat, ct = 8, b"", None
    w = h = 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, depth, ct, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and ct == 6 and interlace == 0
        elif kind == b"IDAT":
            idat += body
    raw = zlib.decompress(idat)
    stride, prev, out, p = w * 4, bytearray(w * 4), [], 0
    for _y in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out.append([tuple(line[i:i + 4]) for i in range(0, stride, 4)])
        prev = line
    return w, h, out


BASE = (200, 60, 40, 255)
DARK = (10, 10, 10, 255)
MID = (120, 80, 40, 255)


def test_ring_is_the_darkest_colour():
    rows = [[BASE] * 5 for _ in range(5)]
    rows[2][2] = DARK
    rows[1][1] = MID
    _w, _h, out = png_rows(outline_image(png_bytes(rows)))
    for y in range(5):
        for x in range(5):
            edge = x in (0, 4) or y in (0, 4)
            if edge:
                assert out[y][x] == DARK, (x, y, out[y][x])
    assert out[1][1] == MID, "an interior colour must stay"
    assert out[2][2] == DARK
    assert out[3][3] == BASE


def test_transparent_neighbour_is_outlined():
    rows = [[BASE] * 5 for _ in range(5)]
    rows[1][1] = (0, 0, 0, 0)
    rows[2][2] = DARK
    _w, _h, out = png_rows(outline_image(png_bytes(rows)))
    assert out[0][1] == DARK and out[2][1] == DARK, "the four neighbours of a hole are boundary"
    assert out[1][0] == DARK and out[1][2] == DARK
    assert out[1][1] == (0, 0, 0, 0), "transparent pixels stay transparent"
    assert out[0][0] == DARK, "a corner is an edge, out-of-image neighbours count"
    assert out[3][3] == BASE, "an interior pixel away from the hole keeps its colour"


def test_already_outlined_is_unchanged():
    rows = [[DARK if x in (0, 2) or y in (0, 2) else BASE for x in range(3)] for y in range(3)]
    data = png_bytes(rows)
    assert outline_image(data) == data, "a hand grid with a dark ring must round-trip byte for byte"


def test_single_pixel():
    data = png_bytes([[(5, 5, 5, 255)]])
    assert outline_image(data) == data


def test_wide_flat_sprite():
    rows = [[BASE] * 8 for _ in range(2)]
    rows[0][3] = DARK
    _w, _h, out = png_rows(outline_image(png_bytes(rows)))
    assert all(p == DARK for p in out[0] + out[1]), "a 2-row sprite is all boundary"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok", name)
    print("ALL PASS")
