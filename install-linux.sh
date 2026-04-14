#!/usr/bin/env bash
# Installs the Finner XKB layout as a variant of the Finnish (fi) layout.
# Requires sudo. Tested on Ubuntu 24.04 LTS.

set -euo pipefail

SYMBOLS_DIR="/usr/share/X11/xkb/symbols"
RULES_DIR="/usr/share/X11/xkb/rules"

if [[ $EUID -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi

# Resolve the finner symbols file relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FINNER_SYMBOLS="$SCRIPT_DIR/finner"

echo "==> Installing finner variant into $SYMBOLS_DIR/fi"
FI_FILE="$SYMBOLS_DIR/fi"
if grep -q 'xkb_symbols "finner"' "$FI_FILE"; then
    echo "    finner block already present in fi, skipping"
else
    cp "$FI_FILE" "$FI_FILE.finner.bak"
    echo "" >> "$FI_FILE"
    cat "$FINNER_SYMBOLS" >> "$FI_FILE"
fi

echo "==> Registering variant in evdev.xml"
EVDEV_XML="$RULES_DIR/evdev.xml"
if grep -q '<name>finner</name>' "$EVDEV_XML"; then
    echo "    already registered, skipping"
else
    cp "$EVDEV_XML" "$EVDEV_XML.finner.bak"
    python3 - "$EVDEV_XML" <<'PY'
import sys, re
path = sys.argv[1]
with open(path) as f:
    data = f.read()
variant = """      <variant>
        <configItem>
          <name>finner</name>
          <description>Finnish (Finner)</description>
        </configItem>
      </variant>
"""
pattern = re.compile(
    r'(<layout>\s*<configItem>\s*<name>fi</name>.*?<variantList>\s*)',
    re.DOTALL,
)
new, n = pattern.subn(lambda m: m.group(1) + variant, data, count=1)
if n != 1:
    sys.exit("could not locate <variantList> for fi layout in evdev.xml")
with open(path, "w") as f:
    f.write(new)
PY
fi

echo "==> Registering variant in evdev.lst"
EVDEV_LST="$RULES_DIR/evdev.lst"
if grep -qE '^\s*finner\s' "$EVDEV_LST"; then
    echo "    already registered, skipping"
else
    cp "$EVDEV_LST" "$EVDEV_LST.finner.bak"
    awk '
        BEGIN { inserted = 0 }
        /^! variant/ { in_variant = 1; print; next }
        /^!/ { in_variant = 0 }
        in_variant && !inserted && /^[[:space:]]*[^[:space:]]+[[:space:]]+fi:/ {
            print "  finner          fi: Finnish (Finner)"
            inserted = 1
        }
        { print }
    ' "$EVDEV_LST" > "$EVDEV_LST.tmp" && mv "$EVDEV_LST.tmp" "$EVDEV_LST"
fi

echo
echo "Done. Log out and log back in, then add 'Finnish (Finner)'"
echo "from Settings -> Keyboard -> Input Sources."
echo
echo "To try it in the current X session without logging out:"
echo "    setxkbmap -layout fi -variant finner"
