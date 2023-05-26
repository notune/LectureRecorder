# Lecture Recorder
[![Codemagic build status](https://api.codemagic.io/apps/644ad786c8eb18dd0cf43f16/644ad786c8eb18dd0cf43f15/status_badge.svg)](https://codemagic.io/apps/644ad786c8eb18dd0cf43f16/644ad786c8eb18dd0cf43f15/latest_build)

Lecture Recorder is a cross-platform app that allows you to record lectures using your mobile device. The app records audio via the built-in microphone and synchronizes it with the linked slides, creating a video file for future reference. The app is compatible with Android and iOS.

<a href="https://apps.apple.com/app/lecturerecorder-slides-audio/id6449231186">
  <img src="https://github.com/dravolin/LectureRecorder/raw/main/assets/app-store-badge.png" height="50"/> 
</a>
<a href="https://play.google.com/store/apps/details?id=me.muehl.lecture_recorder"> 
  <img src="https://github.com/dravolin/LectureRecorder/raw/main/assets/play-store-badge.png" height="50" />
</a>

## How it works

The App keeps track of which slides you go to while recording the audio to later merge it into one video file. This takes a few minutes depending on your device.

## System Requirements
Minimum Android 8.0 (API 26) or iOS 12.1

## Disclaimer
Before using this application to record lectures, please be aware of your local and national laws regarding the recording of conversations without consent. Regulations vary by location and violation of these laws could have legal consequences. Also, always adhere to your educational institution's policies on lecture recording. When in doubt, it's best to ask your professor for permission before recording. Always respect individual privacy and intellectual property rights. Please remember that recordings should be used for personal reference only and should not be distributed without explicit permission.

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

This project is licensed under the GPL-3.0 license. See the [LICENSE](LICENSE) file for more details.
