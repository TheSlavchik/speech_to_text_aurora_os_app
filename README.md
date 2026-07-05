[Omsk State Technical University (OmSTU)](https://omgtu.ru)  

"SpeechToText" — an offline voice recorder with on-device speech-to-text transcription, developed in C++/Qt (Sailfish Silica) for running on Aurora OS.

Record a lecture, a meeting or an idea — the app transcribes the speech and saves a note with both text and audio that you can search through. Transcription is performed entirely on the device using the [Vosk](https://alphacephei.com/vosk/) speech recognition engine: no internet connection is required and the recordings are never uploaded anywhere.

Key features:

- microphone recording with start/stop, duration and signal level indication;
- background on-device transcription with progress indication and cancellation;
- long recordings are processed in chunks and the text is stitched together;
- notes (title + date + audio file + text) stored in the application data directory;
- note viewing with audio playback;
- full-text search through the transcripts;
- text export to a file or to the clipboard.

## Project Build

- Install the [Aurora SDK](https://developer.auroraos.ru/doc/software_development/sdk) (Aurora Build Tools together with Qt Creator) and set up the emulator or a connection to a real device according to the [documentation](https://developer.auroraos.ru/doc)  
- Open `ru.omstu.SpeechToText.pro` in Qt Creator and select the `AuroraOS-…-aarch64` (device) or `AuroraOS-…-x86_64` (emulator) kit  
- (Optional, required for actual speech recognition) Enable the Vosk engine by passing the directory that contains `vosk_api.h` and `libvosk.so` to qmake: `qmake VOSK_DIR={path/to/vosk}`. Without Vosk the app still builds and runs, but transcription reports that the speech engine is not available  
- Build the project (Ctrl+B) — an RPM package is produced in `build/…/RPMS/`  
- Put a Vosk speech model (e.g. [`vosk-model-small-ru`](https://alphacephei.com/vosk/models)) on the device into `~/.local/share/ru.omstu.SpeechToText/model` or bundle it into the package at `/usr/share/ru.omstu.SpeechToText/model`  

## Package Signing and Installation on Device

- The RPM package is signed automatically by Qt Creator with the configured key (a developer key by default); alternatively sign it manually following the [package signing guide](https://developer.auroraos.ru/doc/software_development/guides/package_signing)  
- Deploy to the emulator/device directly from Qt Creator (Run, Ctrl+R), or copy the package with the `scp` utility and install it on the device with `pkcon install-local {path/to/signed_rpm_file}`  

## Project members  
Information about the project authors (developers) is provided in [AUTHORS.md](AUTHORS.md).  

## Terms of use  
Copyright © 2026 Omsk State Technical University (Chair of Applied Mathematics and Computer Science).  

The source code of the application is provided under the [BSD-3 Clause](LICENSE.BSD-3-Clause.md) license.  

[Project description in Russian](README.ru.md)  
