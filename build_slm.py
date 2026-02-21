import re, sys

SRC  = r"C:\Users\Etien\Documents\SITES&PLUGINS\plugins\Simloadmanager\WIP\GITHUB\SimLoadManager.lua"
DEST = SRC

with open(SRC, encoding="utf-8") as f:
    content = f.read()

lines = content.splitlines()

# ── 1. Remove purely decorative inline comment lines ─────────────────────────
# Lines that are ONLY a comment (stripped starts with --) and are NOT:
#   a) section separator lines (80 dashes)
#   b) the version line (--SIMLOAD MANAGER)
#   c) a few important keeper comments (see KEEPERS set)

KEEPERS = {
    "-- set to true to show [DEV] button in UI",
    "-- passed_1000ft is intentionally not persisted (always starts fresh as Departure)",
    "-- no longer persisted between sessions (always starts in Departure mode)",
    "-- Cargo management",
    "-- Pax management",
    "-- Fuel management",
    "-- External sounds: louder outside, quieter inside",
    "-- Internal sounds: audible only from inside (pax, briefing, catering, cleaning)",
}

SECTION_DASH = re.compile(r"^-{60,}$")

cleaned = []
for line in lines:
    stripped = line.strip()
    # keep blank lines, non-comment lines, section dashes, version header
    if not stripped.startswith("--"):
        cleaned.append(line)
        continue
    if stripped.startswith("--SIMLOAD"):
        cleaned.append(line)
        continue
    if SECTION_DASH.match(stripped):
        cleaned.append(line)
        continue
    # keep section title lines (-- SOMETHING in all caps or mixed after dashes)
    if stripped in KEEPERS:
        cleaned.append(line)
        continue
    # REMOVE: -- SECTION: xxx  / -- Case X: / -- Note: / -- Deploy / -- Only call
    # i.e. standalone comment lines that are just descriptive noise
    # Strategy: if the line is ONLY a comment (no code), remove it
    # EXCEPTION: keep lines that start with "-- !" or are TODO/FIXME (none here)
    cleaned.append(line)   # conservative: keep everything for now, do targeted removes below

# ── 2. Targeted removal of known noisy comment patterns ──────────────────────
REMOVE_PATTERNS = [
    re.compile(r"^\s*-- SECTION:\s.*$"),
    re.compile(r"^\s*-- Case [A-Z]:.*$"),
    re.compile(r"^\s*-- Derived planned masses.*$"),
    re.compile(r"^\s*-- Keep existing behavior.*$"),
    re.compile(r"^\s*-- Deploy stairs/jetway.*$"),
    re.compile(r"^\s*-- Deploy ground crew.*$"),
    re.compile(r"^\s*-- Only call if crew.*$"),
    re.compile(r"^\s*-- INITIAL FUEL CAPTURE\s*$"),
    re.compile(r"^\s*-- Note:.*$"),
    re.compile(r"^\s*-- Derived.*$"),
    re.compile(r"^\s*-- If a turnaround.*$"),
    re.compile(r"^\s*-- External sounds.*$"),
    re.compile(r"^\s*-- Internal sounds.*$"),
    re.compile(r"^\s*-- Default custom values.*$"),
    re.compile(r"^\s*-- Current timing \(set by.*$"),
    re.compile(r"^\s*-- SGES.*$"),
    re.compile(r"^\s*-- Custom preset.*$"),
    re.compile(r"^\s*-- Auto-import turnaround\s*$"),
    re.compile(r"^\s*-- Session mode tracker.*$"),
    re.compile(r"^\s*-- Crew Briefing\s*$"),
    re.compile(r"^\s*-- Catering\s*$"),
    re.compile(r"^\s*-- Cleaning\s*$"),
    re.compile(r"^\s*-- Crew Deplane.*$"),
]

final = []
for line in cleaned:
    stripped = line.strip()
    if stripped.startswith("--") and not SECTION_DASH.match(stripped) and not stripped.startswith("--SIMLOAD"):
        skip = False
        for pat in REMOVE_PATTERNS:
            if pat.match(line):
                skip = True
                break
        if skip:
            continue
    final.append(line)

result = "\n".join(final) + "\n"
with open(DEST, "w", encoding="utf-8") as f:
    f.write(result)

print(f"Done. {len(lines)} -> {len(final)} lines")
