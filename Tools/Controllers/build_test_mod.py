"""Builds "Controller Fix", a test mod of KIF's C-SYS-08 Controllers (the pull
request to cody), so players can try the fix before it's in KIF: the PR's own
Controllers.rb, model list and licence, a loader, mod.json and a README, as a
.zip that KIF unpacks when it's dropped into the game's Mods folder.
Usage: python -I build_test_mod.py <KIF-Beta-PRs clone> <out .zip (must not exist)>"""
import os, sys, zipfile

clone, out = sys.argv[1:3]
if os.path.exists(out):
    sys.exit(f"{out} already exists: give a new name (nothing is replaced)")
VERSION = "0.1.1"
src = {
    "Controllers.rb": os.path.join(clone, "Data", "Scripts", "990_KIF", "ZZ_Cody", "C-SYS-08_Controllers", "Controllers.rb"),
    "controller_models.txt": os.path.join(clone, "Data", "KIF", "controller_models.txt"),
    "controller_models_LICENSE.txt": os.path.join(clone, "Data", "KIF", "controller_models_LICENSE.txt"),
}
for name, path in src.items():
    if not os.path.isfile(path):
        sys.exit(f"missing {path}")

mod_json = """{
  "name": "Controller Fix (Test)",
  "id": "ControllerFix",
  "version": "%s",
  "author": "Stonewall",
  "requires_kif": ">=0.21.0",
  "description": "Makes newer controllers work without Steam Input or DS4Windows, and lists every controller the game sees in Logs/KIF_log.txt. A test of a fix sent to KIF; does nothing once KIF has it.",
  "tags": ["QoL", "Test"],
  "dependencies": [],
  "incompatible": [],
  "scripts": ["Load.rb"]
}
""" % VERSION

load_rb = """# Controller Fix (test mod) %s: KIF's C-SYS-08 Controllers, the fix sent to
# KIF as a pull request, as a mod so it can be tried first. Its files are the
# pull request's own. Once KIF has the fix itself, this does nothing.
if defined?(KIF::Controllers)
  KIF.log("Controller Fix (test mod): KIF already has this fix, so the mod does nothing")
else
  here = File.dirname(__FILE__)
  load File.join(here, "Controllers.rb")
  KIF::Controllers.define_singleton_method(:models_path) { File.join(here, "controller_models.txt") }
  KIF.log("Controller Fix (test mod) %s: loaded")
end
""" % (VERSION, VERSION)

readme = """Controller Fix (Test) %s
==========================

What it does
------------
Some controllers don't work in KIF unless Steam Input or DS4Windows is running.
The game only uses a controller whose model is on a list built into it, and that
list is from 2021. This mod adds 141 newer models to it when the game starts
(8BitDo Ultimate, Ultimate 2C, Pro 3, Lite 2 and more). Controllers that already
work are left exactly as they are.

It also writes every controller the game sees into Logs/KIF_log.txt, with its
model number and whether the game can use it, and which one the game is using
(it uses one at a time, so another device can be in the way), so a controller
that still doesn't work can be looked up.

Install
-------
1. Close the game.
2. Put ControllerFix.zip in the game's Mods folder (next to InfiniteFusion.exe).
   Don't unzip it: the game does that the next time it starts.
3. Start the game.

Test
----
1. Close Steam and DS4Windows if they're running (including from the system tray).
2. Plug in your controller, then start the game.
3. At the title screen and the menus, try the buttons, both sticks and the triggers.
4. Close the game and send back Logs/KIF_log.txt (in the game folder), and say
   which controller you have and whether it worked.

The lines to look for start with "Controllers:". A controller the game can't use
shows as "not on the engine's controller list".

Remove
------
Delete the Mods/ControllerFix folder (or switch it off in KIF Settings > Mods).

The model list is altered from SDL_GameControllerDB (zlib licence, see
controller_models_LICENSE.txt).
""" % VERSION

with zipfile.ZipFile(out, "x", zipfile.ZIP_DEFLATED) as z:
    for name, path in src.items():
        z.write(path, "ControllerFix/" + name)
    z.writestr("ControllerFix/mod.json", mod_json)
    z.writestr("ControllerFix/Load.rb", load_rb)
    z.writestr("ControllerFix/README.txt", readme)
print("built", out)
with zipfile.ZipFile(out) as z:
    for i in z.infolist():
        print(f"  {i.filename:45} {i.file_size:7} bytes, method {i.compress_type}")
