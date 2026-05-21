#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KOKORO_DIR="${HOME}/Library/Application Support/TimeAnnouncer/Kokoro"
VENV_DIR="${KOKORO_DIR}/venv"
TEST_OUTPUT="${KOKORO_DIR}/setup-test.wav"

mkdir -p "${KOKORO_DIR}"

if ! command -v espeak-ng >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install espeak-ng
  else
    echo "espeak-ng is required. Install it with Homebrew: brew install espeak-ng" >&2
    exit 1
  fi
fi

if command -v uv >/dev/null 2>&1; then
  uv venv --python 3.11 "${VENV_DIR}"
  uv pip install --python "${VENV_DIR}/bin/python" "kokoro>=0.9.4" soundfile "misaki[en]"
else
  python3 -m venv "${VENV_DIR}"
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip
  "${VENV_DIR}/bin/python" -m pip install "kokoro>=0.9.4" soundfile "misaki[en]"
fi

export VIRTUAL_ENV="${VENV_DIR}"
export PATH="${VENV_DIR}/bin:${PATH}"

"${VENV_DIR}/bin/python" "${ROOT_DIR}/TimeAnnouncer/KokoroSynth.py" \
  --text "It's ten thirty." \
  --voice af_heart \
  --output "${TEST_OUTPUT}"

echo "Kokoro is ready: ${VENV_DIR}/bin/python"
echo "Test audio: ${TEST_OUTPUT}"
