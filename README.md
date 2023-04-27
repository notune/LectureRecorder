# Lecture Recorder

Lecture Recorder is a cross-platform app that allows users to record lectures using their mobile devices. The app records audio via the built-in microphone and synchronizes it with the linked slides, creating a video file for future reference. The app has been tested and is compatible with Android and iOS. Note that the web app is currently not functional.

## How it works

The App keeps track of which slides you go to while recording the audio to later merge it into one video file. This takes a few minutes depending on your device.

## Building

### Prerequisites

Flutter SDK 2.19.6 or later

### Building

```
git clone https://github.com/dravolin/LectureRecorder.git
cd LectureRecorder/lecture_recorder
flutter pub get
flutter run
```

# License

This project is licensed under the Apache 2.0 License. See the LICENSE file for more details.