# Wrapper around randscreen_backdrop.py for KR's mockups: adds a custom page
# "kr" (title "Randomizer: Kanto Reloaded", rows only from --extra-rows) and,
# on the main screen, a "Kanto Reloaded (On)" page button after Pokémon data
# (copied from an existing page button's row, so it's drawn the same way).
import sys, os
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(HERE, "randscreen_backdrop.py"), encoding="utf-8").read()
src = src.replace("def build_page(name):\n    pages = page_defs()",
 "def build_page(name):\n    if name == 'kr':\n        return 'Randomizer: Kanto Reloaded', 'Randomizer parts added by Kanto Reloaded.', 'GREEN', []\n    pages = page_defs()", 1)
src = src.replace("    return title, default_desc, rows\n",
 "    if os.environ.get('KR_MAIN_BUTTON'):\n"
 "        import copy\n"
 "        k = next(i for i, r in enumerate(rows) if r.get('page') == 'data')\n"
 "        o = copy.deepcopy(rows[k]); o['page'] = 'kr'\n"
 "        o['name'] = 'Kanto Reloaded (On)'; o['desc'] = 'Per-Pokémon abilities, random learnsets and Expanded Pokémon, added by Kanto Reloaded.'\n"
 "        rows.insert(k + 1, o)\n"
 "    return title, default_desc, rows\n", 1)
sys.argv[0] = os.path.join(HERE, "randscreen_backdrop.py")
os.chdir(HERE)
exec(compile(src, sys.argv[0], "exec"))
