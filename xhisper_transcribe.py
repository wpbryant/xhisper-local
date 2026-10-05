#!/usr/bin/env python3
"""
xhisper transcription module
Transcribes audio files locally with faster-whisper or NVIDIA Parakeet (onnx-asr).
"""

import os
import sys
import wave
import argparse
import logging
from pathlib import Path

# Configure logging to suppress verbose output
logging.getLogger("faster_whisper").setLevel(logging.WARNING)

# Compat: PyAV 15+ removed the metadata_errors argument from av.open(), but
# faster-whisper 1.2.x still passes it, which crashes every transcription
# with "open() got an unexpected keyword argument 'metadata_errors'".
# Shim av.open to drop the argument until faster-whisper catches up.
try:
    import av

    if int(av.__version__.split(".")[0]) >= 15:
        _av_open = av.open

        def _av_open_compat(*args, **kwargs):
            kwargs.pop("metadata_errors", None)
            return _av_open(*args, **kwargs)

        av.open = _av_open_compat
except ImportError:
    pass

def transcribe_file(
    audio_path: str,
    model_size: str = "base",
    device: str = "auto",
    language: str = None,
    prompt: str = None,
    vad_min_silence_ms: int = 5000,
) -> str:
    """
    Transcribe an audio file using faster-whisper.

    Args:
        audio_path: Path to the audio file (WAV, MP3, etc.)
        model_size: Model size (tiny, base, small, medium, large-v1, large-v2, large-v3)
        device: Device to use (auto, cpu, cuda)
        language: Language code (e.g., 'en', 'es') or None for auto-detect
        prompt: Optional context text for better accuracy
        vad_min_silence_ms: Silence (ms) before the VAD splits segments; raise
            this if speech after a thinking pause gets dropped

    Returns:
        Transcribed text
    """
    from faster_whisper import WhisperModel

    # Initialize model
    model = WhisperModel(
        model_size,
        device=device,
        compute_type="float16" if device == "cuda" else "int8",
    )

    # Transcribe
    segments, info = model.transcribe(
        audio_path,
        language=language,
        initial_prompt=prompt,
        beam_size=5,
        vad_filter=True,  # Voice activity detection to remove silence
        vad_parameters={"min_silence_duration_ms": vad_min_silence_ms},
        condition_on_previous_text=False,  # avoids repetition drift after pauses
    )

    # Combine all segments
    text = " ".join(segment.text for segment in segments)

    # Clean up extra whitespace
    text = " ".join(text.split())

    return text


# onnx-asr guidance: most models handle only 20-30s of audio per shot, so
# longer recordings must be segmented with a VAD before recognition.
_PARAKEET_VAD_THRESHOLD_S = 25.0

# Download parakeet models as real files into our own cache dir. The HF hub
# cache stores them as content-addressed blobs behind symlinks, which breaks
# ONNX external-data validation ("External data path escapes model directory").
_PARAKEET_MODEL_DIR = (
    Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "xhisper" / "parakeet"
)


def _wav_duration_s(audio_path: str):
    """Duration of a wav file in seconds, or None if unreadable."""
    try:
        with wave.open(audio_path) as w:
            return w.getnframes() / w.getframerate()
    except Exception:
        return None


def transcribe_parakeet(audio_path: str, model_name: str) -> str:
    """
    Transcribe an audio file using NVIDIA Parakeet via onnx-asr.

    Output is already punctuated and capitalized, which is most of what the
    standard LLM post-processing pass would do.
    """
    try:
        import onnx_asr
    except ImportError:
        print(
            "Error: engine 'parakeet' requires the onnx-asr package. "
            "Install it with: pip3 install --break-system-packages onnx-asr",
            file=sys.stderr,
        )
        sys.exit(1)

    model = onnx_asr.load_model(model_name, _PARAKEET_MODEL_DIR)

    duration = _wav_duration_s(audio_path)
    if duration is not None and duration > _PARAKEET_VAD_THRESHOLD_S:
        # Long clip: segment with silero VAD so each chunk stays inside the
        # model's window. 5s min-silence keeps thinking pauses intact — a
        # pause becomes a chunk boundary, never dropped audio.
        vad = onnx_asr.load_vad("silero")
        model = model.with_vad(vad, min_silence_duration_ms=5000.0)
        results = model.recognize(audio_path)
        if isinstance(results, str):  # defensive: adapter may return a plain str
            return results.strip()
        return " ".join(
            r.text if hasattr(r, "text") else str(r) for r in results
        ).strip()

    return model.recognize(audio_path).strip()


def main():
    parser = argparse.ArgumentParser(
        description="Transcribe audio files using faster-whisper or Parakeet"
    )
    parser.add_argument("audio_file", help="Path to audio file to transcribe")
    parser.add_argument(
        "--engine",
        default="whisper",
        choices=["whisper", "parakeet"],
        help="Transcription engine (default: whisper)",
    )
    parser.add_argument(
        "--parakeet-model",
        default="nemo-parakeet-tdt-0.6b-v2",
        help="onnx-asr model name for the parakeet engine "
        "(nemo-parakeet-tdt-0.6b-v2 = English, nemo-parakeet-tdt-0.6b-v3 = multilingual)",
    )
    parser.add_argument(
        "--model",
        default="base",
        help="Whisper model size: tiny, base, small, medium, large-v3 (default: base)",
    )
    parser.add_argument(
        "--device",
        default="auto",
        choices=["auto", "cpu", "cuda"],
        help="Device to use (default: auto)",
    )
    parser.add_argument(
        "--language",
        help="Language code (e.g., en, es) for faster/more accurate transcription",
    )
    parser.add_argument(
        "--prompt",
        help="Context words for better accuracy (whisper engine only)",
    )
    parser.add_argument(
        "--vad-min-silence-ms",
        type=int,
        default=5000,
        help="Silence (ms) before the whisper VAD splits segments (default: 5000)",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug output",
    )

    args = parser.parse_args()

    if args.debug:
        logging.getLogger("faster_whisper").setLevel(logging.DEBUG)

    # Check if audio file exists
    if not Path(args.audio_file).exists():
        print(f"Error: Audio file not found: {args.audio_file}", file=sys.stderr)
        sys.exit(1)

    try:
        if args.engine == "parakeet":
            result = transcribe_parakeet(args.audio_file, args.parakeet_model)
        else:
            result = transcribe_file(
                args.audio_file,
                model_size=args.model,
                device=args.device,
                language=args.language,
                prompt=args.prompt,
                vad_min_silence_ms=args.vad_min_silence_ms,
            )
        print(result)
    except Exception as e:
        print(f"Error during transcription: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
