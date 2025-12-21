#!/usr/bin/env bash
#
# Andrea Alberti (MIT license, 2025)
#
# term_query.sh — query cursor shape (DECRQSS " q"), blink (DECRQM ?12), and CSI u support, a few useful modes via DECRQM
#
# Usage: ./term_query.sh [--passthrough]
#   --passthrough   Wrap queries for tmux passthrough (if inside tmux)
#
# For the documentation about XTerm Control Sequences, check: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html

set -euo pipefail

want_passthrough=0
for a in "${@:+"$@"}"; do
  case "$a" in
    --passthrough) want_passthrough=1 ;;
  esac
done

echo "Preparing terminal..."
stty_orig=$(stty -g)
stty -echo -icanon time 0 min 0

# --- Sequences ---
DECRQSS_CURSOR=$'\eP$q q\e\\'   # DCS $ q  q ST    (cursor shape)
DECRQM_BLINK=$'\e[?12$p'        # CSI ? 12 $ p     (report blink mode)
CSIU_QUERY=$'\e[?u'             # CSI ? u          (query CSI u / keyboard enhancement)
CSIDA1=$'\e[0c'                 # CSI 0 c          (query DA1 — primary Device Attributes)
CSIDA2=$'\e[>0c'                # CSI > 0 c        (query DA2 — secondary Device Attributes)
CSIDA3=$'\e[=0c'                # CSI > 0 c        (query DA3 — tertiary Device Attributes)
DECRQM_BRACKETED=$'\e[?2004$p'  # CSI ? 2004 $ p   (bracketed paste)
DECRQM_FOCUS=$'\e[?1004$p'      # CSI ? 1004 $ p   (focus tracking)
DECRQM_SGR=$'\e[?1006$p'        # CSI ? 1006 $ p   (SGR mouse)

QUERIES=(
  "${DECRQSS_CURSOR}"
  "${DECRQM_BLINK}"
  "${CSIU_QUERY}"
  "${CSIDA1}"
  "${CSIDA2}"
  "${CSIDA3}"
  "${DECRQM_BRACKETED}"
  "${DECRQM_FOCUS}"
  "${DECRQM_SGR}"
)

# tmux passthrough wrapper (DCS Ptmux; ESC ... ST)
wrap_tmux() {
  printf $'\ePtmux;\e%s\e\\' "$1"
}

restore_passthrough=''
cleanup() {
  if [[ -n "${restore_passthrough}" ]]; then
    tmux set-option -p allow-passthrough "${restore_passthrough}" >/dev/null 2>&1 || true
  fi
  stty "$stty_orig"
  echo "Test finished."
}
trap cleanup EXIT

send() {
  # $1 = sequence
  if (( want_passthrough )) && [[ -n "${TMUX-}" ]]; then
    printf "%s" "$(wrap_tmux "$1")" > /dev/tty
  else
    printf "%s" "$1" > /dev/tty
  fi
}

if (( want_passthrough )) && [[ -n "${TMUX-}" ]]; then
  restore_passthrough=$(tmux show -p -v allow-passthrough 2>/dev/null | awk '{print $1}')
  tmux set-option -p allow-passthrough on >/dev/null
  echo "Sending PASSTHROUGH queries to the underlying terminal..."
else
  echo "Sending DIRECT queries to the current terminal..."
fi

# --- Send queries ---
for q in "${QUERIES[@]}"; do send "$q"; done

# --- Read replies ---
sleep 0.3
reply=$(dd bs=2048 count=1 2>/dev/null || true)
if command -v hexyl >/dev/null 2>&1; then
    printf "%s" "$reply" | hexyl
else
    printf "%s" "$reply" | hexdump -C
fi

# --- Helpers ---
extract_first_dcs() {
  local s="$1"
  s="${s#*$'\eP'}"
  s="${s%%$'\e\\'*}"
  printf '%s' "$s"
}
ESC=$'\x1b'

