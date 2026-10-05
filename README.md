<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <img src="demo.gif" alt="xhisper demo" width="300">
  <br><br>
</div>

Dictation at cursor for Linux. Now with **local transcription** (Parakeet/Whisper) + **AI formatting** support - no API keys required!

**Original project by [imaginalnika](https://github.com/imaginalnika/xhisper)** - This fork adds local Whisper transcription and AI formatting.

## Features

- 🎤 **Parakeet-first local transcription** — NVIDIA TDT 0.6B via onnx-asr: ~2x more accurate than whisper-base in English, punctuation & capitalization built in, fast on CPU (whisper remains a config-switch away)
- ⚡ **No LLM latency for everyday dictation** — Parakeet output is pasted directly; Gemma only runs for command and email modes
- 🧠 **AI-powered formatting** via local LLM (Ollama) for grammar, punctuation, and context-aware correction
- 🔧 **Smart modes**: Auto-detects commands, or manual modes for email/standard text
- 🕐 **Pause-safe long dictation** — thinking pauses never drop your words
- 🚀 **GPU acceleration** with CUDA support (whisper engine)
- 💻 **Works offline** after initial model download
- ⌨️ **Types at cursor** in any application

## Installation

### Dependencies

<details>
<summary>Arch Linux / Manjaro</summary>
<pre><code>sudo pacman -S pipewire ffmpeg gcc python3-pip nvidia-cuda-toolkit ollama</code></pre>
</details>

<details>
<summary>Debian / Ubuntu / Pop!_OS</summary>
<pre><code>sudo apt update
sudo apt install pipewire ffmpeg gcc python3-pip nvidia-cuda-toolkit
# Install Ollama from https://ollama.com
curl -fsSL https://ollama.com/install.sh | sh</code></pre>
</details>

<details>
<summary>Fedora / RHEL / AlmaLinux / Rocky</summary>
<pre><code>sudo dnf install -y pipewire pipewire-utils ffmpeg gcc python3 cuda-toolkit ollama</code></pre>
</details>

**Note:** `wl-clipboard` (Wayland) or `xclip` (X11) required for non-ASCII but usually pre-installed.

### Setup

1. **Add user to input group** to access `/dev/uinput`:
```sh
sudo usermod -aG input $USER
```
Then **log out and log back in** (restart is safer) for the group change to take effect.

Check by running:
```sh
groups
```
You should see `input` in the output.

2. **Install Python dependencies**:
```sh
# Parakeet engine (default) — deps (onnxruntime, huggingface-hub, numpy) usually already present
pip3 install --break-system-packages onnx-asr

# Whisper engine (optional fallback)
pip3 install --break-system-packages faster-whisper
```

3. **Pull AI formatting model** (Ollama):
```sh
ollama pull gemma3:4b
```

4. Clone the repository and install:
```sh
git clone https://github.com/wpbryant/xhisper-local.git
cd xhisper-local && make
sudo make install
```

5. Configure:
```sh
mkdir -p ~/.config/xhisper
cp default_xhisperrc ~/.config/xhisper/xhisperrc
nano ~/.config/xhisper/xhisperrc
```

6. Set up keyboard shortcut (e.g., in COSMIC Settings → Keyboard → Custom Shortcuts):
```sh
xhisper                    # Auto mode (default)
xhisper --mode=command     # For terminal commands
xhisper --mode=email       # For email bodies
xhisper --mode=standard    # Plain text formatting
```

**Recommended shortcut:** `Alt+Shift+D` (avoids conflicts with browsers/editors)

---

## Usage

Simply run `xhisper` twice (via your keybinding):
- **First run**: Starts recording (shows `(recording...)`)
- **Second run**: Stops and transcribes (shows `(transcribing...)`), then types the result at your cursor. A `(formatting...)` step appears only when an LLM pass actually applies (see the matrix below).

**Which pipeline runs?** Engine and mode combine like this:

| Engine | Mode | Pipeline |
|--------|------|----------|
| `parakeet` | `auto` (prose) / `standard` | **Parakeet only** — punctuation & capitalization are built in, no LLM round trip |
| `parakeet` | `auto` (sounds like a command) | Parakeet → Gemma (command correction) |
| `parakeet` | `command` / `email` | Parakeet → Gemma |
| `whisper` | any | Whisper → Gemma (original behavior) |

**View logs:**
```sh
xhisper --log
```

Every transcription is tagged with its engine (`Transcription [parakeet]` / `[whisper]`), and skips/failures are logged too.

**Non-QWERTY layouts:**

For non-QWERTY layouts (e.g. Dvorak, International), set up an input switch key to QWERTY (e.g. rightalt). Then bind to:
```sh
xhisper --<your-input-switch-key>
```

**Available input switch keys:** `--leftalt`, `--rightalt`, `--leftctrl`, `--rightctrl`, `--leftshift`, `--rightshift`, `--super`

---

## Configuration

Configuration is read from `~/.config/xhisper/xhisperrc`:

### Transcription Engine Settings
| Setting | Description | Recommended |
|---------|-------------|-------------|
| `transcription-engine` | `parakeet` or `whisper` | `parakeet` (default) |
| `parakeet-model` | onnx-asr model name | `nemo-parakeet-tdt-0.6b-v2` |

**Why Parakeet?** It's ~2x more accurate than whisper-base in English and outputs punctuated, capitalized text natively — so standard dictation skips the LLM formatting pass entirely (faster, no Gemma spin-up). Gemma is still used for `command` and `email` modes. Long recordings (>25s) are automatically segmented with Silero VAD so nothing after a thinking pause is lost. First use downloads ~1GB to `~/.cache/xhisper/parakeet`.

**Parakeet models:** `nemo-parakeet-tdt-0.6b-v2` (English, best accuracy), `nemo-parakeet-tdt-0.6b-v3` (25 languages, auto-detects)

### Whisper Settings (whisper engine only)
| Setting | Description | Recommended |
|---------|-------------|-------------|
| `model-name` | Whisper model size | `base` (best balance) |
| `model-device` | Device to use | `cuda` (GPU) or `cpu` |
| `model-language` | Language code | leave empty for auto |
| `transcription-prompt` | Context for accuracy | optional |
| `vad-min-silence-ms` | Pause length before VAD splits segments | `5000` |

**Available models:** `tiny`, `base`, `small`, `medium`, `large-v3`
- `tiny` - fastest, least accurate
- `base` - **recommended**, good speed/accuracy
- `small` - slower, better accuracy
- `medium` - much slower, very good accuracy
- `large-v3` - slowest, best accuracy

### AI Formatting Settings
| Setting | Description | Recommended |
|---------|-------------|-------------|
| `post-process-model` | Ollama model for formatting | `gemma3:4b` |
| `post-process-mode` | Detection mode | `auto` |
| `post-process-timeout` | Max seconds for formatting | `10` |

**Available modes:**
- `auto` - Detects context (commands vs text) automatically
- `standard` - Grammar, punctuation, capitalization (skipped for parakeet — already punctuated)
- `command` - Linux command syntax correction (e.g., "pseudo" → "sudo")
- `email` - Email body formatting with proper paragraph breaks

### Other Settings
- `silence-threshold`: Volume threshold for silence detection (dB, default -50)
- `non-ascii-*-delay`: Timing for Unicode character pasting

---

## Recommended Setup (Tested)

**Hardware:** NVIDIA RTX 4050 Laptop (6GB VRAM)
**OS:** Pop!_OS with COSMIC desktop

| Component | Model/Setting | Notes |
|-----------|---------------|-------|
| Engine | `parakeet` | More accurate than whisper-base, punctuates natively |
| Parakeet model | `nemo-parakeet-tdt-0.6b-v2` | English, runs fast on CPU |
| Formatter | `gemma3:4b` | Used for command/email modes only |
| Mode | `auto` | Detects commands automatically |

This setup achieves ~1.5s end-to-end for standard dictation (transcription only — no LLM pass), or ~1s transcription + ~1s Gemma formatting for command/email modes. Long dictation sessions with thinking pauses are safe: recordings over 25s are VAD-segmented so nothing said after a pause is dropped, and a timed-out formatting pass falls back to your raw transcription instead of pasting truncated text.

---

## Troubleshooting

**Terminal Applications**: Clipboard paste uses Ctrl+V, which doesn't work in terminal emulators (they require Ctrl+Shift+V). Remap Ctrl+V to paste in your terminal's settings, or use `--mode=command` for pure command transcription.

**GPU not detected**: Ensure NVIDIA drivers and CUDA toolkit are installed. Run `nvidia-smi` to verify.

**Formatting not working**: Ensure Ollama is running and the model is pulled (`ollama pull gemma3:4b`).

**Keyboard shortcut conflicts**: Avoid `Ctrl+Space` or `Alt+Space` as they conflict with browsers. Use `Alt+Shift+D` or `Ctrl+Alt+D` instead.

**First run is slow**: Models download on first use and are cached in `~/.cache/xhisper/parakeet/` (Parakeet ~1GB), `~/.cache/huggingface/hub/` (Whisper) and `~/.ollama/models/` (Ollama). Pre-warm before your first dictation:
```sh
python3 -c "import onnx_asr, pathlib; onnx_asr.load_model('nemo-parakeet-tdt-0.6b-v2', pathlib.Path.home()/'.cache/xhisper/parakeet')"
```

---

## Changes from upstream

This is a fork of [xhisper](https://github.com/imaginalnika/xhisper) by [imaginalnika](https://github.com/imaginalnika). The original project used the Groq API for transcription. This fork adds:

- **Parakeet as the default transcription engine** (NVIDIA TDT 0.6B via onnx-asr) — ~2x more accurate than whisper-base in English, punctuates natively, runs fast on CPU; whisper remains available via `transcription-engine`
- **LLM formatting only where it earns its latency** — standard dictation skips the Ollama pass entirely; Gemma handles command/email modes
- **Long-dictation safety** — VAD segmentation for long clips, tunable pause threshold (`vad-min-silence-ms`), and timeout-killed formatting falls back to raw text instead of truncating
- **Local Whisper transcription** via `faster-whisper` (no Groq API)
- **AI formatting** with local LLM support via Ollama
- **Smart mode detection** for commands vs text
- **Multiple formatting modes** (auto, standard, command, email)
- **GPU acceleration** for both transcription and formatting
- **Works completely offline** after model download

---

<p align="center">
  <em>Low complexity dictation for Linux with AI-powered formatting</em>
  <br><br>
  Forked from <a href="https://github.com/imaginalnika/xhisper">xhisper</a> by <a href="https://github.com/imaginalnika">imaginalnika</a>
</p>
