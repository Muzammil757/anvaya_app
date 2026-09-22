# ANVAYA — AI-Assisted 100% Offline Mother-Tongue FLN Platform

Smart India Hackathon submission — a fully air-gapped Foundational Literacy &
Numeracy (FLN) delivery platform for tribal-belt classrooms with no
connectivity guarantee.

## 1. Project Overview

ANVAYA runs entirely on-device. There is no backend, no live API dependency,
and no network call anywhere in the classroom-facing runtime — every screen,
lookup, and playback resolves from local storage. The platform targets
low-cost Android tablets deployed in bandwidth-constrained or fully
unconnected schools, where teachers deliver bilingual (Hindi ⇄ Santali / Ol
Chiki) content without any assumption of cluster sync, cloud inference, or
even intermittent signal. All curriculum content, pronunciation audio, and
intent-matching logic ship pre-bundled in the APK at build time; the app is
functionally identical on first launch as it is permanently disconnected.

## 2. Key Features

- **Instruction Mode** — An offline classroom command board driven by a
  dynamic keyword-intent dictionary: bilingual (English/Hindi) mic or typed
  input is resolved against a multi-synonym keyword set per command (e.g.
  "quiet" / "silence" / "चुप" / "शांत" all route to the same intent) with no
  network round-trip. A match triggers local MP3 playback and a bilingual
  (English / Ol Chiki) instruction card in a single on-device pass.
- **Worksheet Generator** — Generates bilingual practice sheets (Match the
  Following, Trace & Write) from the on-device "needs practice" queue, plus
  standard offline topic templates (Addition, Subtraction, Shapes &
  Patterns). PDFs are rendered locally with embedded Devanagari / Ol Chiki
  fonts and exported via the native print/share sheet — no server round-trip
  for generation or export.
- **Lecture Delivery Registry** — A synchronized bilingual flashcard/chant
  slideshow with an Interactive Classroom Scene mode, backed by a local
  activity log (SQLite) that timestamps every unit start, resume, and
  completion for the Archive/Vault review screen.

## 3. Tech Stack

| Layer | Technology |
|---|---|
| Application shell | **Flutter** (Dart), single codebase for Android/Windows/macOS/Web targets |
| Persistent storage | **SQLite** (`sqflite` / `sqflite_common_ffi`) — vocabulary, practice-flags, and activity-log tables, no ORM |
| Offline ASR | **Vosk** (`vosk_flutter`), AOT pre-bundled acoustic model (`vosk-model-small-en-us-0.15`) shipped in `assets/models/` — no cloud speech endpoint |
| Audio playback | **Native Audioplayers** (`audioplayers`) — local asset-backed WAV/MP3 playback, zero streaming |
| Document generation | `pdf` / `printing` — on-device PDF composition with embedded local TTF fonts |
| Local state | `shared_preferences` for ephemeral UI history (recent worksheets, instruction board) |

## 4. Quick Start / Installation

### Prerequisites
- Flutter SDK (stable channel) with the Android toolchain configured
- Android SDK / Gradle (bundled via the Flutter Android embedding)

### Build a release APK

```bash
# 1. Clone and enter the project
git clone <repository-url>
cd anvaya_app

# 2. Resolve dependencies
flutter pub get

# 3. Build the release APK
flutter build apk --release
```

The signed/unsigned release artifact is emitted to:

```
build/app/outputs/flutter-apk/app-release.apk
```

Install directly on a target device for fully offline evaluation:

```bash
flutter install --release
```

No `.env`, API key, or network reachability check is required at build or
run time — all curriculum, audio, ASR model, and font assets are packaged
into the APK via `pubspec.yaml`'s `assets:` manifest.
