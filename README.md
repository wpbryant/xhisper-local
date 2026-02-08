<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <img src="demo.gif" alt="xhisper demo" width="300">
  <br><br>
</div>

Dictation at cursor for Linux. Now with **local Whisper** support - no API keys required!

## Installation

### Dependencies

<details>
<summary>Arch Linux / Manjaro</summary>
<pre><code>sudo pacman -S pipewire ffmpeg gcc python-pip</code></pre>
</details>

<details>
<summary>Debian / Ubuntu / Linux Mint</summary>
<pre><code>sudo apt update
sudo apt install pipewire ffmpeg gcc python3-pip</code></pre>
</details>

<details>
<summary>Fedora / RHEL / AlmaLinux / Rocky</summary>
<pre><code>sudo dnf install -y pipewire pipewire-utils ffmpeg gcc python3</code></pre>
</details>

<details>
<summary>OpenSUSE (Leap / Tumbleweed)</summary>
<pre><code>sudo zypper refresh
sudo zypper install pipewire ffmpeg gcc python3</code></pre>
</details>

<details>
<summary>Void Linux</summary>
<pre><code>sudo xbps-install -S
sudo xbps-install pipewire ffmpeg gcc python3-pip</code></pre>
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
pip install --break-system-packages faster-whisper
```
Or use a venv if preferred.

3. Clone the repository and install:
```sh
git clone https://git.bryantnet.net/william/xhisper-local.git
cd xhisper-local && make
sudo make install
```

4. Configure the model (optional):
```sh
mkdir -p ~/.config/xhisper
cp default_xhisperrc ~/.config/xhisper/xhisperrc
# Edit ~/.config/xhisper/xhisperrc to change model size, device, etc.
```

5. Bind `xhisper` binary to your favorite key:

<details>
<summary>keyd</summary>

```ini
[main]
capslock = layer(dictate)

[dictate:C]
d = macro(xhisper)
```
</details>

<details>
<summary>sxhkd</summary>

```
super + d
    xhisper
```
</details>

<details>
<summary>i3 / sway</summary>

```
bindsym $mod+d exec xhisper
```
</details>

<details>
<summary>Hyprland</summary>

```
bind = $mainMod, D, exec, xhisper
```
</details>

---

## Usage

Simply run `xhisper` twice (via your favorite keybinding):
- **First run**: Starts recording
- **Second run**: Stops and transcribes

The transcription will be typed at your cursor position.

**View logs:**
```sh
xhisper --log
```

**Non-QWERTY layouts:**

For non-QWERTY layouts (e.g. Dvorak, International), set up an input switch key to QWERTY (e.g. rightalt). Then instead of binding to `xhisper`, bind to:
```sh
xhisper --<your-input-switch-key>
```

**Available input switch keys:** `--leftalt`, `--rightalt`, `--leftctrl`, `--rightctrl`, `--leftshift`, `--rightshift`, `--super`

Key chords (like ctrl-space) not available yet.

---

## Configuration

Configuration is read from `~/.config/xhisper/xhisperrc`:

```sh
mkdir -p ~/.config/xhisper
cp default_xhisperrc ~/.config/xhisper/xhisperrc
```

Available settings:
- `model-name`: Whisper model size (tiny, base, small, medium, large-v3)
- `model-device`: Device to use (auto, cpu, cuda)
- `model-language`: Language code for faster transcription (e.g., en, es, fr)
- `transcription-prompt`: Context words for better accuracy
- `silence-threshold`: Volume threshold for silence detection (dB)
- `non-ascii-*-delay`: Timing for Unicode character pasting

---

## Troubleshooting

**Terminal Applications**: Clipboard paste uses Ctrl+V, which doesn't work in terminal emulators (they require Ctrl+Shift+V). Temporary workaround is to remap Ctrl+V to paste in your terminal emulator's settings. Note that *this limitation only affects international/Unicode characters*. ASCII characters (a-z, A-Z, 0-9, punctuation) are typed directly and doesn't care whether terminal or not.

**Non-ASCII Transcription**: Increase non-ascii-*-delay to give the transcription longer timing buffer.

**GPU not detected**: Ensure CUDA is installed if you want GPU acceleration. Otherwise, set `model-device : cpu` in your config.

**First run is slow**: The model downloads on first use. This is cached in `~/.cache/huggingface/hub/`.

---

## Changes from upstream

This fork replaces the Groq API with local Whisper transcription using `faster-whisper`:
- No API key required
- Works completely offline
- GPU acceleration via CUDA
- Configurable model sizes for speed/accuracy tradeoff

---

<p align="center">
  <em>Low complexity dictation for Linux</em>
</p>
