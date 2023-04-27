# Lecture Recorder
[![Codemagic build status](https://api.codemagic.io/apps/644ad786c8eb18dd0cf43f16/644ad786c8eb18dd0cf43f15/status_badge.svg)](https://codemagic.io/apps/644ad786c8eb18dd0cf43f16/644ad786c8eb18dd0cf43f15/latest_build)

Lecture Recorder is a cross-platform app that allows you to record lectures using your mobile device. The app records audio via the built-in microphone and synchronizes it with the linked slides, creating a video file for future reference. The app is compatible with Android and iOS.

## How it works

The App keeps track of which slides you go to while recording the audio to later merge it into one video file. This takes a few minutes depending on your device.

## System Requirements
Minimum Android 8.0 (API 26) or iOS 12.1

## Building

### Prerequisites

Flutter SDK 2.19.6 or later

```
git clone https://github.com/dravolin/LectureRecorder.git
cd LectureRecorder/lecture_recorder
flutter pub get
flutter run
```

# License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for more details.