# --- Parse DECRQSS cursor shape ---
ps=""
dcs_block="$(extract_first_dcs "$reply")"
if [[ -n "$dcs_block" ]]; then
  if [[ "$dcs_block" =~ 1\$r\ q([0-6])\ q ]]; then
    ps="${BASH_REMATCH[1]}"
  elif [[ "$dcs_block" =~ 1\$r([0-6])\ q ]]; then
    ps="${BASH_REMATCH[1]}"
  fi
fi
case "${ps:-}" in
  0|1) desc="blinking block" ;;
  2)   desc="steady block" ;;
  3)   desc="blinking underline" ;;
  4)   desc="steady underline" ;;
  5)   desc="blinking bar" ;;
  6)   desc="steady bar" ;;
  *)   desc="unknown" ;;
esac
if [[ -n "${ps:-}" ]]; then
  echo "→ DECRQSS cursor shape: Ps=$ps  [$desc]"
else
  echo "→ DECRQSS cursor shape: no parseable reply found"
fi

# --- Parse DECRQM ?12 (blink) ---
if [[ "$reply" =~ ${ESC}\[\?12\;([0-9]+)\$y ]]; then
  state="${BASH_REMATCH[1]}"
  case "$state" in
    1|5) blink="blinking (on)" ;;
    2|6) blink="steady (off)" ;;
    3)   blink="blinking (permanent)" ;;
    4)   blink="steady (permanent)" ;;
    *)   blink="unknown-state($state)" ;;
  esac
  echo "→ DECRQM ?12 (blink): $blink  [state=$state]"
else
  echo "→ DECRQM ?12 (blink): no parseable reply found"
fi

