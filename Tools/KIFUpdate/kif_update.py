"""Compares the local KIF Beta with cody's repo between two commits, and
(with --apply) backs up and replaces the changed files.
--skip=a,b leaves those paths out (cody's repo-only files: .gitattributes,
his release scripts), which aren't part of the game folder.
Usage: python kif_update.py <repo> <local KIF Beta> <old commit> <new commit> <backup dir> [--apply] [--skip=a,b]"""
import subprocess, sys, os, shutil

repo, local, old, new, backup = sys.argv[1:6]
apply = "--apply" in sys.argv
skip = set()
for a in sys.argv[6:]:
    if a.startswith("--skip="):
        skip.update(p for p in a[len("--skip="):].split(",") if p)

def git(*args, binary=False):
    out = subprocess.run(["git", "-C", repo] + list(args), capture_output=True, check=True)
    return out.stdout if binary else out.stdout.decode("utf-8", "replace")

def norm(b):
    return b.replace(b"\r\n", b"\n")

changes = []
for line in git("diff", "--name-status", "--no-renames", old, new).splitlines():
    status, path = line.split("\t", 1)
    if path in skip:
        print(f"{status} skipped          {path}")
        continue
    changes.append((status, path))

problems = []
for status, path in changes:
    full = os.path.join(local, path)
    if status == "A":
        state = "new" if not os.path.exists(full) else "EXISTS LOCALLY"
    else:
        if not os.path.exists(full):
            state = "MISSING LOCALLY"
        else:
            want = git("show", f"{old}:{path}", binary=True)
            have = open(full, "rb").read()
            state = "same as old" if norm(want) == norm(have) else "LOCALLY CHANGED"
    if state.isupper() or state.startswith("EXISTS") or state.startswith("MISSING"):
        problems.append((path, state))
    print(f"{status} {state:16} {path}")

print(f"\n{len(changes)} files, {len(problems)} need a look")
if not apply:
    sys.exit(0)
if problems and "--force" not in sys.argv:
    print(f"not applying: files differ from {old}")
    sys.exit(1)
for status, path in changes:
    full = os.path.join(local, path)
    if os.path.exists(full):
        dest = os.path.join(backup, path)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(full, dest)
    if status == "D":
        os.remove(full)
        continue
    data = git("show", f"{new}:{path}", binary=True)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "wb") as f:
        f.write(data)
print("applied; old copies in", backup)
