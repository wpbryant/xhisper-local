<div align="center">
  <h1>xhisper <i>/ˈzɪspər/</i></h1>
  <b>dictate anywhere in Linux; transcribe at your cursor</b>
  <br><br>
</div>

## One-liner

Dead simple anywhere-dictation (like [WisprFlow](https://wisprflow.ai/)) for Linux.

## Installation

### Dependencies

<details>
<summary>Fedora / RHEL / AlmaLinux / Rocky</summary>
<pre><code>sudo dnf install -y pipewire pipewire-utils jq curl ffmpeg gcc</code></pre>
</details>

<details>
<summary>Arch Linux / Manjaro</summary>
<pre><code>sudo pacman -S pipewire jq curl ffmpeg gcc</code></pre>
</details>

<details>
<summary>Debian / Ubuntu / Linux Mint</summary>
<pre><code>sudo apt update
sudo apt install pipewire jq curl ffmpeg gcc</code></pre>
</details>

<details>
<summary>Void Linux</summary>
<pre><code>sudo xbps-install -S
sudo xbps-install pipewire jq curl ffmpeg gcc</code></pre>
</details>

<details>
<summary>OpenSUSE (Leap / Tumbleweed)</summary>
<pre><code>sudo zypper refresh
sudo zypper install pipewire jq curl ffmpeg gcc</code></pre>
</details>

**Note:** `wl-clipboard` (Wayland) or `xclip` (X11) required but usually pre-installed.

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

2. **Get a Groq API key** from [console.groq.com](https://console.groq.com) (free tier available) and add to `~/.env`:
```sh
GROQ_API_KEY=<your_API_key>
```

3. Clone the repository and install:
```sh
git clone --depth 1 https://github.com/imaginalnika/xhisper.git
cd xhisper && make
sudo make install
```

4. Bind `xhisper` binary to your favorite key:

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

Simply run `xhisper` twice:
- **First run**: Starts recording
- **Second run**: Stops and transcribes

The transcription will be typed at your cursor position.

For non-QWERTY layouts, set up an input switch key to QWERTY (e.g. rightalt). Then instead of `xhisper`, bind your favorite key to:
```sh
xhisper --rightalt
```

**Available wrap keys:** `--leftalt`, `--rightalt`, `--leftctrl`, `--rightctrl`, `--leftshift`, `--rightshift`, `--super`

Key chords (like ctrl-space) not available yet.

The daemon (`xhispertoold`) auto-starts when needed.

---

## Configuration

Edit variables at the top of `xhisper`:

| Variable                     | Default | Description                                      |
|------------------------------|---------|--------------------------------------------------|
| `LONG_RECORDING_THRESHOLD`   | `1000`  | Seconds threshold for large model (in seconds)   |
| `TRANSCRIPTION_PROMPT`       | Custom  | Context words for better Whisper accuracy        |

## Troubleshooting

**Terminal Applications**: The clipboard paste functionality uses Ctrl+V, which doesn't work in terminal emulators (they require Ctrl+Shift+V). Temporary workaround is to remap Ctrl+V to paste in your terminal emulator's settings. Note that *this limitation only affects international/Unicode characters*. ASCII characters (a-z, A-Z, 0-9, punctuation) are typed directly and work in all applications including terminals.

---

<p align="center">
  <em>Low complexity dictation for Linux</em>
</p>
