<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <img src="demo.gif" alt="xhisper demo" width="300">
  <br><br>
</div>

Dictation at cursor for Linux. Now with **local transcription** (Parakeet/Whisper) + **AI formatting** support - no API keys required!

**Original project by [imaginalnika](https://github.com/imaginalnika/xhisper)** - This fork adds local Whisper transcription and AI formatting.

## Features

- 🎤 **Parakeet-first local transcription** — NVIDIA TDT 0.6B via onnx-asr: ~2x more accurate than whisper-base in English, punctuation & capitalization built in, fast on CPU (whisper remains a config-switch away)
- 🧹 **Fast dictation cleanup** — optional [Spokenly cleanup-1](https://huggingface.co/spokenly/cleanup-1) pass (0.6B, ~0.1-0.3s) strips filler words, applies spoken corrections ("send it to Bob wait no Alice"), formats numbers, email and web addresses
- ⚡ **No heavyweight LLM for everyday dictation** — the 0.6B cleanup model handles standard text; a bigger Ollama model is only used for command and email modes
- 🧠 **AI-powered formatting** via local LLM (Ollama) for grammar, punctuation, and context-aware correction
- 🔧 **Smart modes**: Auto-detects commands, or manual modes for email/standard text
- 🕐 **Pause-safe long dictation** — thinking pauses never drop your words
- 🚀 **GPU acceleration** with CUDA support (whisper engine)
- 💻 **Works offline** after initial model download
- ⌨️ **Types at cursor** in any application

## Installation

### Dependencies

**Required** for every install:

| Dependency | Why |
|------------|-----|
| `pipewire` + `pw-record` | audio capture (`pipewire-bin` on Debian/Ubuntu, `pipewire-utils` on Fedora) |
| `wl-clipboard` (Wayland) or `xclip` (X11) | clipboard paste for non-ASCII characters — the script exits without one, and it is **not** in Ubuntu's default install |
| `bc` | timing entries in the log |
| `gcc`, `make`, `python3-pip` | build the typing daemon, install |

**Optional**, depending on what you use:

| Dependency | Needed for |
|------------|-----------|
| Ollama + `hf.co/spokenly/cleanup-1-gguf:Q8_0` (639 MB, ~1 GB RAM) | dictation cleanup of standard text — filler words, spoken corrections, numbers |
| Ollama + an instruct model (e.g., `gemma3:4b`) | `command` / `email` formatting modes only |
| `faster-whisper` (pip) | the `whisper` engine only |
| NVIDIA CUDA toolkit | GPU acceleration for the whisper engine (and optionally parakeet via `onnxruntime-gpu`) — Parakeet runs fast on CPU |

<details>
<summary>Arch Linux / Manjaro</summary>
<pre><code>sudo pacman -S --needed pipewire wl-clipboard bc gcc make python-pip
# Optional (AI formatting): install ollama from https://ollama.com or AUR</code></pre>
</details>

<details>
<summary>Debian / Ubuntu / Pop!_OS</summary>
<pre><code>sudo apt update
sudo apt install pipewire pipewire-bin wl-clipboard bc gcc make python3-pip
# Optional (AI formatting): install Ollama from https://ollama.com
curl -fsSL https://ollama.com/install.sh | sh</code></pre>
</details>

<details>
<summary>Fedora / RHEL / AlmaLinux / Rocky</summary>
<pre><code>sudo dnf install -y pipewire pipewire-utils wl-clipboard bc gcc make python3-pip
# Optional (AI formatting): install ollama from https://ollama.com</code></pre>
</details>

Note: `ffmpeg` is **not** required — recording uses PipeWire's own WAV writer and both engines read WAV natively.

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
# Parakeet engine (default) — onnxruntime is an extra since onnx-asr 0.12
pip3 install --break-system-packages 'onnx-asr[cpu]'

# If pip has no onnxruntime wheel for your Python yet (e.g. a just-released
# 3.15), install your distro's onnxruntime package instead, e.g. on Fedora:
#   sudo dnf install python3-onnxruntime

# Whisper engine (optional fallback)
pip3 install --break-system-packages faster-whisper
```

> **⚠️ Package break in onnx-asr ≥ 0.12 (affects reinstallers and fresh installs on any distro):** onnxruntime moved from a hard dependency to an optional *extra*. The old instruction — a bare `pip3 install onnx-asr` — now installs **no** onnxruntime, and dictation fails with `No module named 'onnxruntime'` even though onnx-asr looks installed.
>
> - **CPU setup:** use `'onnx-asr[cpu]'` as shown above (or your distro's onnxruntime package).
> - **GPU setup:** use the pinned `onnxruntime-gpu` command from the *Parakeet on GPU* section under Transcription Engine Settings — it satisfies onnx-asr and replaces the CPU onnxruntime package.
> - onnxruntime wheels also lag brand-new Python releases (there were none for 3.15 at its launch). If pip finds no wheel for your Python, CPU setups can fall back to a distro package; the GPU stack has no fallback and must wait for wheels — Parakeet stays fast on CPU meanwhile.

3. **Pull AI models** (both optional — xhisper works with no LLM at all):

Recommended: [Spokenly cleanup-1](https://huggingface.co/spokenly/cleanup-1), a 0.6B model built specifically for cleaning up dictated text — removes "um"/"uh", applies spoken corrections, formats numbers, email and web addresses, ~0.1-0.3s per dictation:
```sh
ollama pull hf.co/spokenly/cleanup-1-gguf:Q8_0   # 639 MB, one time
```
Enable it in step 5 by setting `cleanup-model : xhisper-cleanup-1` (the tuned alias is created automatically on first use — see [AI Formatting Settings](#ai-formatting-settings) for why the names differ).

For `command`/`email` formatting modes only (multi-GB instruct model):
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
Most defaults are fine. The two settings you may want to change:
- Dictation cleanup (after the step-3 pull): `cleanup-model : xhisper-cleanup-1`
- Command/email formatting: `post-process-model : gemma3:4b`

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
- **Second run**: Stops and transcribes (shows `(transcribing...)`), then types the result at your cursor. A `(formatting...)` step appears only when an AI pass actually applies (see the matrix below).

**Which pipeline runs?** Engine, mode, and configured models combine like this (`cleanup-model` = the fast 0.6B cleanup pass, `post-process-model` = an instruct LLM like Gemma):

| Engine | Mode | Pipeline |
|--------|------|----------|
| `parakeet` | `auto` (prose) / `standard` | Parakeet → **cleanup-1** when `cleanup-model` is set (filler words, spoken corrections, numbers); otherwise Parakeet only — punctuation is built in, no LLM round trip (set `post-process-standard : on` to add the instruct-LLM pass anyway) |
| `parakeet` | `auto` (sounds like a command) | Parakeet → Gemma (command correction) |
| `parakeet` | `command` / `email` | Parakeet → Gemma |
| `whisper` | any | Whisper → cleanup-1 (standard text) or Gemma |

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

**Fixing misheard words (`transcription-corrections`):** the ASR engines have no vocabulary biasing, so homophones get transcribed literally — e.g. "Claude" comes out as "clawed". A comma-separated `from=to` map fixes known mishears right after transcription, before cleanup runs:
```sh
transcription-corrections : clawed code=Claude Code,clawed=Claude
```
Matches are case-insensitive whole phrases, longest source first. Note the trade-off: literal uses of a mapped word are replaced too, so only map words you never dictate with their literal meaning.

**Parakeet on GPU (optional):** Parakeet runs on CPU by default and is fast there. To run it on an NVIDIA GPU instead, set `model-device : cuda` and install the CUDA 12 build of onnxruntime plus the two libraries its CUDA provider needs:
```sh
pip3 install --break-system-packages 'onnxruntime-gpu==1.24.4' nvidia-curand-cu12 nvidia-cufft-cu12
```
`onnxruntime-gpu` **replaces** `onnxruntime`, and wheels ≥ 1.26 are built for CUDA 13, which won't load against the CUDA 12 libraries most stacks ship (the script fails loudly rather than silently falling back to CPU). There is also an `onnx-asr[gpu]` extra, but it pulls the newest onnxruntime-gpu — CUDA 13-built since 1.26 — so on a CUDA 12 stack use the pinned command above. GPU wheels lag new Python releases too: on a Python without a published wheel the GPU stack can't be pip-installed until one appears. Measured on an RTX 5070 Ti laptop: long VAD-segmented dictations get ~2.3× faster (80s clip: 6.7s → 2.9s), short dictations gain little (~2.1s → ~1.9s) because per-run model load dominates. The first GPU run takes ~40s one time (cuDNN kernel autotuning); later runs are fast. `auto` and `cpu` always stay on CPU.

### Whisper Settings (whisper engine only)
| Setting | Description | Recommended |
|---------|-------------|-------------|
| `model-name` | Whisper model size | `base` (best balance) |
| `model-device` | Device to use (both engines — for parakeet GPU see above) | `cuda` (GPU) or `cpu` |
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
| `cleanup-model` | Ollama model for fast dictation cleanup of standard text | `xhisper-cleanup-1` (after pulling `hf.co/spokenly/cleanup-1-gguf:Q8_0`) |
| `post-process-model` | Ollama instruct model for command/email formatting | `gemma3:4b` |
| `post-process-mode` | Detection mode | `auto` |
| `post-process-standard` | AI pass for standard text (`auto`/`on`/`off`) | `auto` |
| `post-process-timeout` | Max seconds for formatting | `10` |

**Available modes:**
- `auto` - Detects context (commands vs text) automatically
- `standard` - Grammar, punctuation, capitalization
- `command` - Linux command syntax correction (e.g., "pseudo" → "sudo")
- `email` - Email body formatting with proper paragraph breaks

**Dictation cleanup (`cleanup-model`):** [Spokenly cleanup-1](https://huggingface.co/spokenly/cleanup-1) is a 0.6B model fine-tuned specifically for cleaning up dictated text. It runs on every standard-mode dictation, even on top of parakeet's built-in punctuation, and turns:

```
"um can you send that to bob wait no to alice by three pm tomorrow"
```
into:
```
"Can you send that to Alice by 3 pm tomorrow?"
```

What it does: strips filler words ("um", "uh"), applies spoken corrections ("to Bob wait no to Alice" → "to Alice"), formats numbers and dates ("three thousand five hundred dollars" → "$3,500"), writes spoken email/web addresses in their real forms ("john dot smith at gmail dot com" → `john.smith@gmail.com`), and adds punctuation and capitalization.

**Setup** — one download, one config line:
```sh
ollama pull hf.co/spokenly/cleanup-1-gguf:Q8_0    # 639 MB, one time
```
```sh
cleanup-model : xhisper-cleanup-1                 # in ~/.config/xhisper/xhisperrc
```
That's it — from the next dictation on, standard text goes through it (`post-process-standard : off` disables it again).

**Why two different model names?** You *pull* `hf.co/spokenly/cleanup-1-gguf:Q8_0` but *configure* `xhisper-cleanup-1`. The raw model's embedded prompt template ends in `"out: "` with a trailing space, which under greedy decoding makes it return empty output for many inputs — so on first use xhisper creates the `xhisper-cleanup-1` alias in Ollama with a fixed template, temperature 0, and a 4096-token context. Always configure the alias name; check `ollama list` after your first dictation to see it.

**Requirements and limits:**
- Ollama running locally; 639 MB disk, ~0.7-1.1 GB RAM while loaded
- Runs on CPU (~0.3s per sentence, needs AVX2 — any x86-64 CPU from ~2014 on) or GPU (~0.1s)
- Fully offline after the one-time download; Apache-2.0 licensed
- English is best; German, Spanish, French, Chinese, Russian and Japanese work at lower quality — if you dictate mainly in another language (e.g. with the multilingual `nemo-parakeet-tdt-0.6b-v3`), test before relying on it
- Not an instruct model — it cleans text but doesn't follow instructions, so `command`/`email` modes still use `post-process-model`
- On failure or timeout the raw transcription is pasted unchanged (see `xhisper --log`)

`post-process-standard` controls whether plain (non-command/email) text gets an AI pass: with `cleanup-model` set, `auto` runs the cheap cleanup pass (and `on` behaves the same); without it, `auto` skips the instruct LLM when the parakeet engine already punctuates (fastest) and `on` always formats (~1s+ extra per dictation). `off` never processes standard text. Command and email modes always use the instruct LLM.

### Other Settings
- `silence-threshold`: Volume threshold for silence detection (dB, default -50)
- `non-ascii-*-delay`: Timing for Unicode character pasting

---

## Tested Setups

- Custom desktop with a Ryzen 9800X3D and an RTX 5080 (16GB), running Ubuntu 26.04 LTS
- ASUS ROG Zephyrus G14 laptop with an AMD CPU and an RTX 5070 Ti (12GB), running Fedora Workstation 44
- Alienware x14 laptop with an Intel CPU and an RTX 4050 (6GB), running Pop!_OS (COSMIC)

All NVIDIA GPUs; CPU brand matters little — the default Parakeet engine runs fast on any modern CPU and needs no GPU at all.

**Recommended configuration** (same on all of them):

| Component | Model/Setting | Notes |
|-----------|---------------|-------|
| Engine | `parakeet` | More accurate than whisper-base, punctuates natively |
| Parakeet model | `nemo-parakeet-tdt-0.6b-v2` | English, runs fast on CPU |
| Cleanup | `xhisper-cleanup-1` | 0.6B dictation cleanup for standard text, ~0.1-0.3s |
| Formatter | `gemma3:4b` | Used for command/email modes only |
| Mode | `auto` | Detects commands automatically |

This achieves ~1.5s end-to-end for standard dictation (transcription + the 0.6B cleanup pass), or ~1s transcription + Gemma formatting for command/email modes (beware cold Gemma loads: raise `post-process-timeout` if the first command-mode dictation falls back to raw text). Long dictation sessions with thinking pauses are safe: recordings over 25s are VAD-segmented so nothing said after a pause is dropped, and a timed-out formatting pass falls back to your raw transcription instead of pasting truncated text.

---

## Troubleshooting

**Terminal Applications**: Clipboard paste uses Ctrl+V, which doesn't work in terminal emulators (they require Ctrl+Shift+V). Remap Ctrl+V to paste in your terminal's settings, or use `--mode=command` for pure command transcription.

**GPU not detected**: Ensure NVIDIA drivers and CUDA toolkit are installed. Run `nvidia-smi` to verify.

**Formatting not working**: Ensure Ollama is running and the models are pulled (`ollama pull hf.co/spokenly/cleanup-1-gguf:Q8_0`, `ollama pull gemma3:4b`). For cleanup, `xhisper-cleanup-1` should appear in `ollama list` after your first dictation. A failed or timed-out pass falls back to your raw transcription — check `xhisper --log` for the reason.

**Keyboard shortcut conflicts**: Avoid `Ctrl+Space` or `Alt+Space` as they conflict with browsers. Use `Alt+Shift+D` or `Ctrl+Alt+D` instead.

**First run is slow**: Models download on first use and are cached in `~/.cache/xhisper/parakeet/` (Parakeet ~1GB), `~/.cache/huggingface/hub/` (Whisper) and `~/.ollama/models/` (Ollama). Pre-warm before your first dictation:
```sh
python3 -c "import onnx_asr, pathlib; onnx_asr.load_model('nemo-parakeet-tdt-0.6b-v2', pathlib.Path.home()/'.cache/xhisper/parakeet')"
```

---

## Changes from upstream

This is a fork of [xhisper](https://github.com/imaginalnika/xhisper) by [imaginalnika](https://github.com/imaginalnika). The original project used the Groq API for transcription. This fork adds:

- **Parakeet as the default transcription engine** (NVIDIA TDT 0.6B via onnx-asr) — ~2x more accurate than whisper-base in English, punctuates natively, runs fast on CPU; whisper remains available via `transcription-engine`
- **Fast dictation cleanup via [Spokenly cleanup-1](https://huggingface.co/spokenly/cleanup-1)** — a 0.6B model purpose-built for cleaning dictated text (filler words, spoken corrections, numbers, email/web addresses), ~0.1-0.3s per dictation; the script auto-creates a tuned Ollama alias with the correct prompt format and greedy decoding
- **LLM formatting only where it earns its latency** — an instruct LLM (e.g., Gemma) is reserved for command/email modes
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
