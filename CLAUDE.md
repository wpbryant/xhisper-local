# xhisper-local - Linux Dictation Tool with Local Whisper

## Project Overview

xhisper-local is a fork of xhisper that uses **local Whisper models** instead of cloud APIs. It transcribes speech to text directly at the cursor position on Linux, working completely offline.

**Version:** 2.0 (local Whisper fork)
**Language:** C (daemon/tool), Bash (main script), Python (transcription)
**Upstream:** https://github.com/imaginalnika/xhisper

## Key Changes from Upstream

- **No API key required** - uses local Whisper models via faster-whisper
- **Works offline** - after initial model download
- **GPU acceleration** - supports CUDA for NVIDIA GPUs
- **Configurable models** - choose speed/accuracy tradeoff

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

3. **xhisper_transcribe.py** (Python transcription module)
   - Uses faster-whisper (CTranslate2) for local transcription
   - Downloads and caches models from Hugging Face
   - Supports GPU acceleration via CUDA
   - Voice activity detection (VAD) to remove silence

4. **xhisper.sh** (main entry point)
   - Orchestrates recording/transcription workflow
   - Records audio via PipeWire (`pw-record`)
   - Calls Python transcription script
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
xhisper_transcribe.py runs faster-whisper
    ↓
Delete "(transcribing...)", type transcription result
```

## Dependencies

### System packages
- **pipewire** - Audio recording (`pw-record`)
- **ffmpeg** - Audio processing, silence detection
- **gcc** - C compiler
- **python3** - Python 3.10+
- **wl-clipboard** (Wayland) or **xclip** (X11) - Clipboard operations

### Python packages
- **faster-whisper** - Local Whisper transcription with CTranslate2

### System requirements
- User must be in `input` group for `/dev/uinput` access
- Linux with uinput support
- For GPU: CUDA toolkit (optional, CPU fallback available)

## Configuration

Location: `~/.config/xhisper/xhisperrc` (or `$XDG_CONFIG_HOME/xhisper/xhisperrc`)

```ini
# Whisper model size: tiny, base, small, medium, large-v3
model-name : base

# Device: auto, cpu, or cuda
model-device : auto

# Language code (e.g., en, es, fr) or empty for auto-detect
model-language : ""

# Context words for better accuracy
transcription-prompt     : ""

# Clipboard paste delays for Unicode characters
non-ascii-initial-delay : 0.15
non-ascii-default-delay : 0.025

# Silence detection (dB, percentage)
silence-threshold  : -50
silence-percentage : 95
```

### Model Sizes

| Model | Size | RAM | Speed | Accuracy |
|-------|------|-----|-------|----------|
| tiny | 39M | ~1GB | Very fast | Lowest |
| base | 74M | ~1GB | Fast | Good (recommended) |
| small | 244M | ~2GB | Medium | Better |
| medium | 769M | ~5GB | Slow | Very good |
| large-v3 | 1550M | ~10GB | Slowest | Best |

## Key Files

| File | Purpose |
|------|---------|
| `xhisper.sh` | Main script - recording, transcription, typing |
| `xhispertool.c` | C daemon + client for uinput keyboard |
| `xhisper_transcribe.py` | Python transcription using faster-whisper |
| `test.c` | Test program for uinput verification |
| `Makefile` | Build and install targets |
| `default_xhisperrc` | Default configuration template |

## Character Input Strategy

- **ASCII (32-126)**: Typed directly via uinput (fast)
- **Unicode/Non-ASCII**: Copied to clipboard, pasted via Ctrl+V (slower)

The daemon's `ascii2keycode_map` in xhispertool.c maps ASCII to Linux keycodes for US QWERTY layout.

## Build & Install

```bash
# Install Python dependencies
pip install --break-system-packages faster-whisper

# Build and install
make
sudo make install

# Uninstall
sudo make uninstall

# Clean build artifacts
make clean
```

## Command Line Options

```
xhisper              # Toggle recording/transcription
xhisper --local      # Run from build dir (not installed)
xhisper --log        # Show transcription log
xhisper --rightalt   # Use right alt as input switch key (for non-QWERTY layouts)
```

## Development Notes

- Daemon runs with `atexit(cleanup)` for proper uinput device destruction
- Socket uses abstract namespace (no filesystem socket file)
- Unicode paste timing configurable for different clipboard managers
- Models cached in `~/.cache/huggingface/hub/`
- Log file: `/tmp/xhisper.log`
- Daemon log: `/tmp/xhispertoold.log`

## Testing Transcription Standalone

You can test the transcription module directly:

```bash
python3 xhisper_transcribe.py recording.wav --model base --device auto
```

Options:
- `--model`: tiny, base, small, medium, large-v3
- `--device`: auto, cpu, cuda
- `--language`: Language code
- `--prompt`: Context for better accuracy
- `--debug`: Enable verbose output
