# pipcl's wdev.py guesses Python's libs directory as `<include>/../libs`, but
# conda-forge Python 3.15+ on Windows puts headers in `include/python/`, so the
# guess points at a nonexistent directory and linking _mupdf.pyd fails with
# LNK1104 (cannot open python3XX.lib). Fall back to `libs` next to python.exe.
#
# This edits the copy of pipcl installed in the host environment, so it only
# affects this build. Drop it once conda-forge's pipcl carries the fix.
import importlib.util
import os

spec = importlib.util.find_spec("pipcl")
path = os.path.join(os.path.dirname(spec.origin), "wdev.py")

with open(path) as f:
    text = f.read()

old = "        self.libs = os.path.abspath(f'{self.include}/../libs')\n"
new = old + (
    "        if not os.path.isdir(self.libs):\n"
    "            self.libs = os.path.abspath(f'{os.path.dirname(self.path)}/libs')\n"
)

if new in text:
    print(f"{path} already patched")
else:
    assert text.count(old) == 1, f"unexpected contents in {path}"
    with open(path, "w") as f:
        f.write(text.replace(old, new))
    print(f"patched {path}")
