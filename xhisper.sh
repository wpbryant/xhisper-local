#!/bin/bash

# Add CUDA library path for faster-whisper
export LD_LIBRARY_PATH=/usr/local/lib/ollama/cuda_v12/lib:$LD_LIBRARY_PATH

# xhisper v2.0
# Dictate anywhere in Linux. Transcription at your cursor.
# - Transcription via local Whisper models (faster-whisper)

# Configuration (see default_xhisperrc or ~/.config/xhisper/xhisperrc):
# - model-name : Whisper model size (tiny, base, small, medium, large-v3)
# - model-device : Device to use (auto, cpu, cuda)
# - model-language : Language code for faster/more accurate transcription (e.g., en)
# - transcription-prompt : context words for better Whisper accuracy
# - silence-threshold : max volume in dB to consider silent (e.g., -50)
# - silence-percentage : percentage of recording that must be silent (e.g., 95)
# - non-ascii-initial-delay : sleep after first non-ASCII paste (seconds)
# - non-ascii-default-delay : sleep after subsequent non-ASCII pastes (seconds)

# Requirements:
# - pipewire, pipewire-utils (audio)
# - wl-clipboard (Wayland) or xclip (X11) for clipboard
# - ffmpeg (processing)
# - Python 3 with faster-whisper
# - make to build, sudo make install to install

# Parse command-line arguments
LOCAL_MODE=0
WRAP_KEY=""
POST_PROCESS_MODE=""  # Empty = use config/default
for arg in "$@"; do
  case "$arg" in
    --local)
      LOCAL_MODE=1
      ;;
    --log)
      if [ -f "/tmp/xhisper.log" ]; then
        cat /tmp/xhisper.log
      else
        echo "No log file found at /tmp/xhisper.log" >&2
      fi
      exit 0
      ;;
    --mode=*)
      POST_PROCESS_MODE="${arg#--mode=}"
      ;;
    --leftalt|--rightalt|--leftctrl|--rightctrl|--leftshift|--rightshift|--super)
      if [ -n "$WRAP_KEY" ]; then
        echo "Error: Multiple wrap keys not yet supported" >&2
        exit 1
      fi
      WRAP_KEY="${arg#--}"
      ;;
    *)
      echo "Error: Unknown option '$arg'" >&2
      echo "Usage: xhisper [--local] [--log] [--mode=auto|standard|command|email] [--leftalt|--rightalt|--leftctrl|--rightctrl|--leftshift|--rightshift|--super]" >&2
      exit 1
      ;;
  esac
done

# Set binary paths based on local mode
if [ "$LOCAL_MODE" -eq 1 ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  XHISPERTOOL="$SCRIPT_DIR/xhispertool"
  XHISPERTOOLD="$SCRIPT_DIR/xhispertoold"
else
  XHISPERTOOL="xhispertool"
  XHISPERTOOLD="xhispertoold"
fi

RECORDING="/tmp/xhisper.wav"
LOGFILE="/tmp/xhisper.log"
PROCESS_PATTERN="pw-record.*$RECORDING"

# Default configuration
model_name="base"
model_device="auto"
model_language=""
transcription_prompt=""
silence_threshold=-50
silence_percentage=95
non_ascii_initial_delay=0.1
non_ascii_default_delay=0.025
post_process_model=""
post_process_timeout=10
post_process_mode="auto"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/xhisper/xhisperrc"

if [ -f "$CONFIG_FILE" ]; then
  while IFS=: read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    # Trim whitespace and quotes
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')

    case "$key" in
      model-name) model_name="$value" ;;
      model-device) model_device="$value" ;;
      model-language) model_language="$value" ;;
      transcription-prompt) transcription_prompt="$value" ;;
      silence-threshold) silence_threshold="$value" ;;
      silence-percentage) silence_percentage="$value" ;;
      non-ascii-initial-delay) non_ascii_initial_delay="$value" ;;
      non-ascii-default-delay) non_ascii_default_delay="$value" ;;
      post-process-model) post_process_model="$value" ;;
      post-process-timeout) post_process_timeout="$value" ;;
      post-process-mode) post_process_mode="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

# Command-line mode overrides config
[ -n "$POST_PROCESS_MODE" ] && post_process_mode="$POST_PROCESS_MODE"

