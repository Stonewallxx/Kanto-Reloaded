"""Builds Kanto Reloaded's list of newer controller models for the engine's
SDL 2.0.12: SDL's current Windows entries (SDL_GameControllerDB) for models
the engine doesn't already know, rewritten the way SDL 2.0.12 names a
device (bus 0003, vendor, product, no version or name check), and trimmed
of fields it doesn't know. Purely additive: a model the engine knows is
never touched. --kif writes KIF's copy (its header).
Usage: python -I pad_models.py <engine exe> <gamecontrollerdb.txt> <out file> [--report] [--kif]"""
import datetime, re, sys

exe, db, out = sys.argv[1:4]
report = "--report" in sys.argv
OLD_FIELDS = {"platform", "crc", "hint", "sdk>=", "sdk<=", "misc1", "misc2", "misc3", "misc4", "misc5", "misc6",
              "paddle1", "paddle2", "paddle3", "paddle4", "touchpad"}
XINPUT = "78696e707574"           # "xinput": SDL handles those itself

def vidpid(guid):
    """(bus, vendor, product) for the VID/PID kind of GUID, else None."""
    if len(guid) != 32 or not re.fullmatch(r"[0-9a-f]{32}", guid) or guid.startswith(XINPUT):
        return None
    b = bytes.fromhex(guid)
    bus = b[0] | b[1] << 8
    if bus not in (0x03, 0x05) or b[6:8] != b"\0\0" or b[10:12] != b"\0\0" or b[14:16] != b"\0\0":
        return None
    return bus, b[4] | b[5] << 8, b[8] | b[9] << 8

def engine_known():
    data = open(exe, "rb").read()
    known, lines = set(), 0
    for m in re.finditer(rb"([0-9a-f]{32}),([^,\x00]{1,80}),([\x20-\x7e]{10,600})", data):
        rest = m.group(3).decode("latin-1")
        plat = re.search(r"platform:([A-Za-z ]+)", rest)
        if plat and plat.group(1) != "Windows":
            continue
        k = vidpid(m.group(1).decode())
        if k:
            known.add(k[1:])
            lines += 1
    return known, lines

known, known_lines = engine_known()
entries = []
for raw in open(db, encoding="utf-8"):
    line = raw.strip()
    if not line or line.startswith("#") or "platform:Windows" not in line:
        continue
    guid, name, *fields = line.split(",")
    k = vidpid(guid)
    if not k:
        continue
    entries.append((k, name, [f for f in fields if f and f.split(":", 1)[0] not in OLD_FIELDS]))

chosen, order = {}, []
for want_bus in (0x03, 0x05):            # a USB entry before a Bluetooth one for the same model
    for (bus, vid, pid), name, fields in entries:
        if bus != want_bus or (vid, pid) in known or (vid, pid) in chosen:
            continue
        chosen[(vid, pid)] = (name, fields)
        order.append((vid, pid))

def le(x):
    return "%02x%02x" % (x & 0xFF, x >> 8)

with open(out, "w", encoding="utf-8", newline="\n") as f:
    if "--kif" in sys.argv:          # KIF's own copy (Data/KIF/controller_models.txt)
        f.write("# Newer controller models for KIF's engine (SDL 2.0.12), added at start-up by C-SYS-08_Controllers.\n")
        lic, tool = "controller_models_LICENSE.txt", "Kanto Reloaded's pad_models.py"
    else:
        f.write("# Newer controller models for KIF Beta's engine (SDL 2.0.12), added at start-up by PadSDL.rb.\n")
        lic, tool = "ControllerModels_LICENSE.txt", "Tools/Controllers/pad_models.py"
    f.write("# ALTERED from SDL_GameControllerDB (https://github.com/mdqinc/SDL_GameControllerDB), zlib licence:\n")
    f.write("# see %s. Its Windows entries for models the engine doesn't already know,\n" % lic)
    f.write("# rewritten the way SDL 2.0.12 names a device (bus 0003, no version or CRC; fields it doesn't know\n")
    f.write("# taken out). Made %s with %s.\n" % (datetime.date.today().isoformat(), tool))
    for vid, pid in sorted(order, key=lambda k: chosen[k][0].lower()):
        name, fields = chosen[(vid, pid)]
        f.write("03000000%s0000%s000000000000,%s,%s,\n" % (le(vid), le(pid), name, ",".join(fields)))

print(f"engine knows {len(known)} models ({known_lines} Windows lines); SDL's list has {len(entries)} Windows entries")
print(f"added: {len(order)} models -> {out}")
if report:
    for vid, pid in order[:25]:
        print(f"  {vid:04x}:{pid:04x}  {chosen[(vid, pid)][0]}")
    for probe in [(0x054c, 0x0ce6), (0x054c, 0x05c4), (0x054c, 0x09cc), (0x045e, 0x0b13), (0x057e, 0x2009), (0x2dc8, 0x6003)]:
        print(f"  {probe[0]:04x}:{probe[1]:04x}", "engine knows it" if probe in known else ("added" if probe in chosen else "neither"))
