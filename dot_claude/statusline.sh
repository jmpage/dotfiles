#!/bin/bash
# Minimal Claude Code status line w/ Nerd Font icons. This is intended
# to surface only actionable information:
# - Context used, which can impact the effectiveness of the model when bloated
# - Service status, which can inform a user when an outage occurs
# - Model, which impacts effectiveness
# - Effort, which impacts speed / effectiveness
# - Output style, which impacts user comprehension, model output
# - Rate limit budget used, which impacts what a user may prioritize finishing
# - Repeated cache misses because of tool changes, which consumes
#   tokens more quickly and may be indicative of a poorly-behaved MCP
#   server
#
# Information which is not useful, such as nominal service status, is
# not displayed.
#
# Layout:
#   [context used]     [service status] [tool change warning] [model] [effort] [output style]     [budget used]
#
# See https://code.claude.com/docs/en/statusline

set -euo pipefail





### =============
### CONFIGURATION
### =============

# Effectiveness may degrade after 25% of context used
# See https://callsphere.ai/blog/claude-200k-context-window-effective-memory-myth
CONTEXT_THRESHOLD_YELLOW=12.5
CONTEXT_THRESHOLD_RED=25

# Rate-limit windows turn yellow/red at or below this percent remaining.
RATELIMIT_THRESHOLD_YELLOW=25
RATELIMIT_THRESHOLD_RED=10

# Tool-change cache misses icon appears at the yellow threshold. It
# turns red at the red threshold.
TOOLS_CHANGED_THRESHOLD_YELLOW=2
TOOLS_CHANGED_THRESHOLD_RED=5

# Service status from status.claude.com
STATUS_URL="https://status.claude.com/api/v2/components.json"
STATUS_CHECK_INTERVAL=300 # seconds between requests
STATUS_CHECK_TIMEOUT=5    # curl --max-time, seconds
STATUS_BACKOFF_MAX=3600   # cap on failure backoff, seconds
STATUS_CACHE_FILE="${XDG_CACHE_HOME:-${HOME}/.cache}/claude-statusline/status"
# Component IDs to monitor
STATUS_COMPONENTS=(
  k8w3r06qmzrp # Claude API (api.anthropic.com)
  yyzkbfz2thpt # Claude Code
)





### ==============
### ICON CONSTANTS
### ==============

# Nerd Font icons, as UTF-8 octal escapes
FIRE=$(printf '\356\275\266')        # nf-fa-fire_flame_curved U+EF76
CHAT=$(printf '\363\260\255\271')    # nf-md-chat              U+F0B79
TICKET=$(printf '\363\260\234\244')  # nf-md-ticket_percent    U+F0724
SLEEP=$(printf '\363\260\222\262')   # nf-md-sleep             U+F04B2
WARNING=$(printf '\357\201\261')     # nf-fa-warning           U+F071
ERROR=$(printf '\356\257\273')       # nf-cod-error_small      U+EBFB
QUESTION=$(printf '\357\220\240')    # nf-oct-question         U+F420
TOOLS=$(printf '\363\261\201\244')   # nf-md-tools             U+F1064





### ===============
### COLOR CONSTANTS
### ===============

# Stored as real escape bytes so segments print with %s and visible_len can
# strip them.
RESET=$'\033[0m'

# Tokyo Night palette (github.com/zatchheems/tokyo-night-alacritty-theme, tokyo-night.toml)
YELLOW=$'\033[38;2;224;175;104m' # #e0af68 normal yellow
RED=$'\033[38;2;247;118;142m'    # #f7768e normal red
FG=$'\033[38;2;120;124;153m'     # #787c99 normal white

# (Alternative) Terminal default color scheme:
# YELLOW=$'\033[33m'
# RED=$'\033[31m'
# FG=$'\033[2m'





### =======
### PROGRAM
### =======

