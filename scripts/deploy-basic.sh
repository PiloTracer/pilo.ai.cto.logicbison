#!/usr/bin/env bash
# deploy-basic.sh — Thin-client bootstrap of CTO Professor OS into a target project.
#
# Copies ONLY:
#   - .cursorrules (TRAINER_CTO_SOURCE → absolute path of THIS source)
#   - .work.cto/ skeleton
#
# Skills/curricula/standards stay in the source.
#
# Usage (modes/flags accept an optional `--` prefix: `update` ≡ `--update`):
#   bash scripts/deploy-basic.sh <target-path>
#   bash scripts/deploy-basic.sh status [target-path]
#   bash scripts/deploy-basic.sh verify [target-path]
#   bash scripts/deploy-basic.sh <target-path> update
#   bash scripts/deploy-basic.sh <target-path> --force confirm-overwrite-cursorrules
#                                                           # overwrite .cursorrules (blocked without the token)
#   TRAINER_CTO_SOURCE=/path bash scripts/deploy-basic.sh <target-path>
#
set -euo pipefail

# Normalize: every mode/flag works with or without the `--` prefix.
norm() { local a="$1"; [[ "$a" == --* ]] && a="${a#--}"; printf '%s' "$a"; }

if [[ "$(norm "${1:-}")" == "verify" ]]; then
  shift
  exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify-target.sh" "${1:-.}"
fi

if [[ "$(norm "${1:-}")" == "status" ]]; then
  shift
  RAW_TARGET="${1:-.}"
  if [[ "$RAW_TARGET" == "." || "$RAW_TARGET" == "$PWD" ]]; then
    DEST_ROOT="$(pwd)"
  else
    DEST_ROOT="$(cd "$RAW_TARGET" && pwd)"
  fi
  CURS_DEST="${DEST_ROOT}/.cursorrules"
  echo "=== cto-deploy-basic status → $DEST_ROOT ==="
  if [[ -f "$CURS_DEST" ]]; then
    echo "  .cursorrules: present"
    src="$(grep -oE 'TRAINER_CTO_SOURCE=[^ ]*' "$CURS_DEST" 2>/dev/null | head -1 | cut -d= -f2- || true)"
    if [[ -n "$src" && "$src" != "REPLACE_BASICSOURCE" ]]; then
      if [[ -d "$src" ]]; then echo "  TRAINER_CTO_SOURCE: $src (reachable)"; else echo "  TRAINER_CTO_SOURCE: $src (UNREACHABLE)"; fi
    elif grep -q 'TRAINER_CTO_SOURCE=' "$CURS_DEST"; then
      echo "  TRAINER_CTO_SOURCE: <unset token>"
    else
      echo "  TRAINER_CTO_SOURCE: missing"
    fi
  else
    echo "  .cursorrules: MISSING"
  fi
  [[ -d "${DEST_ROOT}/.work.cto/context" ]] && echo "  .work.cto/: present" || echo "  .work.cto/: missing"
  [[ -d "${DEST_ROOT}/.ai.cto/skills" ]] && echo "  local .ai.cto/skills/: present (WARN — fat-client leak)" || echo "  local .ai.cto/skills/: absent (thin-client ok)"
  exit 0
fi

RAW_TARGET="${1:?Usage: $0 [status|verify] <target-path> [force|update] (optional -- prefix on any mode; force requires confirm-overwrite-cursorrules when .cursorrules exists)}"
shift || true
MODE="skip"
CONFIRM_OVERWRITE=0
while [[ $# -gt 0 ]]; do
  case "$(norm "$1")" in
    force)  MODE="force" ;;
    update) MODE="update" ;;
    confirm-overwrite-cursorrules) CONFIRM_OVERWRITE=1 ;;
    verify) exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify-target.sh" "$RAW_TARGET" ;;
    *) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ -n "${TRAINER_CTO_SOURCE:-}" ]]; then
  CTO_ROOT="$(cd "$TRAINER_CTO_SOURCE" && pwd)"
else
  CTO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Shared sister-framework discovery (family naming `pilo.ai.ui.logicbison` + legacy `.ai.ui`).
source "${CTO_ROOT}/scripts/sister-discovery.sh"

