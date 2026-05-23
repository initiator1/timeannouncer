#!/usr/bin/env python3
import argparse
import json
import sys

import numpy as np
import soundfile as sf
from kokoro import KPipeline


def synthesize_with_pipeline(
    pipeline: KPipeline,
    text: str,
    voice: str,
    output: str,
    speed: float,
) -> None:
    generator = pipeline(text, voice=voice, speed=speed, split_pattern=r"\n+")

    chunks = []
    for _, _, audio in generator:
        chunks.append(np.asarray(audio, dtype=np.float32))

    if not chunks:
        raise RuntimeError("Kokoro returned no audio chunks")

    audio = chunks[0] if len(chunks) == 1 else np.concatenate(chunks)
    sf.write(output, audio, 24000)


def synthesize(text: str, voice: str, output: str, lang_code: str, speed: float) -> None:
    pipeline = KPipeline(lang_code=lang_code, repo_id="hexgrad/Kokoro-82M")
    synthesize_with_pipeline(pipeline, text, voice, output, speed)


def run_server(lang_code: str, default_voice: str, default_speed: float) -> int:
    pipeline = KPipeline(lang_code=lang_code, repo_id="hexgrad/Kokoro-82M")
    print(json.dumps({"ready": True}), flush=True)

    for raw_line in sys.stdin:
        raw_line = raw_line.strip()
        if not raw_line:
            continue

        try:
            request = json.loads(raw_line)
            synthesize_with_pipeline(
                pipeline,
                text=request["text"],
                voice=request.get("voice", default_voice),
                output=request["output"],
                speed=float(request.get("speed", default_speed)),
            )
            print(json.dumps({"ok": True}), flush=True)
        except Exception as exc:
            print(json.dumps({"ok": False, "error": str(exc)}), flush=True)

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Synthesize speech with Kokoro 82M")
    parser.add_argument("--server", action="store_true")
    parser.add_argument("--text")
    parser.add_argument("--voice", default="af_heart")
    parser.add_argument("--output")
    parser.add_argument("--lang-code", default="a")
    parser.add_argument("--speed", type=float, default=1.0)
    args = parser.parse_args()

    if args.server:
        return run_server(args.lang_code, args.voice, args.speed)

    if not args.text or not args.output:
        parser.error("--text and --output are required unless --server is used")

    try:
        synthesize(args.text, args.voice, args.output, args.lang_code, args.speed)
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