# Print a message and exit early if a dependency is missing.
# flock and curl are only needed for the service status check.
missing=()
command -v jq > /dev/null || missing+=(jq)
if [[ ${#STATUS_COMPONENTS[@]} -gt 0 ]]; then
  command -v curl > /dev/null || missing+=(curl)
  command -v flock > /dev/null || missing+=(flock)
fi
if [[ ${#missing[@]} -gt 0 ]]; then
  printf -v missing_list '%s, ' "${missing[@]}"
  echo "Missing statusline.sh dependencies: ${missing_list%, }"
  exit 0
fi

shopt -s extglob

# Visible length of a string, ignoring ANSI SGR color codes.
visible_len() {
  local s="${1//$'\e['*([0-9;])m/}"
  echo "${#s}"
}

# Extract every field in a single jq call, joined by the ASCII unit
# separator. Unlike tab, a non-whitespace IFS character doesn't merge
# adjacent delimiters, so empty fields keep their positions.
# Rate limits are converted to percent remaining here; non-numeric values
# become empty. Control characters are stripped so values can't emit
# terminal escape sequences or shift fields with an embedded separator.
# Full schema: https://code.claude.com/docs/en/statusline#full-json-schema
IFS=$'\x1f' read -r used model effort style cost \
  ratelimit_remaining_5h ratelimit_remaining_7d tools_changed < <(
  jq -r 'def remaining: if type == "number" then 100 - . else "" end;
    [ .context_window.used_percentage // 0,
      .model.display_name // "unknown model",
      .effort.level // "",
      .output_style.name // "",
      .cost.total_cost_usd // "",
      (.rate_limits.five_hour.used_percentage | remaining),
      (.rate_limits.seven_day.used_percentage | remaining),
      .prompt_cache.miss_causes.tools_changed // 0
    ] | map(tostring | gsub("\\p{Cc}"; "")) | join("\u001f")')

# Left segment: context usage, colored by threshold.
# Set unconditionally: set -u makes it mandatory further down, and a
# non-numeric percentage must degrade to an empty segment rather than abort.
left=""
if [[ "${used}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  color="${FG}"
  pct=$(printf '%.0f' "${used}")
  # Compare with awk: bash [[ -gt ]] only handles integers, and thresholds may be fractional.
  if awk -v u="${used}" -v t="${CONTEXT_THRESHOLD_RED}" 'BEGIN { exit !(u > t) }'; then
    color="${RED}"
  elif awk -v u="${used}" -v t="${CONTEXT_THRESHOLD_YELLOW}" 'BEGIN { exit !(u > t) }'; then
    color="${YELLOW}"
  fi
  left="${color}⛁ ${pct}%${RESET}"
fi

# Print the cached highest severity across STATUS_COMPONENTS: 0 operational,
# 1 unknown (unrecognized status, component missing or request failed),
# 2 degraded_performance, 3 partial_outage, 4 major_outage/under_maintenance.
# Never waits on the network: once the cached result is due, a refresh is
# started in the background and picked up by a later render.
status_severity() {
  local severity=1 next_check=0
  if [[ -r "${STATUS_CACHE_FILE}" ]]; then
    read -r severity _ next_check < "${STATUS_CACHE_FILE}" || true
  fi
  [[ "${severity}" =~ ^[0-9]+$ ]] || severity=1
  [[ "${next_check}" =~ ^[0-9]+$ ]] || next_check=0

  # Detach every standard stream: Claude Code reads stdout until EOF, so a
  # background job holding it would block the render anyway.
  # EPOCHSECONDS needs bash 5; macOS ships bash 3.2 as /bin/bash.
  if (( ${EPOCHSECONDS:-$(date +%s)} >= next_check )); then
    refresh_status < /dev/null > /dev/null 2>&1 &
  fi
  echo "${severity}"
}

# Fetch status and rewrite the cache. Makes at most one request, and only
# one session refreshes at a time. A failed request records 1 and doubles
# the wait before the next attempt (interval * 2^failures, capped at
# STATUS_BACKOFF_MAX). Runs in a background subshell.
refresh_status() {
  local now severity failures=0 next_check=0 body delay tmp i=0
  mkdir -p "${STATUS_CACHE_FILE%/*}" 2>/dev/null || true

  # flock is tied to the open descriptor, so the kernel releases it when
  # this process exits for any reason; a killed refresh can't leave a
  # stale lock behind. -n skips the refresh if another session holds it.
  exec 9> "${STATUS_CACHE_FILE}.lock" || return
  flock -n 9 || return

  # Re-read under the lock: another session may have refreshed between our
  # due-check and now, and failures must be read-modify-written atomically.
  if [[ -r "${STATUS_CACHE_FILE}" ]]; then
    read -r _ failures next_check < "${STATUS_CACHE_FILE}" || true
  fi
  [[ "${failures}" =~ ^[0-9]+$ ]] || failures=0
  [[ "${next_check}" =~ ^[0-9]+$ ]] || next_check=0
  now=${EPOCHSECONDS:-$(date +%s)}
  (( now < next_check )) && return

  # Remove the temp file if we're killed before the rename. A fixed name is
  # safe because writers are serialized by the lock; one left behind by a
  # killed refresh is simply overwritten. HUP/TERM are turned into a normal
  # exit so the EXIT trap runs.
  tmp="${STATUS_CACHE_FILE}.tmp"
  trap 'rm -f -- "${STATUS_CACHE_FILE}.tmp"' EXIT
  trap 'exit 1' HUP TERM

  # A monitored component missing from the response counts as unknown.
  # Children close the lock descriptor so that if this process is killed,
  # an orphaned curl can't keep holding the lock until it times out.
  if body=$(exec 9>&-; curl -fsS --max-time "${STATUS_CHECK_TIMEOUT}" "${STATUS_URL}" 2>/dev/null) &&
     severity=$(exec 9>&-; printf '%s' "${body}" | jq -er --arg ids "${STATUS_COMPONENTS[*]}" '
       ([.components[] | {(.id): .status}] | add // {}) as $by_id
       | [$ids | split(" ")[] | $by_id[.] // ""
          | {operational: 0, degraded_performance: 2, partial_outage: 3,
             major_outage: 4, under_maintenance: 4}[.] // 1]
       | max' 2>/dev/null); then
    failures=0
    delay=${STATUS_CHECK_INTERVAL}
  else
    severity=1
    failures=$(( failures + 1 ))
    delay=${STATUS_CHECK_INTERVAL}
    while (( i < failures && delay < STATUS_BACKOFF_MAX )); do
      delay=$(( delay * 2 ))
      i=$(( i + 1 ))
    done
    (( delay > STATUS_BACKOFF_MAX )) && delay=${STATUS_BACKOFF_MAX}
  fi

  # Write-then-rename so readers, which don't take the lock, never see a
  # partial file.
  { printf '%s %s %s\n' "${severity}" "${failures}" "$(( now + delay ))" > "${tmp}" &&
    mv -f "${tmp}" "${STATUS_CACHE_FILE}"; } 2>/dev/null || true
}

# Status icon, colored by severity.
status=""
severity=0
if [[ ${#STATUS_COMPONENTS[@]} -gt 0 ]]; then
  severity=$(status_severity 2>/dev/null || echo 0)
fi
case "${severity}" in
  1) status="${YELLOW}${QUESTION}  ${RESET}" ;;
  2) status="${FG}${SLEEP}  ${RESET}" ;;
  3) status="${YELLOW}${WARNING}  ${RESET}" ;;
  4) status="${RED}${ERROR}  ${RESET}" ;;
esac

# Tool-change warning, shown only once tool-change cache misses exceed the
# yellow threshold.
tool_change_warning=""
[[ "${tools_changed}" =~ ^[0-9]+$ ]] || tools_changed=0
if (( tools_changed > TOOLS_CHANGED_THRESHOLD_RED )); then
  tool_change_warning="${RED}${TOOLS} ${RESET}"
elif (( tools_changed > TOOLS_CHANGED_THRESHOLD_YELLOW )); then
  tool_change_warning="${YELLOW}${TOOLS} ${RESET}"
fi

# Middle segment: model, effort level and output style
middle_text="${model}"
[[ -n "${effort}" ]] && middle_text="${middle_text}  ${FIRE} ${effort}"
[[ -n "${style}" ]]  && middle_text="${middle_text}  ${CHAT} ${style}"
middle="${FG}${middle_text}${RESET}"


# Right segment: rate-limit remaining for each window present, else session cost.
right=""

# Append " <label> <remaining>%" for one rate-limit window, colored by remaining.
append_ratelimit() {
  local label="$1" remaining="$2" seg_color="${FG}"
  if awk -v r="${remaining}" -v t="${RATELIMIT_THRESHOLD_RED}" 'BEGIN { exit !(r <= t) }'; then
    seg_color="${RED}"
  elif awk -v r="${remaining}" -v t="${RATELIMIT_THRESHOLD_YELLOW}" 'BEGIN { exit !(r <= t) }'; then
    seg_color="${YELLOW}"
  fi
  right="${right}${seg_color} ${label} $(printf '%.0f' "${remaining}")%${RESET}"
}

if [[ -n "${ratelimit_remaining_5h}" || -n "${ratelimit_remaining_7d}" ]]; then
  right="${FG}${TICKET}${RESET}"
  [[ -n "${ratelimit_remaining_5h}" ]] && append_ratelimit 5H "${ratelimit_remaining_5h}"
  [[ -n "${ratelimit_remaining_7d}" ]] && append_ratelimit 7D "${ratelimit_remaining_7d}"
elif [[ -n "${cost}" ]]; then
  right="${FG}\$$(printf '%.2f' "${cost}")${RESET}"
fi

# Claude Code passes the terminal width as the COLUMNS env var.
# See https://code.claude.com/docs/en/statusline.md
# Reserve a margin to account for the narrower region in which claude
# code renders the status line.
# Validate before arithmetic: $(( )) would evaluate an expression in COLUMNS.
term_width=${COLUMNS:-80}
[[ "${term_width}" =~ ^[0-9]+$ ]] || term_width=80
margin=4
width=$(( term_width - margin ))
[[ "${width}" -lt 20 ]] && width=${term_width}

# Visible lengths, excluding ANSI color codes.
L=$(visible_len "${left}")
M=$(visible_len "${status}${tool_change_warning}${middle}")
R=$(visible_len "${right}")

# Center the model across the full width, left/right segments pinned to edges.
center_start=$(( (width - M) / 2 ))
lpad=$(( center_start - L ))
[[ "${lpad}" -lt 1 ]] && lpad=1
rpad=$(( width - (L + lpad) - M - R ))
[[ "${rpad}" -lt 1 ]] && rpad=1

printf '%s%*s%s%s%s%*s%s\n' \
  "${left}" "${lpad}" "" "${status}" "${tool_change_warning}" \
  "${middle}" "${rpad}" "" "${right}"