if [[ "$RAW_TARGET" == "." || "$RAW_TARGET" == "$PWD" ]]; then
  DEST_ROOT="$(pwd)"
else
  DEST_ROOT="$(cd "$RAW_TARGET" && pwd)"
fi

if [[ ! -d "$DEST_ROOT" ]]; then
  echo "ERROR: target directory does not exist: $DEST_ROOT" >&2
  exit 1
fi

TPL_CURS="${CTO_ROOT}/templates/cursorrules.template"
if [[ ! -f "$TPL_CURS" ]]; then
  echo "ERROR: source missing templates/cursorrules.template at $CTO_ROOT" >&2
  exit 1
fi
if [[ ! -d "${CTO_ROOT}/skills" ]]; then
  echo "ERROR: source missing skills/ at $CTO_ROOT" >&2
  exit 1
fi

CURS_DEST="${DEST_ROOT}/.cursorrules"
WORK_FILES=(
  "README.md" "context/PROFILE.md" "context/HANDOFF.md"
  "plans/NEXT.md" "plans/UNKNOWNS.md" "plans/ASSUMPTIONS.md"
  "programs/README.md" "sessions/README.md" "consultancy/README.md"
  "sources/README.md" "assessments/README.md" "progress/COMPETENCY.md"
  "reports/README.md" "standards/README.md"
)

echo "=== cto-deploy-basic (CTO Professor OS) → $DEST_ROOT (thin-client) ==="
echo "  source: $CTO_ROOT"
echo "  mode:   $MODE"

if [[ -d "${DEST_ROOT}/.ai.cto/skills" ]]; then
  echo "  WARN: target has local .ai.cto/skills/ (fat-client leak)"
  if [[ "$MODE" != "force" ]]; then
    echo "  BLOCKED: use --force to confirm, or remove local .ai.cto/"
    exit 1
  fi
fi

subst_cursorules() {
  local CTO_ROOT_ESC SIBLING_PARENT tmpfile
  CTO_ROOT_ESC="${CTO_ROOT//\//\\/}"
  SIBLING_PARENT="$(cd "$CTO_ROOT/.." && pwd)"
  tmpfile="$(mktemp)"

  # Step 1: substitute TRAINER_CTO_SOURCE
  perl -pe "s/TRAINER_CTO_SOURCE=REPLACE_BASICSOURCE/TRAINER_CTO_SOURCE=${CTO_ROOT_ESC}/" "$TPL_CURS" > "$tmpfile"

  # Step 2: discover and fill sister framework paths at bootstrap time.
  # Sister dir names: family naming (source basename with `<fw>` inserted before
  # its last .segment, e.g. `pilo.ai.ui.logicbison` for a `pilo.ai.logicbison`
  # source; `.ai`-prefixed sources use `.ai.<fw>`; sister-framework sources
  # replace their own slot) then legacy `.ai.<fw>`. If a sister exists on disk,
  # write its absolute path. If absent, leave the REPLACE: token and tell the
  # user what was checked + how to adjust (manual cell fill; see .cursorrules
  # § Frameworks registry).
  local fw
  for fw in $FRAMEWORK_SLOTS; do
    local token_upper token fw_dir_abs fw_esc
    token_upper="$(echo "$fw" | tr '[:lower:]' '[:upper:]')"
    token="REPLACE:AI_${token_upper}_PATH"
    fw_dir_abs="$(find_sister_dir "$CTO_ROOT" "$fw" "$SIBLING_PARENT" || true)"
    if [[ -n "$fw_dir_abs" ]]; then
      fw_esc="${fw_dir_abs//\//\\/}"
      perl -i -pe "s{${token} \\(default:? \\\`[^)]*\\)}{${fw_esc} (discovered at deploy time)}" "$tmpfile"
      if grep -q "$token" "$tmpfile"; then
        echo "  frameworks: WARN ${token} cell did not match expected template shape — left for runtime auto-discover" >&2
      else
        echo "  frameworks: resolved ${token} → ${fw_dir_abs}" >&2
      fi
    else
      local checked
      checked="$(sister_names "$fw" "$CTO_ROOT" | paste -sd' ' -)"
      echo "  frameworks: ${token} not found (checked ${checked} in $SIBLING_PARENT) —" >&2
      echo "    if the sister exists under another dir name, fill ${token} manually in" >&2
      echo "    the target .cursorrules; naming conventions: legacy .ai.<fw> or family" >&2
      echo "    <source-name with <fw> before its last .segment> (e.g. pilo.ai.ui.logicbison)." >&2
    fi
  done
  # Step 2b: Agent OS anchor (not a .ai.<fw> slot) — .ai or pilo.ai.logicbison.
  # Fill REPLACE:AI_PATH when one exists; if neither, leave the token and ask
  # the operator to set the proper value manually (never route into the void).
  local ag ag_dir ag_esc
  ag_dir=""
  for ag in .ai pilo.ai.logicbison; do
    if [[ -f "$SIBLING_PARENT/$ag/skills/README.md" ]]; then
      ag_dir="$SIBLING_PARENT/$ag"
      break
    fi
  done
  if [[ -n "$ag_dir" ]]; then
    ag_esc="${ag_dir//\//\\/}"
    perl -i -pe "s{REPLACE:AI_PATH \\(default:? \\\`[^)]*\\)}{${ag_esc} (discovered at deploy time)}" "$tmpfile"
    if grep -q "REPLACE:AI_PATH" "$tmpfile"; then
      echo "  frameworks: WARN REPLACE:AI_PATH cell did not match expected template shape — left for manual fill" >&2
    else
      echo "  frameworks: resolved REPLACE:AI_PATH → ${ag_dir}" >&2
    fi
  else
    echo "  frameworks: REPLACE:AI_PATH — no Agent OS anchor found (checked .ai, pilo.ai.logicbison in $SIBLING_PARENT);" >&2
    echo "    set REPLACE:AI_PATH manually in the target .cursorrules to the Agent OS path." >&2
  fi

  cat "$tmpfile"
  rm -f "$tmpfile"
}

