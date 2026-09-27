#!/usr/bin/env bash
#
# rename-scans.sh — rename scanned PDFs using Claude Code CLI
#
# Name format:  YYYY-mm-dd - Sender - Reason - Recipient.pdf
#   e.g.        2026-03-14 - SoCal Edison - Electricity bill - House.pdf
#               2026-06-02 - Desert Vet - Annual vaccines - Sardine and Red.pdf
#               2026-08-20 - California DMV - Registration renewal - Vehicle F350.pdf
#
# Usage:  rename-scans.sh [-n] [-f] [-m model] [folder]
#   -n   dry run: show what would be renamed, change nothing
#   -f   also process files that already look renamed (start with a date)
#   -m   Claude model alias (e.g. haiku, sonnet). Default: CLI default
#   folder defaults to ~/scans
#
# Needs: claude (Claude Code CLI, logged in), pdftotext + pdfinfo (poppler), jq, iconv
#   macOS: brew install poppler jq      Arch: sudo pacman -S poppler jq
# Works with the stock macOS bash 3.2 as well as bash 4/5.

set -uo pipefail

# ---------- settings ----------
MAX_SENDER=30
MAX_REASON=40
MAX_TOTAL=110          # length of the name without ".pdf"
MIN_TEXT_CHARS=80      # below this, the PDF is treated as image-only and Claude reads the file itself
TEXT_PAGES=3           # pages of text sent to Claude (sender/date are almost always up front)

DRY_RUN=0
FORCE=0
MODEL="${CLAUDE_MODEL:-}"

while getopts ":nfm:h" opt; do
  case $opt in
    n) DRY_RUN=1 ;;
    f) FORCE=1 ;;
    m) MODEL="$OPTARG" ;;
    h) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option. Use -h for help." >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
DIR="${1:-$HOME/scans}"