# --- Parse DA1 (Primary Device Attributes) reply ---
# Match both "CSI ? ... c" (spec) and the rare "CSI ... c" form some emulators use.
da1_nums=""
if [[ "$reply" =~ ${ESC}\[\?([0-9;]+)c ]]; then
  da1_nums="${BASH_REMATCH[1]}"
elif [[ "$reply" =~ ${ESC}\[([0-9;]+)c ]]; then
  da1_nums="${BASH_REMATCH[1]}"
fi

if [[ -n "$da1_nums" ]]; then
  IFS=';' read -r -a da1_arr <<<"$da1_nums"

  # Helpers
  vt_name="unknown"
  summary=""
  features=()

  # Feature map for VT220+ (after the family code like 62/63/64/65)
  get_feat_name() {
    case "$1" in
      1) echo "132-columns" ;;
      2) echo "printer" ;;
      3) echo "ReGIS" ;;
      4) echo "Sixel" ;;
      6) echo "selective-erase" ;;
      8) echo "UDK" ;;
      9) echo "NRC" ;;
      15) echo "technical-chars" ;;
      16) echo "locator-port" ;;
      17) echo "terminal-state-interrogation" ;;
      18) echo "user-windows" ;;
      21) echo "horizontal-scrolling" ;;
      22) echo "ANSI-color" ;;
      28) echo "rectangular-editing" ;;
      29) echo "ANSI-text-locator" ;;
      *) echo "" ;;
    esac
  }

  # Identify family / model and (for VT220+) decode feature list
  # Common patterns per xterm ctlseqs:
  #   ?1;2c    VT100 + AVO
  #   ?1;0c    VT101 (no options)
  #   ?4;6c    VT132 + AVO + graphics
  #   ?6c      VT102
  #   ?7c      VT131
  #   ?12;Ps c VT125 (+ extra data)
  #   ?62;Ps c VT220 (+ feature list Ps…)
  #   ?63;Ps c VT320 (+ feature list)
  #   ?64;Ps c VT420 (+ feature list)
  #   ?65;Ps c VT510–VT525 (+ feature list)

  first="${da1_arr[0]}"
  second="${da1_arr[1]:-}"

  case "$first" in
    1)
      case "$second" in
        2)  vt_name="VT100 + AVO"; summary="VT100 w/ Advanced Video Option" ;;
        0)  vt_name="VT101";       summary="VT101 (no options)" ;;
        *)  vt_name="VT100-family"; summary="VT100-style ($first;$second)" ;;
      esac
      ;;
    4)
      if [[ "$second" == "6" ]]; then
        vt_name="VT132 + AVO + graphics"
        summary="VT132 with Advanced Video & Graphics"
      else
        vt_name="VT1xx-family"
        summary="VT100-style ($first;$second)"
      fi
      ;;
    6)
      # lone 6 => VT102
      if [[ -z "$second" ]]; then
        vt_name="VT102"
        summary="VT102"
      else
        vt_name="VT1xx-family"
        summary="VT100-style ($first;$second)"
      fi
      ;;
    7)
      vt_name="VT131"
      summary="VT131"
      ;;
    12)
      vt_name="VT125"
      summary="VT125"
      ;;
    62|63|64|65)
      # VT220+ families; remaining numbers are feature flags
      case "$first" in
        62) vt_name="VT220" ;;
        63) vt_name="VT320" ;;
        64) vt_name="VT420" ;;
        65) vt_name="VT510–VT525" ;;
      esac
      # Collect feature names (skip the family code itself)
      for ((i=1; i<${#da1_arr[@]}; i++)); do
        code="${da1_arr[$i]}"
        fname=$(get_feat_name "$code")
        if [[ -n "$fname" ]]; then
          features+=("$fname")
        else
          features+=("feature-$code")
        fi
      done
      if ((${#features[@]})); then
        summary="$vt_name features: $(IFS=', '; echo "${features[*]}")"
      else
        summary="$vt_name (no feature codes reported)"
      fi
      ;;
    *)
      vt_name="unrecognized"
      summary="unrecognized DA1 codes: ?${da1_nums}c"
      ;;
  esac

  echo "→ DA1 (primary): ?${da1_nums}c  [${summary}]"

else
  echo "→ DA1 (primary): no reply"
fi


# --- Parse DA2 (Secondary Device Attributes) reply ---
pp="" pv="" pc=""
pp_name=""

# 3-field: ESC [ > Pp ; Pv ; Pc c
if [[ "$reply" =~ ${ESC}\[\>([0-9]+)\;([0-9]+)\;([0-9]+)c ]]; then
  pp="${BASH_REMATCH[1]}"
  pv="${BASH_REMATCH[2]}"
  pc="${BASH_REMATCH[3]}"
# 2-field (no Pc): ESC [ > Pp ; Pv c
elif [[ "$reply" =~ ${ESC}\[\>([0-9]+)\;([0-9]+)c ]]; then
  pp="${BASH_REMATCH[1]}"
  pv="${BASH_REMATCH[2]}"
  pc=""
fi

if [[ -n "$pp" ]]; then
  case "$pp" in
    0)   pp_name="VT100" ;;
    1)   pp_name="VT220" ;;
    2)   pp_name="VT240/VT241" ;;
    18)  pp_name="VT330" ;;
    19)  pp_name="VT340" ;;
    24)  pp_name="VT320" ;;
    32)  pp_name="VT382" ;;
    41)  pp_name="VT420" ;;
    61)  pp_name="VT510" ;;
    64)  pp_name="VT520" ;;
    65)  pp_name="VT525" ;;
    84)  pp_name="tmux"  ;;
    *)   pp_name="unknown($pp)" ;;
  esac

  if [[ -n "$pc" ]]; then
    echo "→ DA2 (secondary): >$pp;$pv;$pc c  [type=$pp_name  version=$pv  cartridge=$pc]"
  else
    echo "→ DA2 (secondary): >$pp;$pv c  [type=$pp_name  version=$pv]"
  fi

  # Helpful hint for xterm family (common in modern terminals)
  # In many xterm-likes: Pp=0 (VT100), Pv≈patch/version, Pc=0.
  if [[ "$pp" == "0" && "${pc:-0}" == "0" ]]; then
    echo "   note: this looks like an xterm-style reply (Pp=0, Pc=0; Pv is patch/version)."
  fi