existing_source=""
if [[ -f "$CURS_DEST" ]]; then
  existing_source="$(grep -oE 'TRAINER_CTO_SOURCE=[^ ]*' "$CURS_DEST" | head -1 | cut -d= -f2- || true)"
fi

# Force overwrites wholesale — only after the operator names
# `confirm-overwrite-cursorrules` (a replace destroys every sister framework's
# block in the file — same guard as Agent OS / UI Design OS / Business OS).
if [[ "$MODE" == "force" ]]; then
  if [[ -f "$CURS_DEST" && "$CONFIRM_OVERWRITE" -ne 1 ]]; then
    lost="$(grep -oE '(SOC_DESIGN_OS_BEGIN|UI_DESIGN_OS_BEGIN|FLUTTER_AGENT_OS_BEGIN|MLT_DESIGN_OS_BEGIN|Core Principles|Source resolution)' "$CURS_DEST" 2>/dev/null | sort -u | paste -sd, - | sed 's/,/, /g' || true)"
    echo "  BLOCKED: force would replace .cursorrules wholesale ($(wc -l < "$CURS_DEST") lines)"
    [[ -n "$lost" ]] && echo "    content that would be LOST: ${lost}"
    echo "    to proceed, name the confirmation token explicitly:"
    echo "      bash ${CTO_ROOT}/scripts/deploy-basic.sh ${DEST_ROOT} force confirm-overwrite-cursorrules"
    echo "    otherwise use update (re-sync pointer in place) — the normal, non-destructive path."
    exit 1
  fi
  subst_cursorules > "$CURS_DEST"
  echo "  cursorules: wrote (TRAINER_CTO_SOURCE=$CTO_ROOT)"
elif [[ -f "$CURS_DEST" ]]; then
  echo "  cursorules: skip (exists) — keeping existing"
  if grep -q 'TRAINER_CTO_SOURCE=' "$CURS_DEST"; then
    :
  else
    echo "  cursorules: NOTE — existing .cursorrules has no TRAINER_CTO_SOURCE;"
    echo "    agent should merge Source-resolution section from template (do not clobber Agent OS rules)."
  fi
else
  subst_cursorules > "$CURS_DEST"
  echo "  cursorules: wrote (TRAINER_CTO_SOURCE=$CTO_ROOT)"
fi

