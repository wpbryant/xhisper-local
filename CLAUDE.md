# xhisper - Linux Dictation Tool

## Project Overview

xhisper is a lightweight Linux dictation tool that transcribes speech to text directly at the cursor position. It uses a keyboard-driven workflow and integrates seamlessly with any Linux application.

**Current Version:** 1.0
**Language:** C (daemon/tool), Bash (main script)
**License:** See LICENSE file

## Architecture

### Components

1. **xhispertoold** (C daemon)
   - Creates virtual keyboard device via Linux uinput
   - Listens on Unix domain socket `@xhisper_socket` (abstract namespace)
   - Handles key presses, typing, backspace, and modifier keys
   - Auto-started by main script if not running

2. **xhispertool** (C client)
   - Communicates with daemon via socket
   - Commands: `paste`, `type <char>`, `backspace`, modifier keys
   - Symlinked as `xhispertoold` for daemon mode

3. **xhisper.sh** (main entry point)
   - Orchestrates recording/transcription workflow
   - Records audio via PipeWire (`pw-record`)
   - Calls transcription API
   - Manages text input via daemon
   - Toggle behavior: first run starts recording, second run stops and transcribes

### Data Flow

```
User presses hotkey
    ↓
xhisper.sh checks if recording
    ↓ (no recording)
Start pw-record → /tmp/xhisper.wav, type "(recording...)"
    ↓
User presses hotkey again
    ↓ (recording active)
Kill pw-record, delete "(recording...)"
    ↓
Check for silence (ffmpeg volumedetect)
    ↓ (not silent)
Type "(transcribing...)", call transcribe()
    ↓
Delete "(transcribing...)", type transcription result
```

## Current API Integration

**Groq Whisper API** (cloud-based, requires API key)

- Endpoint: `https://api.groq.com/openai/v1/audio/transcriptions`
- Models:
  - `whisper-large-v3-turbo` for short recordings (< 1000s)
  - `whisper-large-v3` for longer recordings
- API Key: stored in `~/.env` as `GROQ_API_KEY`
- Headers: `Authorization: Bearer $GROQ_API_KEY`
- Form fields: `file`, `model`, `prompt`

## Dependencies

### System packages
- **pipewire** - Audio recording (`pw-record`)
- **jq** - JSON parsing
- **curl** - HTTP requests
- **ffmpeg** - Audio processing, silence detection
- **gcc** - C compiler
- **wl-clipboard** (Wayland) or **xclip** (X11) - Clipboard operations

### System requirements
- User must be in `input` group for `/dev/uinput` access
- Linux with uinput support

## Configuration

Location: `~/.config/xhisper/xhisperrc` (or `$XDG_CONFIG_HOME/xhisper/xhisperrc`)

```ini
# Model selection threshold (seconds)
long-recording-threshold : 1000

# Context words for better accuracy
transcription-prompt     : ""

# Clipboard paste delays for Unicode characters
non-ascii-initial-delay : 0.15
non-ascii-default-delay : 0.025

# Silence detection (dB, percentage)
silence-threshold  : -50
silence-percentage : 95
```

## Key Files

| File | Purpose |
|------|---------|
| `xhisper.sh` | Main script - recording, transcription, typing |
| `xhispertool.c` | C daemon + client for uinput keyboard |
| `test.c` | Test program for uinput verification |
| `Makefile` | Build and install targets |
| `default_xhisperrc` | Default configuration template |

## Character Input Strategy

- **ASCII (32-126)**: Typed directly via uinput (fast)
- **Unicode/Non-ASCII**: Copied to clipboard, pasted via Ctrl+V (slower)

The daemon's `ascii2keycode_map` in xhispertool.c maps ASCII to Linux keycodes for US QWERTY layout.

## Build & Install

```bash
make                  # Build xhispertool and test
sudo make install     # Install to /usr/local/bin/
sudo make uninstall   # Remove installed binaries
make clean           # Remove built files
```

## Command Line Options

```
xhisper              # Toggle recording/transcription
xhisper --local      # Run from build dir (not installed)
xhisper --log        # Show transcription log
xhisper --rightalt   # Use right alt as input switch key (for non-QWERTY layouts)
```

## Local Whisper Migration Plan

To replace Groq API with local whisper models:

### Option 1: whisper.cpp (Recommended)
- C++ library, lightweight
- Python bindings available
- Models: tiny, base, small, medium, large-v1, large-v2, large-v3
- Supports quantization for smaller models

### Option 2: OpenAI Whisper (Python)
- Original implementation
- Requires PyTorch
- Heavier resource usage

### Implementation Changes Needed

1. **Remove API dependency:**
   - Remove `GROQ_API_KEY` from `~/.env` requirement
   - Remove curl/jq from transcribe() function
   - Remove model selection based on duration

2. **Add local transcription:**
   - Install whisper library (whisper-cpp or openai-whisper)
   - Replace `transcribe()` function with local model call
   - Download model to `~/.local/share/xhisper/models/`

3. **New config options:**
   - `model-path` or `model-name` (e.g., "base", "small", "large-v3")
   - `model-language` (optional, for faster/more accurate transcription)
   - `device` (cpu/cuda)

4. **Dependencies:**
   - Python: `pip install openai-whisper`
   - Or C++: whisper.cpp with bindings

### Example transcribe() replacement (Python/whisper):

```python
import whisper

model = whisper.load_model("base")
result = model.transcribe("audio.wav", fp16=False)
print(result["text"])
```

### Example transcribe() replacement (whisper.cpp):

```bash
./main -m models/ggml-base.bin -f audio.wav --no-colors
```

## Development Notes

- Daemon runs with `atexit(cleanup)` for proper uinput device destruction
- Socket uses abstract namespace (no filesystem socket file)
- Unicode paste timing configurable for different clipboard managers
- Log file: `/tmp/xhisper.log`
- Daemon log: `/tmp/xhispertoold.log`
