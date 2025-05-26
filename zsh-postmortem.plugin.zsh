# ------------------------------------------------------------------------------------
#  zsh-postmortem — automatic "why did that just fail?" powered by your favorite LLM
#  Author:  Stephen Howells  <@stephenhowells>      License: MIT
# ------------------------------------------------------------------------------------

# ── Guard: only load once & only in interactive shells ────────────────────
if [[ -n ${_ZP_ALREADY_LOADED:+1} || ! -o interactive ]]; then
  return 0
fi
typeset -g _ZP_ALREADY_LOADED=1

# ── Utility helpers ───────────────────────────────────────────────────────
# Print to stderr
_zp_warn() { print -u2 -- "ai-postmortem: $*" }
# Fast command existence test
_zp_has() { command -v -- "$1" >/dev/null 2>&1 }

# ── Dependency checks ─────────────────────────────────────────────────────
if ! _zp_has aichat; then
  _zp_warn "⚠️  Missing dependency: aichat (https://github.com/sigoden/aichat) — plugin disabled"
  return 0
fi

# Optional dependency for log browsing
_zp_has fzf && _ZP_FZF_OK=1 || _ZP_FZF_OK=0

# ── Configuration (override in .zshrc BEFORE sourcing) ────────────────────
#   export AI_POSTMORTEM_DISABLE=1          # disable everything
: ${AI_POSTMORTEM_DISABLE:=0}
: ${AI_POSTMORTEM_CACHE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/ai-postmortem}
: ${AI_POSTMORTEM_MODEL_ARGS:=--no-stream}
: ${AI_POSTMORTEM_BULLETS:=true}

# Ensure cache dir exists (best-effort)
if ! mkdir -p -- "$AI_POSTMORTEM_CACHE_DIR" 2>/dev/null; then
  _zp_warn "Could not create cache directory $AI_POSTMORTEM_CACHE_DIR (continuing without cache)"
fi

# ── Internal helper: stable digest for deduplication ──────────────────────
_zp_hash() {
  emulate -L zsh

  local _data="$1"
  if _zp_has shasum; then
    print -n -- "$_data" | shasum -a 256 2>/dev/null | awk '{print $1}'
  elif _zp_has md5sum; then
    print -n -- "$_data" | md5sum 2>/dev/null | awk '{print $1}'
  else
    print "${#_data}_${_data[1]}_${_data[-1]}"
  fi
}

# ── Core: precmd hook implementation ─────────────────────────────────────
_zp_precmd() {
  # Capture exit status IMMEDIATELY - this must be the very first line
  local _zp_orig_status=$?

  # Early exit if disabled
  (( AI_POSTMORTEM_DISABLE )) && return $_zp_orig_status

  # Early exit if command succeeded
  (( _zp_orig_status == 0 )) && return 0

  # Use local scope to avoid affecting global state
  {
    emulate -L zsh

    # Get the last command from history
    local cmd
    cmd=$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    # Skip if we can't get the command or it's empty
    [[ -z $cmd ]] && return $_zp_orig_status

    # Skip commands that are expected to have non-zero exit codes
    case "$cmd" in
      exec\ *|exit\ *|logout|return\ *) return $_zp_orig_status ;;
    esac

    # Create cache key
    local cache_key="$cmd|$PWD|$_zp_orig_status"
    local cache_file="$AI_POSTMORTEM_CACHE_DIR/$(_zp_hash "$cache_key")"

    # Check cache first
    if [[ -r $cache_file ]]; then
      print -P "%F{1}✖%f  $cmd"
      cat -- "$cache_file"
      print
      return $_zp_orig_status
    fi

    # Get git branch if available
    local git_branch=""
    if _zp_has git; then
      git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    fi

    # Build prompt for LLM
    local prompt="Explain why this shell command failed and how to fix it.

    Command: $cmd
    Exit code: $_zp_orig_status
    Directory: $PWD"

    [[ -n $git_branch ]] && prompt+=$'\nGit branch: '"$git_branch"

    [[ $AI_POSTMORTEM_BULLETS == true ]] && prompt+=$'\n\nReturn answer as concise bullet points.'

    # Query LLM
    local answer
    if answer=$(aichat ${AI_POSTMORTEM_MODEL_ARGS} "$prompt" 2>/dev/null); then
      # Display result
      print -P "%F{1}✖%f  $cmd"
      print -- "$answer"
      print

      # Cache the result
      if [[ -w $AI_POSTMORTEM_CACHE_DIR ]]; then
        print -- "$answer" >| "$cache_file" 2>/dev/null || true
      fi
    fi
  } always {
    # Always return the original exit status
    return $_zp_orig_status
  }
}

# ── Bonus: browse cached failures with fzf ────────────────────────────────
ai-oops-log() {
  emulate -L zsh
  [[ $_ZP_FZF_OK -eq 1 ]] || { _zp_warn "fzf not found"; return 1; }
  [[ -d $AI_POSTMORTEM_CACHE_DIR ]] || { _zp_warn "Cache directory not found: $AI_POSTMORTEM_CACHE_DIR"; return 1; }

  local file
  file=$(grep -l -r "" -- "$AI_POSTMORTEM_CACHE_DIR" 2>/dev/null | fzf --prompt="😬  previous fails > ") || return 0
  [[ -r $file ]] && less -R -- "$file"
}
alias aplo='ai-oops-log'

# ── Hook registration (once) ─────────────────────────────────────────────
autoload -Uz add-zsh-hook || { _zp_warn "Could not load add-zsh-hook — plugin disabled"; return 0 }

# Remove any existing instance first, then add at the beginning of the array
add-zsh-hook -d precmd _zp_precmd 2>/dev/null || true
precmd_functions=(_zp_precmd "${precmd_functions[@]}")

# Verify registration
if [[ ${precmd_functions[1]} != "_zp_precmd" ]]; then
  _zp_warn "Could not register precmd hook as first — plugin may not work correctly"
fi

# All done
# ------------------------------------------------------------------------------------