if [[ "$MODE" == "update" ]] && [[ -f "$CURS_DEST" ]] && grep -q 'TRAINER_CTO_SOURCE=' "$CURS_DEST"; then
  if [[ "$existing_source" != "$CTO_ROOT" ]]; then
    CTO_ROOT_ESC="${CTO_ROOT//\//\\/}"
    perl -i -pe "s/TRAINER_CTO_SOURCE=[^\n]*/TRAINER_CTO_SOURCE=${CTO_ROOT_ESC}/" "$CURS_DEST"
    echo "  cursorules: re-synced TRAINER_CTO_SOURCE → $CTO_ROOT"
  fi
fi

BOOTSTRAP_SKIP_CURSERRULES=1 REPO_ROOT="$DEST_ROOT" TRAINER_CTO_SOURCE="$CTO_ROOT" \
  bash "$CTO_ROOT/templates/bootstrap.sh" \
  > /tmp/cto-deploy-basic-cto-bootstrap.$$.log 2>&1 || { cat /tmp/cto-deploy-basic-cto-bootstrap.$$.log; rm -f /tmp/cto-deploy-basic-cto-bootstrap.$$.log; exit 1; }
grep -E '(created:|skip )' /tmp/cto-deploy-basic-cto-bootstrap.$$.log | sed 's/^/  training: /' || true
rm -f /tmp/cto-deploy-basic-cto-bootstrap.$$.log

# --- update-mode classification -------------------------------------------------
# A raw byte-diff over-reports: most differences between a template and a deployed
# file are learner content, not template drift, and acting on the list verbatim
# erases assessment history and sibling-framework rules. Classify each differing
# pair instead, and name the structure the template gained:
#   keep    target is a superset — nothing from the template is missing
#   review  template prose changed, target carries local lines, no new structure
#   MERGE   template gained sections/columns AND target has local lines → schema merge
#   DRIFT   template gained content and the target has no local lines → safe replace

# A header row is any table row immediately followed by a `|---|` separator row.
# The separator must contain a dash: an empty data row (`| | | | |`) otherwise
# matches and the separator above it leaks out as a "header".
hdr_rows() {
  awk 'function is_sep(l) { return l ~ /^\|[-: |]*-[-: |]*\|$/ }
       prev ~ /^\|/ && is_sep($0) && !is_sep(prev) { print prev }
       { prev=$0 }' "$1"
}
col_names() { hdr_rows "$1" | tr '|' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u; }
sec_names() { { grep -E '^#{2,6} ' "$1" || true; } | sed 's/[[:space:]]*$//' | sort -u; }
nonblank() { { grep -c '[^[:space:]]' || true; }; }
# `paste -sd, ` cycles a multi-char delimiter list, so join on "," and expand after.
join_commas() { paste -sd, - | sed 's/,/, /g'; }
cap_list() { local n; n="$(awk -F, '{print NF}' <<< "$1")"; (( n > 3 )) && printf '%s, +%s more' "$(cut -d, -f1-3 <<< "$1")" "$((n - 3))" || printf '%s' "$1"; }

n_keep=0; n_review=0; n_merge=0; n_drift=0

classify_pair() {
  local tpl="$1" dest="$2" label="$3"
  local tpl_only dest_only new_secs new_cols detail
  tpl_only="$(comm -23 <(sort -u "$tpl") <(sort -u "$dest") | nonblank)"
  dest_only="$(comm -13 <(sort -u "$tpl") <(sort -u "$dest") | nonblank)"
  new_secs="$(comm -23 <(sec_names "$tpl") <(sec_names "$dest") | join_commas)"
  new_cols="$(comm -23 <(col_names "$tpl") <(col_names "$dest") | join_commas)"

  detail=""
  [[ -n "$new_secs" ]] && detail+="sections: $(cap_list "$new_secs")"
  if [[ -n "$new_cols" ]]; then
    [[ -n "$detail" ]] && detail+="; "
    detail+="columns: $(cap_list "$new_cols")"
  fi

  if [[ "$tpl_only" -eq 0 ]]; then
    printf '  keep:   %s — target ahead (%s local lines, nothing missing from template)\n' "$label" "$dest_only"
    n_keep=$((n_keep + 1))
  elif [[ -n "$detail" && "$dest_only" -gt 0 ]]; then
    printf '  MERGE:  %s — template adds %s; target has %s local lines → schema merge, never a blind replace\n' "$label" "$detail" "$dest_only"
    n_merge=$((n_merge + 1))
  elif [[ -n "$detail" ]]; then
    printf '  DRIFT:  %s — template adds %s; no local content → safe to replace from template\n' "$label" "$detail"
    n_drift=$((n_drift + 1))
  elif [[ "$dest_only" -eq 0 ]]; then
    printf '  DRIFT:  %s — template prose changed (%s lines), no local content → safe to replace from template\n' "$label" "$tpl_only"
    n_drift=$((n_drift + 1))
  else
    printf '  review: %s — template prose changed (%s lines) but target carries %s local lines and no new template structure\n' "$label" "$tpl_only" "$dest_only"
    n_review=$((n_review + 1))
  fi
}