else
  echo "→ DA2 (secondary): no reply"
fi

# --- Parse DA3 (Tertiary Device Attributes / DECRPTUI) ---
da3_payload=""

# Preferred/standard reply: DCS ! | <payload> ST
# Pattern: ESC P ! | .... ESC \
if [[ "$reply" =~ ${ESC}P!\|([^\x1b]*)${ESC}\\ ]]; then
  da3_payload="${BASH_REMATCH[1]}"
fi

if [[ -n "$da3_payload" ]]; then
  echo "→ DA3 (tertiary / DECRPTUI): DCS ! | ${da3_payload} ST"

  # Try a few common numeric payload shapes; always show raw first.
  if [[ "$da3_payload" =~ ^([0-9]+)(;[0-9]+)*$ ]]; then
    IFS=';' read -r -a f <<<"$da3_payload"
    case "${#f[@]}" in
      2)
        # Seen in some emulators: "<site>;<serial>"
        echo "  [interpreted as: site_code=${f[0]}  serial=${f[1]}]"
        ;;
      3)
        # Sometimes a leading code before site/serial
        echo "  [interpreted as: code=${f[0]}  site=${f[1]}  serial=${f[2]}]"
        ;;
      4)
        echo "  [interpreted as 4 numeric fields: ${f[*]}]"
        ;;
      6)
        echo "  [interpreted as 6 numeric fields: ${f[*]}]"
        ;;
    esac
    # xterm typically uses zeros for site/serial
    if [[ "${da3_payload//;/}" =~ ^0+$ ]]; then
      echo "  note: looks like an xterm-style reply (zeros for site/serial)."
    fi
  fi

else
  # Some terminals (non-standard) may echo a literal CSI = ... c.
  if [[ "$reply" =~ ${ESC}\[=([0-9;]+)c ]]; then
    echo "→ DA3 (tertiary): literal CSI = ${BASH_REMATCH[1]} c reply (non-standard)"
  else
    echo "→ DA3 (tertiary): no reply"
  fi
fi

# --- Parse CSI u status ---
csiu_flags=""
if [[ "$reply" =~ ${ESC}\[\?([0-9;]+)u ]]; then
  csiu_flags="${BASH_REMATCH[1]}"
  case "$csiu_flags" in
    0)
      echo "→ CSI u: supported, but currently OFF  [flags=0]"
      ;;
    1)
      echo "→ CSI u: ON  [mode 1: disambiguate escape codes]"
      ;;
    "1;2")
      echo "→ CSI u: ON  [mode 1+2: disambiguate + alternate keys]"
      ;;
    *)
      echo "→ CSI u: ON with flags={$csiu_flags}  [unrecognized combo]"
      ;;
  esac
else
  echo "→ CSI u: no reply  [terminal does not recognize query]"
fi

parse_decrqm() {
  # $1 = mode number (e.g., 2004)
  local n="$1"
  if [[ "$reply" =~ ${ESC}\[\?${n}\;([0-9]+)\$y ]]; then
    local st="${BASH_REMATCH[1]}"
    local label=""
    case "$n" in
      2004) label="bracketed-paste" ;;
      1004) label="focus-events" ;;
      1006) label="mouse-sgr" ;;
      *)    label="?$n" ;;
    esac
    local txt
    case "$st" in
      1|5) txt="enabled" ;;
      2|6) txt="disabled" ;;
      3)   txt="permanently-enabled" ;;
      4)   txt="permanently-disabled" ;;
      0)   txt="unsupported" ;;
      *)   txt="state=$st" ;;
    esac
    echo "→ DECRQM ?$n: $label: $txt"
  else
    echo "→ DECRQM ?$n: no reply"
  fi
}
parse_decrqm 2004
parse_decrqm 1004
parse_decrqm 1006
