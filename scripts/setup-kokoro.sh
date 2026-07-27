#!/usr/bin/env bash
set -euo pipefail

# Resolve KokoroSynth.py whether this runs from the git checkout OR from inside
# a shipped .app bundle (2026-07-26 fix). The released DMG contains 25 files and
# no `scripts/` directory, yet the app's own dialog told users to run
# "./scripts/setup-kokoro.sh from the project directory" — a directory a
# downloader does not have. Two of three advertised voices were unreachable for
# every real user. The venv itself always lived under Application Support, so
# only this path resolution and the dialog text were repo-bound.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../TimeAnnouncer/KokoroSynth.py" ]; then
  SYNTH_PY="${SCRIPT_DIR}/../TimeAnnouncer/KokoroSynth.py"   # git checkout
elif [ -f "${SCRIPT_DIR}/KokoroSynth.py" ]; then
  SYNTH_PY="${SCRIPT_DIR}/KokoroSynth.py"                     # inside the .app
else
  echo "Cannot find KokoroSynth.py beside this script or in ../TimeAnnouncer." >&2
  exit 1
fi

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

"${VENV_DIR}/bin/python" "${SYNTH_PY}" \
  --text "It's ten thirty." \
  --voice af_heart \
  --output "${TEST_OUTPUT}"

echo "Kokoro is ready: ${VENV_DIR}/bin/python"
echo "Test audio: ${TEST_OUTPUT}"
