# ANVAYA - Edge-AI Powered Vernacular Pedagogy for Mother-Tongue Primary Education



### 🎥 [Watch the ANVAYA Demo Video Here](https://youtu.be/KAoKCfq-eB0)

## Overview

ANVAYA is a submission to **Smart India Hackathon 2026** for problem statement **SIH26042**, built around the **NIPUN Bharat** Foundational Literacy & Numeracy (FLN) mission. It targets tribal-belt primary schools teaching in **Santali (Ol Chiki script)**, where classrooms run on legacy government-issued Android tablets with no reliable internet access.

Every screen, lookup, audio clip, and PDF export in ANVAYA resolves from on-device storage — there is no backend, no live API call, and no dependency on connectivity at any point in the classroom-facing runtime. The app is deployed once via APK and behaves identically whether the device has ever been online or not, so it bypasses the internet-access constraint that would otherwise block digital FLN delivery in these schools entirely.

## Core Features

- **Air-Gapped Architecture** — Zero network calls anywhere in the classroom-facing app. All curriculum content, vocabulary, audio, and layout logic ship pre-bundled in the APK at build time.
- **Active Math Manipulatives** — A drag-and-drop "Equal Sharing" division tool where students physically distribute apples/pastries into baskets/plates to build division intuition (e.g. 9 ÷ 3), with real-time correctness feedback.
- **Automated ORF Stopwatch** — A NIPUN Bharat-aligned Oral Reading Fluency assessment: a teacher times a student's reading, flags stumbled words tap-by-tap, and the app computes Words-Per-Minute (WPM) automatically from elapsed time and mistake count.
- **Localized Audio Delivery** — Bilingual (Hindi ⇄ Santali) instruction cards, multiplication chants, and Q&A prompts each play their own local audio clip on demand, with dynamic keyword-intent matching for spoken/typed classroom commands.
- **Teacher Resource Vault** — Lesson plans, worksheet generation, and other classroom resources, including **native on-device PDF generation** (bilingual worksheets, lesson plan summaries) exported straight to the OS print/share sheet — no server round-trip.

## Tech Stack

| Layer | Technology |
|---|---|
| Application shell | **Flutter** (Dart) |
| Persistent storage | **SQLite** (`sqflite` / `sqflite_common_ffi`) — vocabulary, practice-flags, and activity-log tables |
| Audio playback | **`audioplayers`** — local asset-backed offline audio playback |
| Document generation | **`pdf` / `printing`** — on-device PDF composition with embedded local fonts, exported via the native print/share sheet |
| Edge AI | **Vosk ASR** (`vosk_flutter`) — on-device speech recognition via a pre-bundled acoustic model, no cloud speech endpoint |

## Run Instructions

### Prerequisites
- Flutter SDK (stable channel) with the Android toolchain configured

### Build & Run

```bash
# 1. Resolve dependencies
flutter pub get

# 2. Build the release APK
flutter build apk --release
```

The release artifact is emitted to `build/app/outputs/flutter-apk/app-release.apk`.

## Team InnovexaX

- **Mohammed Muzammil** — Roll No: 160124733254
- **[Teammate Name]** — Roll No: [XXXXXXXXXXXX]