# ---------- colors ----------
if [[ -t 1 ]]; then
  RED=$'\e[1;31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; DIM=$'\e[2m'; RESET=$'\e[0m'
else
  RED=""; GREEN=""; YELLOW=""; DIM=""; RESET=""
fi

flag() { printf '%s✗ %s%s\n' "$RED" "$1" "$RESET"; [[ -n "${2:-}" ]] && printf '%s    %s%s\n' "$RED" "$2" "$RESET"; }

# ---------- checks ----------
for cmd in claude pdftotext pdfinfo jq iconv; do
  command -v "$cmd" >/dev/null || { echo "${RED}Missing dependency: $cmd${RESET}" >&2; exit 1; }
done
[[ -d "$DIR" ]] || { echo "${RED}Folder not found: $DIR${RESET}" >&2; exit 1; }

# Model flag kept as plain words (bash 3.2 on macOS treats an empty array as unbound under set -u).
MODEL_FLAG=""
[[ -n "$MODEL" ]] && MODEL_FLAG="--model=$MODEL"

# ---------- prompt ----------
read -r -d '' PROMPT <<'EOF'
You are naming scanned household documents. Extract the fields below and reply with ONLY one JSON object: no prose, no code fences.

{"date": "YYYY-MM-DD or null", "sender": "string or null", "reason": "string or null", "recipient": ["..."] or null, "vehicle": "string or null"}

Rules:
- date: the date the document was issued or sent (letter date, invoice date, statement date). Not a due date, service period or print date. null if there is none.
- sender: the organization or person who sent it, using its short common name (e.g. "SoCal Edison", "Hydro-Quebec", "Desert Vet Clinic"). At most 4 words.
- reason: what the document is about, 2 to 5 words (e.g. "Electricity bill", "Annual vaccines", "Registration renewal", "Tax assessment").
- recipient: who or what the document concerns. Allowed values only: "Amelie", "Patrick", "Red", "Sardine", "Vehicle", "House".
  * Red and Sardine are dogs: vet bills, pet licenses, pet insurance, grooming go to the dog concerned.
  * "House": property, utilities, HOA, home insurance, property tax, home repairs.
  * "Vehicle": anything about a car, truck or camper (registration, insurance, repair, loan).
  * A personal document addressed jointly to Amelie and Patrick: list both.
- vehicle: only when recipient is "Vehicle": which vehicle, short (e.g. "F350", "Scout Kenai", or make and model from the document). Otherwise null.
- Use null for anything you cannot determine with reasonable confidence. Do not guess.
EOF

# ---------- helpers ----------

# Clean a name section: accents -> ASCII, keep letters/digits only, words separated by single spaces, length capped.
clean() {
  local s="$1" max="$2" t
  # French/Spanish accents first (works in any locale), then iconv for anything else.
  s=$(printf '%s' "$s" | sed 's/à/a/g; s/â/a/g; s/ä/a/g; s/á/a/g; s/ã/a/g; s/À/A/g; s/Â/A/g; s/Ä/A/g; s/Á/A/g; s/Ã/A/g; s/é/e/g; s/è/e/g;
    s/ê/e/g; s/ë/e/g; s/É/E/g; s/È/E/g; s/Ê/E/g; s/Ë/E/g; s/î/i/g; s/ï/i/g; s/í/i/g; s/Î/I/g; s/Ï/I/g; s/Í/I/g;
    s/ô/o/g; s/ö/o/g; s/ó/o/g; s/õ/o/g; s/Ô/O/g; s/Ö/O/g; s/Ó/O/g; s/Õ/O/g; s/ù/u/g; s/û/u/g; s/ü/u/g; s/ú/u/g;
    s/Ù/U/g; s/Û/U/g; s/Ü/U/g; s/Ú/U/g; s/ç/c/g; s/Ç/C/g; s/ñ/n/g; s/Ñ/N/g; s/œ/oe/g; s/Œ/OE/g; s/æ/ae/g; s/Æ/AE/g')
  t=$(printf '%s' "$s" | LC_ALL=C.UTF-8 iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null) && s="$t"
  s=$(printf '%s' "$s" | tr -c 'A-Za-z0-9' ' ' | tr -s ' ')
  s="${s#"${s%%[! ]*}"}"; s="${s%"${s##*[! ]}"}"   # trim
  s="${s:0:max}"
  s="${s% }"
  printf '%s' "$s"
}

# Scan date: PDF CreationDate (ISO form from pdfinfo), else file modification date.
# Works with GNU date (Linux) and BSD date (macOS).
scan_date() {
  local f="$1" cd
  cd=$(pdfinfo -isodates "$f" 2>/dev/null | sed -n 's/^CreationDate:[[:space:]]*//p')
  cd="${cd:0:10}"
  if valid_date "$cd"; then
    printf '%s' "$cd"
  else
    cd=$(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null)     # macOS / BSD
    valid_date "$cd" || cd=$(date -r "$f" '+%Y-%m-%d')      # Linux / GNU
    printf '%s' "$cd"
  fi
}

valid_date() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
  local d
  d=$(date -j -f '%Y-%m-%d' "$1" '+%Y-%m-%d' 2>/dev/null) ||   # macOS / BSD
    d=$(date -d "$1" '+%Y-%m-%d' 2>/dev/null)                  # Linux / GNU
  [[ "$d" == "$1" ]]   # rejects impossible dates like 2026-02-30
}

ERR_FILE=$(mktemp); trap 'rm -f "$ERR_FILE"' EXIT
RETRIES=3

# One claude call. stdout = the model's reply text. On failure, the reason is left in $ERR_FILE.
claude_once() {
  local f="$1" text="$2" out rc
  : >"$ERR_FILE"
  if [[ -n "$text" ]]; then
    out=$(printf '%s' "$text" | env -u CLAUDECODE claude -p "$PROMPT

The document text is provided on stdin." \
          --output-format json ${MODEL_FLAG:+"$MODEL_FLAG"} 2>"$ERR_FILE"); rc=$?
  else
    # Image-only scan (no OCR layer): let Claude open the PDF itself.
    out=$(env -u CLAUDECODE claude -p "$PROMPT

Read the PDF file at: $f" \
          --allowedTools Read --add-dir "$(dirname "$f")" \
          --output-format json ${MODEL_FLAG:+"$MODEL_FLAG"} </dev/null 2>"$ERR_FILE"); rc=$?
  fi

  # A JSON envelope with is_error / a non-success subtype carries the real reason in .result.
  if jq -e 'type == "object"' <<<"$out" >/dev/null 2>&1; then
    if [[ "$(jq -r '.is_error // false' <<<"$out")" == "true" || "$(jq -r '.subtype // "success"' <<<"$out")" != "success" ]]; then
      jq -r '.result // .api_error_status // .subtype // "no details"' <<<"$out" >"$ERR_FILE"
      return 1
    fi
    jq -r '.result // empty' <<<"$out"
    return 0
  fi

  # Not JSON: keep whatever claude printed so it can be shown.
  { [[ -s "$ERR_FILE" ]] && cat "$ERR_FILE"; printf '%s' "$out"; echo " (exit $rc)"; } >"$ERR_FILE.tmp"
  mv "$ERR_FILE.tmp" "$ERR_FILE"
  return 1
}

# Ask Claude about one PDF, retrying transient errors (overload, rate limit, network).
ask_claude() {
  local f="$1" text attempt=1 reply
  text=$(pdftotext -l "$TEXT_PAGES" -layout "$f" - 2>/dev/null | head -c 15000)
  (( $(printf '%s' "$text" | tr -d '[:space:]' | wc -c) < MIN_TEXT_CHARS )) && text=""

  while :; do
    if reply=$(claude_once "$f" "$text") && [[ -n "$reply" ]]; then
      printf '%s' "$reply"; return 0
    fi
    [[ -s "$ERR_FILE" ]] || echo "empty reply" >"$ERR_FILE"
    # Usage limit or auth problem: retrying won't help.
    grep -qiE 'usage limit|limit reached|log ?in|auth|api key|credit' "$ERR_FILE" && return 2
    (( attempt >= RETRIES )) && return 1
    sleep $(( attempt * ${RETRY_WAIT:-10} ))
    ((attempt++))
  done
}

# ---------- main loop ----------
renamed=0; flagged=0; skipped=0
NAMED_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}( - |-)'   # already renamed (new or old style)

while IFS= read -r -d '' f <&3; do
  name=$(basename "$f")

  if (( ! FORCE )) && [[ "$name" =~ $NAMED_RE ]]; then
    printf '%s• skip (already named): %s%s\n' "$DIM" "$name" "$RESET"
    ((skipped++)); continue
  fi

  printf '… %s\n' "$name"

  reply=$(ask_claude "$f"); rc=$?
  if (( rc != 0 )); then
    why=$(tr '\n' ' ' <"$ERR_FILE" | cut -c1-300)
    flag "$name" "Claude call failed: $why"; ((flagged++))
    if (( rc == 2 )); then
      echo "${RED}Stopping: this looks like a login or usage-limit problem, so the other files would fail too.${RESET}"
      break
    fi
    continue
  fi

  # Pull the JSON object out of the reply, tolerating stray text or code fences.
  obj=$(printf '%s' "$reply" | tr '\n' ' ' | sed -E 's/^[^{]*//; s/[^}]*$//')
  if ! jq -e 'type == "object"' <<<"$obj" >/dev/null 2>&1; then
    flag "$name" "Unreadable reply: ${reply:0:120}"; ((flagged++)); continue
  fi

  get() { jq -r "$1 // empty | select(. != \"null\")" <<<"$obj"; }
  doc_date=$(get '.date')
  sender=$(get '.sender')
  reason=$(get '.reason')
  vehicle=$(get '.vehicle')
  recipients=$(jq -r 'if (.recipient|type)=="array" then .recipient[] elif .recipient then .recipient else empty end' <<<"$obj")

  # Date: document date, else scan date (not a reason to flag).
  if valid_date "$doc_date"; then
    date_part="$doc_date"
  else
    date_part=$(scan_date "$f")
    printf '%s    no date in document, using scan date %s%s\n' "$YELLOW" "$date_part" "$RESET"
  fi

  # Recipient(s): only the allowed values.
  rcpt_list=""; bad_rcpt=""
  while IFS= read -r r; do
    [[ -z "$r" ]] && continue
    case "$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]')" in
      amelie|amélie) p="Amelie" ;;
      patrick)       p="Patrick" ;;
      red)           p="Red" ;;
      sardine)       p="Sardine" ;;
      house)         p="House" ;;
      vehicle)
        v=$(clean "$vehicle" 20)
        if [[ -z "$v" ]]; then bad_rcpt="vehicle not identified"; continue; fi
        p="Vehicle $v" ;;
      *) bad_rcpt="unexpected recipient '$r'"; continue ;;
    esac
    [[ "|$rcpt_list|" == *"|$p|"* ]] || rcpt_list="${rcpt_list:+$rcpt_list|}$p"
  done <<<"$recipients"

  # "Amelie|Patrick|Red" -> "Amelie, Patrick and Red"
  rcpt_part="${rcpt_list//|/, }"
  [[ "$rcpt_part" == *", "* ]] && rcpt_part="${rcpt_part%, *} and ${rcpt_part##*, }"

  sender_part=$(clean "$sender" "$MAX_SENDER")
  reason_part=$(clean "$reason" "$MAX_REASON")

  missing=""
  [[ -z "$sender_part" ]] && missing="$missing sender"
  [[ -z "$reason_part" ]] && missing="$missing reason"
  [[ -z "$rcpt_part"   ]] && missing="$missing recipient${bad_rcpt:+ ($bad_rcpt)}"
  if [[ -n "$missing" ]]; then
    flag "$name" "Missing:$missing — not renamed"; ((flagged++)); continue
  fi

  SEP=" - "
  base="${date_part}${SEP}${sender_part}${SEP}${reason_part}${SEP}${rcpt_part}"
  # Keep the total length reasonable: shorten the reason first.
  if (( ${#base} > MAX_TOTAL )); then
    over=$(( ${#base} - MAX_TOTAL ))
    keep=$(( ${#reason_part} - over )); (( keep < 10 )) && keep=10
    reason_part="${reason_part:0:keep}"; reason_part="${reason_part% }"
    base="${date_part}${SEP}${sender_part}${SEP}${reason_part}${SEP}${rcpt_part}"
    base="${base:0:MAX_TOTAL}"; base="${base%" - "}"; base="${base%" -"}"; base="${base% }"
  fi

  # Never overwrite: add (2), (3)… if the name is taken.
  target="$DIR/$base.pdf"; n=2
  while [[ -e "$target" ]]; do target="$DIR/$base ($n).pdf"; ((n++)); done

  if (( DRY_RUN )); then
    printf '%s  → %s (dry run)%s\n' "$GREEN" "$(basename "$target")" "$RESET"
  else
    mv -n -- "$f" "$target" && printf '%s  → %s%s\n' "$GREEN" "$(basename "$target")" "$RESET"
  fi
  ((renamed++))

done 3< <(find "$DIR" -maxdepth 1 -type f -iname '*.pdf' -print0 | sort -z)

echo
printf '%sRenamed: %d%s   %sFlagged: %d%s   Skipped: %d\n' \
  "$GREEN" "$renamed" "$RESET" "$RED" "$flagged" "$RESET" "$skipped"
(( flagged == 0 ))