/* 
This file is part of Lecture Recorder.

Lecture Recorder is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Lecture Recorder is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Lecture Recorder. If not, see <https://www.gnu.org/licenses/>. 
*/
import 'package:ffmpeg_kit_flutter_https_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_https_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_https_gpl/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'lecture_history.dart';
import 'settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LectureRecorder(),
    );
  }
}

Future<Map<String, dynamic>> getSettings() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int videoQuality = prefs.getInt('videoQuality') ?? 720;
  bool wakelockWhileRecording = prefs.getBool('wakelockWhileRecording') ?? true;

  return {
    'videoQuality': videoQuality,
    'wakelockWhileRecording': wakelockWhileRecording,
  };
}

class LectureRecorder extends StatefulWidget {
  const LectureRecorder({Key? key}) : super(key: key);

  @override
  LectureRecorderState createState() => LectureRecorderState();
}

class LectureRecorderState extends State<LectureRecorder>
    with WidgetsBindingObserver {
  PdfDocumentLoader? _pdfDocumentLoader;
  PdfDocument? _pdfDocument;
  int _currentPageIndex = 0;
  Record? _audioRecorder;
  bool _recorderIsInited = false;
  bool _isRecording = false;
  String _audioPath = '';
  final _stopwatch = Stopwatch();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<List<int>> _slideDurations = [];
  int _backgroundStartTime = 0;
  int _lastTimestamp = 0;
  bool wasInBackground = false;
  int backgroundDuration = 0;
  double _mergeProgress = 0.0;
  Timer? _timer;
  bool _isMerging = false;
  bool _wakelockWhileRecording = true;
  int _videoQuality = 720;
  String _lectureFile = '';

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      WidgetsBinding.instance.addObserver(this);
    }
    _initAudioRecorder();
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _audioRecorder?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isRecording && Platform.isIOS) {
      if (state == AppLifecycleState.paused) {
        // App goes into the background
        _audioRecorder?.pause();
        _backgroundStartTime = DateTime.now().millisecondsSinceEpoch;
        _stopwatch.stop();
        wasInBackground = true;
      } else if (state == AppLifecycleState.resumed) {
        // App comes back to the foreground
        _audioRecorder?.resume();
        if (_backgroundStartTime != 0) {
          int backgroundDuration =
              DateTime.now().millisecondsSinceEpoch - _backgroundStartTime;
          this.backgroundDuration += backgroundDuration;
        }
        _stopwatch.start();
      }
    }
  }

  Future<void> _initAudioRecorder() async {
    _audioRecorder = Record();

    // Request microphone permission
    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }
    }
    setState(() {
      _recorderIsInited = true;
    });
  }

  void _startRecording() async {
    if (!_recorderIsInited) return;
    _stopwatch.reset();
    _stopwatch.start();

    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyMMddHHmm').format(now);
    _lectureFile = 'lecture_$formattedDate.mp4';

    Map<String, dynamic> settings = await getSettings();
    _videoQuality = settings['videoQuality'];
    _wakelockWhileRecording = settings['wakelockWhileRecording'];

    if (_wakelockWhileRecording) Wakelock.enable();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
    Directory tempDir = await getTemporaryDirectory();
    _audioPath = '${tempDir.path}/audio_record.m4a';
    await _audioRecorder!.start(
      path: _audioPath,
      encoder: AudioEncoder.aacLc,
    );
    setState(() {
      _isRecording = true;
      backgroundDuration = 0;
      wasInBackground = false;
      _lastTimestamp = DateTime.now().millisecondsSinceEpoch;
    });
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _stopwatch.stop();
    _timer?.cancel();
    await _audioRecorder!.stop();
    setState(() {
      _isRecording = false;
      trackSlideDuration();
      _mergeProgress = 0.0;
    });
    // Merge audio and video after stopping the recording
    _generateVideoFromSlides();

    if (_wakelockWhileRecording) Wakelock.disable();
  }

  Future<void> _selectPdfAndLoad() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        _currentPageIndex = 0;
        File file = File(result.files.single.path!);
        final doc = await PdfDocument.openFile(file.path);
        setState(() {
          _pdfDocumentLoader = PdfDocumentLoader.openFile(file.path);
          _pdfDocument = doc;
        });
      }
    } catch (e) {
      _showErrorDialog('Error while picking the PDF file: $e');
    }
  }

  Future<void> deleteAudio() async {
    File audioFile = File(_audioPath);
    if (await audioFile.exists()) await audioFile.delete();
  }

  void _generateVideoFromSlides() async {
    if (_pdfDocument == null) return;
    setState(() {
      _isMerging = true;
    });

    List<File> slideImages = [];

    // Convert PDF pages to images
    for (int i = 0; i < _pdfDocument!.pageCount; i++) {
      final page = await _pdfDocument!.getPage(i + 1);
      final aspectRatio = page.width / page.height;
      final targetHeight = _videoQuality;
      final targetWidth = (aspectRatio * targetHeight).round();
      final pdfImage =
          await page.render(width: targetWidth, height: targetHeight);
      final image = img.Image.fromBytes(
        pdfImage.width,
        pdfImage.height,
        pdfImage.pixels.buffer.asUint8List(),
        format: img.Format.rgba,
      );
      final pngBytes = img.encodePng(image);
      final tempDir = await getTemporaryDirectory();
      final imageFile = File('${tempDir.path}/slide_$i.png');
      await imageFile.writeAsBytes(pngBytes);

      slideImages.add(imageFile);
    }

    // Generate video from slide images
    Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    Directory tempDir = await getTemporaryDirectory();

    final outputPath = '${appDocumentsDir.path}/$_lectureFile';

    final concatFileContent =
        'ffconcat version 1.0\n${List.generate(_slideDurations.length, (i) {
      String result =
          'file ${slideImages[_slideDurations[i][0]].path}\nduration ${_slideDurations[i][1] / 1000}';
      // Duplicate the last file after the final duration
      if (i == _slideDurations.length - 1) {
        result += '\nfile ${slideImages[_slideDurations[i][0]].path}';
      }
      return result;
    }).join('\n')}';

    final concatFilePath = '${tempDir.path}/concat.txt';
    final concatFile = File(concatFilePath);
    await concatFile.writeAsString(concatFileContent);

    // Generate the video using the concat demuxer
    bool isSuccess = false;

    bool isFirstCommand =
        true; // Add a flag to check which command is being executed to calc the progress
    double totalProgress = 0.0;

    FFmpegKitConfig.enableStatisticsCallback((statistics) {
      double timeInSec = statistics.getTime() / 1000;
      double totalTimeInSec = _stopwatch.elapsed.inSeconds.toDouble();
      if (totalTimeInSec == 0) return;
      double progress = (timeInSec / totalTimeInSec).clamp(0, 1);
      if (isFirstCommand) {
        totalProgress = progress * 0.5;
      } else {
        totalProgress = 0.5 + progress * 0.5;
      }
      setState(() {
        _mergeProgress = totalProgress;
      });
    });

    File mergedFile = File(_lectureFile);

    // First pass: generate a VFR video
    final vfrOutputPath = '${tempDir.path}/vfr_video.mp4';

    await FFmpegKit.execute(
            '-safe 0 -i $concatFilePath -i $_audioPath -c:v libx264 -preset ultrafast -vsync vfr -vf "scale=-2:$_videoQuality" -pix_fmt yuv420p -c:a copy -y $vfrOutputPath')
        .then((session) async {
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        var output = await session.getAllLogsAsString();
        await deleteAudio();
        _showErrorDialog('Error creating video: $output');
      }
    });

    isFirstCommand = false;

    // Second pass: convert the VFR video to CFR
    await FFmpegKit.execute(
            '-i $vfrOutputPath -vf "fps=5" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a copy -y $outputPath')
        .then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        //delete audio and video files
        deleteAudio();
        //share the lecture video
        await Share.shareFiles([outputPath]);
        isSuccess = true;
      } else {
        var output = await session.getAllLogsAsString();
        await deleteAudio();
        _showErrorDialog('Error creating video: $output');
      }
    });

    // Clean up temporary slide image files and concat file
    for (final imageFile in slideImages) {
      await imageFile.delete();
    }
    await concatFile.delete();

    await File(vfrOutputPath).delete();

    if (!isSuccess) {
      _showErrorDialog('An unknown error occurred while merging the video.');
      setState(() {
        _isMerging = false;
      });
      return;
    }

    if (await mergedFile.exists()) await mergedFile.delete();
    //reset vars
    _isRecording = false;
    _slideDurations = [];
    setState(() {
      _isMerging = false;
    });
  }

  int getPdfPageCount() {
    if (_pdfDocument == null) {
      return 0;
    }
    return _pdfDocument!.pageCount;
  }

  void _showErrorDialog(String errorMessage) {
    BuildContext context = _scaffoldKey.currentContext!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error Occurred'),
          content: SingleChildScrollView(
            // <-- Wrap the Text widget with SingleChildScrollView
            child: Text(errorMessage),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Copy Error Message'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: errorMessage));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error message copied to clipboard'),
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void trackSlideDuration() {
    int duration = DateTime.now().millisecondsSinceEpoch - _lastTimestamp;
    _lastTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (wasInBackground) {
      duration -= backgroundDuration;
    }
    _slideDurations.add([_currentPageIndex, duration]);
    backgroundDuration = 0;
    wasInBackground = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Lecture Recorder'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings,
                color:
                    (_isRecording || _isMerging) ? Colors.grey : Colors.white),
            onPressed: (_isRecording || _isMerging)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Settings()),
                    );
                  },
          ),
          IconButton(
            icon: Icon(Icons.history,
                color:
                    (_isRecording || _isMerging) ? Colors.grey : Colors.white),
            onPressed: (_isRecording || _isMerging)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LectureHistory()),
                    );
                  },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_isMerging)
              SizedBox(
                height: 80,
                width: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    _mergeProgress > 0
                        ? CircularProgressIndicator(
                            value: _mergeProgress,
                          )
                        : const CircularProgressIndicator(),
                    if (_mergeProgress > 0)
                      Text(
                        '${(_mergeProgress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                      ),
                  ],
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Visibility(
                    visible: _pdfDocumentLoader != null,
                    child: IconButton(
                      onPressed:
                          _isRecording ? _stopRecording : _startRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    ),
                  ),
                  if (_isRecording)
                    Text(
                      '${_stopwatch.elapsed.inHours.toString().padLeft(2, '0')}:${_stopwatch.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_stopwatch.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
              ),
            if (_pdfDocumentLoader != null)
              Expanded(
                child: Center(
                  child: PdfPageView(
                    pdfDocument: _pdfDocument!,
                    pageNumber: _currentPageIndex + 1,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (_pdfDocumentLoader == null)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Tap "+" to add lecture slides PDF',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                else
                  Visibility(
                    visible: _pdfDocumentLoader != null,
                    child: IconButton(
                      //Backwards Button
                      onPressed: _currentPageIndex > 0 && !_isMerging
                          ? () {
                              if (_isRecording) {
                                trackSlideDuration();
                              }
                              setState(() {
                                _currentPageIndex--;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                Visibility(
                  visible: _pdfDocumentLoader != null,
                  child: IconButton(
                    //Forward Button
                    onPressed: !_isMerging &&
                            _pdfDocument != null &&
                            _currentPageIndex + 1 < getPdfPageCount()
                        ? () {
                            if (_isRecording) {
                              trackSlideDuration();
                            }
                            setState(() {
                              _currentPageIndex++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: Visibility(
        visible: !_isMerging && !_isRecording,
        child: FloatingActionButton(
          onPressed: () {
            _selectPdfAndLoad();
          },
          tooltip: 'Select PDF',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
