"""One deterministic dark outline around a sprite's opaque silhouette. Python stdlib only.

The outline the sprite workflow gets from the image model is uneven: some silhouette edges come back
dark, others keep the object's colour, and on tiny sprites the model fills the empty space with the
outline colour instead. This pass derives the outline from the silhouette instead: every opaque pixel
that touches an empty pixel (alpha below 50%, the engine's own cut) or the image edge becomes the
sprite's darkest colour. The opaque set, and so the body PixelRigidBody builds, does not change.

  python3 tools/sprites/outline.py textures/sprites/*.png    # rewrites each file in place

gen_sprite.py runs outline_image() on every sprite it downloads, so new sprites arrive outlined.
"""
import struct, sys, zlib

OPAQUE = 128  # alpha at and above this is solid, the engine's own cut (a < 0.5 is empty)


def _decode(data):
    """RGBA8, non-interlaced PNG bytes -> (width, height, rows of [r, g, b, a] bytes)."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, header = 8, b"", None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
    if header is None:
        raise ValueError("no IHDR")
    w, h, depth, colour, compression, filtering, interlace = header
    if (depth, colour, compression, filtering, interlace) != (8, 6, 0, 0, 0):
        raise ValueError("only 8-bit RGBA, non-interlaced PNGs are supported")
    raw = zlib.decompress(idat)
    stride, prev, rows, p = w * 4, bytearray(w * 4), [], 0
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
        rows.append(line)
        prev = line
    return w, h, rows


def _encode(w, h, rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw))
            + chunk(b"IEND", b""))


def outline_image(data):
    """The PNG with every opaque boundary pixel set to the darkest opaque colour in the image.

    Opaque is alpha >= 128, the engine's own cut (PixelRigidBody treats a < 0.5 as empty), so a
    faint anti-aliased edge cannot grow the collision silhouette. The ring is written solid.
    """
    w, h, rows = _decode(data)
    darkest, best = None, None
    for row in rows:
        for i in range(0, w * 4, 4):
            if row[i + 3] < OPAQUE:
                continue
            lum = 0.299 * row[i] + 0.587 * row[i + 1] + 0.114 * row[i + 2]
            if best is None or lum < best:
                darkest, best = bytes(row[i:i + 3]) + b"\xff", lum
    if darkest is None:
        return data
    out = list(rows)
    for y in range(h):
        row = rows[y]
        for x in range(w):
            at = x * 4
            if row[at + 3] < OPAQUE:
                continue
            edge = (x == 0 or rows[y][at - 1] < OPAQUE
                    or x == w - 1 or rows[y][at + 7] < OPAQUE
                    or y == 0 or rows[y - 1][at + 3] < OPAQUE
                    or y == h - 1 or rows[y + 1][at + 3] < OPAQUE)
            if edge:
                if out[y] is rows[y]:
                    out[y] = bytearray(row)
                out[y][at:at + 4] = darkest
    return _encode(w, h, out)


def main():
    paths = sys.argv[1:]
    if not paths:
        sys.exit("usage: outline.py <sprite.png>...")
    for path in paths:
        with open(path, "rb") as f:
            data = f.read()
        try:
            data = outline_image(data)
        except (ValueError, zlib.error) as e:
            sys.exit(f"error: {path}: {e}")
        with open(path, "wb") as f:
            f.write(data)
        print(path)


if __name__ == "__main__":
    main()