# Auto-start daemon if not running
if ! pgrep -x xhispertoold > /dev/null; then
    "$XHISPERTOOLD" 2>> /tmp/xhispertoold.log &
    sleep 1  # Give daemon time to start

    # Verify daemon started successfully
    if ! pgrep -x xhispertoold > /dev/null; then
        echo "Error: Failed to start xhispertoold daemon" >&2
        echo "Check /tmp/xhispertoold.log for details" >&2
        exit 1
    fi
fi

# Check if xhispertool is available
if ! command -v "$XHISPERTOOL" &> /dev/null; then
    echo "Error: xhispertool not found" >&2
    echo "Please either:" >&2
    echo "  - Run 'sudo make install' to install system-wide" >&2
    echo "  - Run 'xhisper --local' from the build directory" >&2
    exit 1
fi

# Detect clipboard tool
if command -v wl-copy &> /dev/null; then
    CLIP_COPY="wl-copy"
    CLIP_PASTE="wl-paste"
elif command -v xclip &> /dev/null; then
    CLIP_COPY() { xclip -selection clipboard; }
    CLIP_PASTE() { xclip -o -selection clipboard; }
else
    echo "Error: No clipboard tool found. Install wl-clipboard or xclip." >&2
    exit 1
fi

press_wrap_key() {
  if [ -n "$WRAP_KEY" ]; then
    "$XHISPERTOOL" "$WRAP_KEY"
  fi
}

