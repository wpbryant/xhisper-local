<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <img src="demo.gif" alt="xhisper demo" width="300">
  <br><br>
</div>

Dictation at cursor for Linux. Now with **local Whisper** + **AI formatting** support - no API keys required!

## Features

- 🎤 **Local transcription** using Whisper models (no cloud API)
- 🧠 **AI-powered formatting** via local LLM (Ollama) for grammar, punctuation, and context-aware correction
- 🔧 **Smart modes**: Auto-detects commands, or manual modes for email/standard text
- 🚀 **GPU acceleration** with CUDA support
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

2. **Install Python dependencies** (faster-whisper):
```sh
pip3 install --break-system-packages faster-whisper
```

3. **Pull AI formatting model** (Ollama):
```sh
ollama pull gemma3:4b
```

4. Clone the repository and install:
```sh
git clone https://git.bryantnet.net/william/xhisper-local.git
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
- **Second run**: Stops, transcribes, and formats (shows `(transcribing...)` then `(formatting...)`)

The formatted transcription will be typed at your cursor position.

**View logs:**
```sh
xhisper --log
```

**Non-QWERTY layouts:**

For non-QWERTY layouts (e.g. Dvorak, International), set up an input switch key to QWERTY (e.g. rightalt). Then bind to:
```sh
xhisper --<your-input-switch-key>
```

**Available input switch keys:** `--leftalt`, `--rightalt`, `--leftctrl`, `--rightctrl`, `--leftshift`, `--rightshift`, `--super`

---

## Configuration

Configuration is read from `~/.config/xhisper/xhisperrc`:

### Whisper Settings
| Setting | Description | Recommended |
|---------|-------------|-------------|
| `model-name` | Whisper model size | `base` (best balance) |
| `model-device` | Device to use | `cuda` (GPU) or `cpu` |
| `model-language` | Language code | leave empty for auto |
| `transcription-prompt` | Context for accuracy | optional |

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
- `standard` - Grammar, punctuation, capitalization
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
| Whisper | `base` | Fast and accurate |
| Device | `cuda` | GPU acceleration |
| Formatter | `gemma3:4b` | Excellent grammar/punctuation |
| Mode | `auto` | Detects commands automatically |

This setup achieves ~1 second transcription + ~1 second formatting for short recordings.

---

## Troubleshooting

**Terminal Applications**: Clipboard paste uses Ctrl+V, which doesn't work in terminal emulators (they require Ctrl+Shift+V). Remap Ctrl+V to paste in your terminal's settings, or use `--mode=command` for pure command transcription.

**GPU not detected**: Ensure NVIDIA drivers and CUDA toolkit are installed. Run `nvidia-smi` to verify.

**Formatting not working**: Ensure Ollama is running and the model is pulled (`ollama pull gemma3:4b`).

**Keyboard shortcut conflicts**: Avoid `Ctrl+Space` or `Alt+Space` as they conflict with browsers. Use `Alt+Shift+D` or `Ctrl+Alt+D` instead.

**First run is slow**: Models download on first use and are cached in `~/.cache/huggingface/hub/` (Whisper) and `~/.ollama/models/` (Ollama).

---

## Changes from upstream

This fork adds significant enhancements to the original xhisper:

- **Local Whisper transcription** via `faster-whisper` (no Groq API)
- **AI formatting** with local LLM support via Ollama
- **Smart mode detection** for commands vs text
- **Multiple formatting modes** (auto, standard, command, email)
- **GPU acceleration** for both transcription and formatting
- **Works completely offline** after model download

---

<p align="center">
  <em>Low complexity dictation for Linux with AI-powered formatting</em>
</p>
