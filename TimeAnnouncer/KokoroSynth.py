#!/usr/bin/env python3
import argparse
import sys

import numpy as np
import soundfile as sf
from kokoro import KPipeline


def synthesize(text: str, voice: str, output: str, lang_code: str, speed: float) -> None:
    pipeline = KPipeline(lang_code=lang_code, repo_id="hexgrad/Kokoro-82M")
    generator = pipeline(text, voice=voice, speed=speed, split_pattern=r"\n+")

    chunks = []
    for _, _, audio in generator:
        chunks.append(np.asarray(audio, dtype=np.float32))

    if not chunks:
        raise RuntimeError("Kokoro returned no audio chunks")

    audio = chunks[0] if len(chunks) == 1 else np.concatenate(chunks)
    sf.write(output, audio, 24000)


def main() -> int:
    parser = argparse.ArgumentParser(description="Synthesize speech with Kokoro 82M")
    parser.add_argument("--text", required=True)
    parser.add_argument("--voice", default="af_heart")
    parser.add_argument("--output", required=True)
    parser.add_argument("--lang-code", default="a")
    parser.add_argument("--speed", type=float, default=1.0)
    args = parser.parse_args()

    try:
        synthesize(args.text, args.voice, args.output, args.lang_code, args.speed)
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