paste() {
  local text="$1"
  press_wrap_key
  # Type character by character
  # Use xhispertool type for ASCII (32-126), clipboard+paste for Unicode
  for ((i=0; i<${#text}; i++)); do
    local char="${text:$i:1}"
    local ascii=$(printf '%d' "'$char")

    if [[ $ascii -ge 32 && $ascii -le 126 ]]; then
      # ASCII printable character - use direct key typing (faster)
      "$XHISPERTOOL" type "$char"
    else
      # Unicode or special character - use clipboard
      echo -n "$char" | $CLIP_COPY
      "$XHISPERTOOL" paste
      # On first character (more error-prone), sleep longer
      [ "$i" -eq 0 ] && sleep "$non_ascii_initial_delay" || sleep "$non_ascii_default_delay"
    fi
  done
  press_wrap_key
}

delete_n_chars() {
  local n="$1"
  for ((i=0; i<n; i++)); do
    "$XHISPERTOOL" backspace
  done
}

get_duration() {
  local recording="$1"
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$recording" 2>/dev/null || echo "0"
}

is_silent() {
  local recording="$1"

  # Use ffmpeg volumedetect to get mean and max volume
  local vol_stats=$(ffmpeg -i "$recording" -af "volumedetect" -f null /dev/null 2>&1 | grep -E "mean_volume|max_volume")
  local max_vol=$(echo "$vol_stats" | grep "max_volume" | awk '{print $5}')

  # If max volume is below threshold, consider it silent
  # Note: ffmpeg reports in dB, negative values (e.g., -50 dB is quiet)
  if [ -n "$max_vol" ]; then
    local is_quiet=$(echo "$max_vol < $silence_threshold" | bc -l)
    [ "$is_quiet" -eq 1 ] && return 0
  fi

  return 1
}

logging_end_and_write_to_logfile() {
  local title="$1"
  local result="$2"
  local logging_start="$3"

  local logging_end=$(date +%s%N)
  local time=$(echo "scale=3; ($logging_end - $logging_start) / 1000000000" | bc)

  echo "=== $title ===" >> "$LOGFILE"
  echo "Result: [$result]" >> "$LOGFILE"
  echo "Time: ${time}s" >> "$LOGFILE"
}

post_process() {
  local text="$1"
  local mode="${2:-$post_process_mode}"
  local logging_start=$(date +%s%N)

  # Skip if empty or no model configured
  [ -z "$text" ] && echo "$text" && return
  [ -z "$post_process_model" ] && echo "$text" && return

  # Check if ollama is available
  if ! command -v ollama &> /dev/null; then
    echo "Error: ollama not found. Install ollama or disable post-processing." >&2
    echo "$text"
    return
  fi

  local prompt

  # Auto-detect mode
  if [ "$mode" = "auto" ]; then
    # Check for command indicators
    if echo "$text" | grep -qE "^(sudo |apt |git |npm |pip |systemctl |docker |cd |ls |mkdir |rm |cp |mv |grep |find |cat |tail |head |ssh |curl |wget |make |cargo |python |node |code |vim |nano |man |chmod |chown |ln |tar |zip |unzip |mount |umount |ps |kill |top |htop |df |du |free |uname |export |alias |source |exit |pseudo )|^(apt|git|npm|pip|sudo|systemctl|docker|cargo) " || \
       echo "$text" | grep -qE " (install|update|upgrade|remove|purge|status|start|stop|restart|enable|disable|clone|pull|push|commit|add|log|diff|checkout|branch|merge|rebase|init)( |$)"; then
      mode="command"
    else
      mode="standard"
    fi
  fi

  # Build prompt based on mode
  case "$mode" in
    command)
      prompt="You are a Linux command expert. Fix this command transcription. Rules: 1) Correct command names (sudo, apt, git, npm, systemctl, docker, etc.) 2) Keep flags exactly as spoken 3) Keep file paths as spoken 4) Fix pipe syntax 5) Output ONLY the corrected command, no explanations. Input: $text"
      ;;
    email)
      prompt="Fix the grammar, punctuation, and capitalization of this email body text. Rules: 1) Use proper paragraph breaks (double line breaks between paragraphs) 2) Keep the tone natural and conversational 3) Do NOT add subject, salutation, or sign-off - user is typing in the body field 4) Output ONLY the formatted body text. Input: $text"
      ;;
    standard|*)
      prompt="Fix the grammar, punctuation, and capitalization of this text. Important: use apostrophes for contractions like don't, can't, I'm, you're, it's, etc. Keep text natural and conversational. Output ONLY the corrected text. Text: $text"
      ;;
  esac

  # Run ollama with timeout
  local result=$(echo "$prompt" | timeout "$post_process_timeout" ollama run "$post_process_model" 2>/dev/null | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  logging_end_and_write_to_logfile "Post-Process [$mode]" "$result" "$logging_start"

  # If ollama failed or timed out, return original text
  if [ -z "$result" ]; then
    echo "$text"
  else
    echo "$result"
  fi
}

transcribe() {
  local recording="$1"
  local logging_start=$(date +%s%N)

  # Set up transcription script path
  if [ "$LOCAL_MODE" -eq 1 ]; then
    TRANSCRIPT_SCRIPT="$SCRIPT_DIR/xhisper_transcribe.py"
  else
    TRANSCRIPT_SCRIPT="xhisper_transcribe"
  fi

  # Build command arguments
  local cmd_args="--model $model_name --device $model_device"

  if [ -n "$model_language" ]; then
    cmd_args="$cmd_args --language $model_language"
  fi

  if [ -n "$transcription_prompt" ]; then
    cmd_args="$cmd_args --prompt \"$transcription_prompt\""
  fi

  # Run transcription
  local transcription=$(python3 "$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null)

  logging_end_and_write_to_logfile "Transcription" "$transcription" "$logging_start"

  echo "$transcription"
}

# Main

# Find recording process, if so then kill
if pgrep -f "$PROCESS_PATTERN" > /dev/null; then
  pkill -f "$PROCESS_PATTERN"; sleep 0.2 # Buffer for flush
  delete_n_chars 14 # "(recording...)"

  # Check if recording is silent
  if is_silent "$RECORDING"; then
    paste "(no sound detected)"
    sleep 0.6
    delete_n_chars 19 # "(no sound detected)"
    rm -f "$RECORDING"
    exit 0
  fi

  paste "(transcribing...)"
  TRANSCRIPTION=$(transcribe "$RECORDING")
  delete_n_chars 17 # "(transcribing...)"

  # Post-process with LLM if configured
  if [ -n "$post_process_model" ] && [ -n "$TRANSCRIPTION" ]; then
    paste "(formatting...)"
    FORMATTED=$(post_process "$TRANSCRIPTION")
    delete_n_chars 15 # "(formatting...)"
    # Only paste if we got a result
    if [ -n "$FORMATTED" ]; then
      paste "$FORMATTED"
    else
      paste "$TRANSCRIPTION"
    fi
  else
    paste "$TRANSCRIPTION"
  fi

  rm -f "$RECORDING"
else
  # No recording running, so start
  sleep 0.2
  paste "(recording...)"
  pw-record --channels=1 --rate=16000 "$RECORDING"
fi