if [[ "$MODE" == "update" ]]; then
  echo ""
  echo "=== update merge candidates (classified) ==="
  if [[ -f "$CURS_DEST" ]]; then
    tmp_cur="$(mktemp)"
    subst_cursorules > "$tmp_cur" 2>/dev/null
    if cmp -s "$tmp_cur" "$CURS_DEST"; then
      echo "  keep:   .cursorrules — identical to a fresh deploy from this source"
      n_keep=$((n_keep + 1))
    else
      # A rules file is hand-merged across frameworks, so heading/column diffing against a
      # CTO-only template is noise. Classify on CTO wiring + non-template content instead.
      curs_local="$(comm -13 <(sort -u "$tmp_cur") <(sort -u "$CURS_DEST") | nonblank)"
      if ! grep -q 'TRAINER_CTO_SOURCE=' "$CURS_DEST"; then
        printf '  MERGE:  .cursorrules — no CTO wiring in this rules file → merge Source-resolution + CTO skills + Identity (skill protocol step 6); never clobber\n'
        n_merge=$((n_merge + 1))
      else
        printf '  keep:   .cursorrules — hand-maintained rules file, CTO wiring present (%s non-template lines)\n' "$curs_local"
        n_keep=$((n_keep + 1))
        if [[ "$curs_local" -gt 0 ]]; then
          printf '          ^ sibling-framework blocks live in this file — force deletes them (hence the token gate).\n'
          printf '            Review CTO-section prose drift by hand: diff -u %s %s\n' "$TPL_CURS" "$CURS_DEST"
        fi
      fi
    fi
    rm -f "$tmp_cur"
  fi
  TPL_WORK="${CTO_ROOT}/templates/training"
  for f in "${WORK_FILES[@]}"; do
    src="${TPL_WORK}/${f}.template"
    dest="${DEST_ROOT}/.work.cto/${f}"
    [[ -f "$src" && -f "$dest" ]] || continue
    cmp -s "$src" "$dest" && continue
    classify_pair "$src" "$dest" ".work.cto/${f}"
  done
  echo "  ---"
  echo "  ${n_merge} schema merge, ${n_drift} safe replace, ${n_review} prose review, ${n_keep} keep — nothing above was modified"
fi

echo ""
echo "=== Done: thin-client bootstrap → $DEST_ROOT ==="
echo "  .cursorrules: $([ -f "$CURS_DEST" ] && echo present || echo MISSING)"
echo "  TRAINER_CTO_SOURCE: $(grep -oE 'TRAINER_CTO_SOURCE=[^ ]*' "$CURS_DEST" 2>/dev/null | head -1 | cut -d= -f2- || echo '<unset>')"
echo "  .work.cto/: $([ -d "${DEST_ROOT}/.work.cto" ] && echo present || echo MISSING)"
echo ""
echo "Next:"
echo "  1. Fill REPLACE: tokens in .cursorrules (except TRAINER_CTO_SOURCE)"
echo "  2. @cto-session start → @cto-bootstrap init → @cto-assess run"

echo ""
if ! bash "$(dirname "${BASH_SOURCE[0]}")/verify-target.sh" "$DEST_ROOT"; then
  echo "" >&2
  echo "DEPLOY INCOMPLETE: resolve the FAIL items above (existing non-CTO .cursorrules needs a rules-aware merge, not a clobber)." >&2
  exit 1
fi
