"""Empaqueta los PNG de app/icono en app/Verdaria.ico (formato ICO con PNG incrustados)."""
import pathlib
import struct

here = pathlib.Path(__file__).resolve().parent
sizes = [16, 32, 48, 256]
images = [(s, (here / "icono" / f"icon_{s}.png").read_bytes()) for s in sizes]
header = struct.pack("<HHH", 0, 1, len(images))
offset = 6 + 16 * len(images)
entries = b""
data = b""
for size, png in images:
    dim = 0 if size >= 256 else size
    entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset + len(data))
    data += png
(here / "Verdaria.ico").write_bytes(header + entries + data)
print("Verdaria.ico listo")
