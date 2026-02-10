# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

xhisper-local is a fork of [xhisper](https://github.com/imaginalnika/xhisper) by imaginalnika. It provides dictation at cursor for Linux using local Whisper transcription and AI-powered formatting.

**Key features:** Local Whisper (no API keys), AI formatting via Ollama, smart command detection, GPU acceleration, works offline.

## Build & Install

```bash
# Install Python dependencies
pip3 install --break-system-packages faster-whisper

# Build C binary
make

# Install system-wide
sudo make install

# Run from source (without installing)
./xhisper.sh --local
```

To use AI formatting, install Ollama and pull Gemma3:
```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull gemma3:4b
```

## Architecture

### Components

1. **xhispertoold** (C daemon) - Virtual keyboard via Linux uinput, listens on abstract Unix socket `@xhisper_socket`
2. **xhispertool** (C client) - Communicates with daemon via socket; symlinked as `xhispertoold` for daemon mode
3. **xhisper_transcribe.py** (Python) - Whisper transcription using faster-whisper
4. **xhisper.sh** (Bash) - Main orchestrator: recording, transcription, AI formatting, typing

### Data Flow

```
User presses hotkey → xhisper.sh toggles recording state
  ├─ First press: pw-record starts → types "(recording...)"
  └─ Second press: kill pw-record → check silence
      ├─ Silent: type "(no sound detected)", exit
      └─ Not silent:
          ├─ transcribe via faster-whisper
          ├─ if post-process-model set: format via Ollama
          └─ type result via daemon
```

### Character Input

- **ASCII (32-126)**: Typed directly via uinput keycodes (US QWERTY layout)
- **Non-ASCII**: Clipboard paste (wl-copy/wl-paste or xclip)

The `ascii2keycode_map` in xhispertool.c maps ASCII to Linux keycodes.

## Configuration

Location: `~/.config/xhisper/xhisperrc` (or `$XDG_CONFIG_HOME/xhisper/xhisperrc`)

Key settings:
- `model-name`: Whisper size (tiny, base, small, medium, large-v3)
- `model-device`: auto, cpu, or cuda
- `post-process-model`: Ollama model (e.g., gemma3:4b)
- `post-process-mode`: auto, standard, command, email
- `post-process-timeout`: Max seconds for LLM formatting

## Command Line Options

```
xhisper                  # Toggle recording (auto mode)
xhisper --local          # Run from build dir
xhisper --log            # Show log
xhisper --mode=command   # Force command mode
xhisper --mode=email     # Force email mode
xhisper --mode=standard  # Force standard text mode
xhisper --rightalt       # Use right alt as input switch (non-QWERTY layouts)
```

## AI Formatting Modes

- **auto**: Detects commands vs text automatically (checks for sudo, apt, git, etc.)
- **standard**: Grammar, punctuation, capitalization
- **command**: Linux command syntax correction (e.g., "pseudo" → "sudo")
- **email**: Email body formatting with paragraph breaks (no subject/salutation added)

## Environment

- User must be in `input` group for `/dev/uinput` access
- Requires CUDA toolkit for GPU acceleration
- Models cached in `~/.cache/huggingface/hub/` (Whisper) and `~/.ollama/models/` (Ollama)
- Log: `/tmp/xhisper.log`
- Daemon log: `/tmp/xhispertoold.log`

## Testing

Test transcription standalone:
```bash
python3 xhisper_transcribe.py recording.wav --model base --device cuda
```

Test AI formatting:
```bash
echo "fix this text" | ollama run gemma3:4b "Fix grammar. Output only text."
```
