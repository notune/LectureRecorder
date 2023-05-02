/*
 * Copyright 2023 Noah Mühl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
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
    return MaterialApp(
      home: const LectureRecorder(),
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
  _LectureRecorderState createState() => _LectureRecorderState();
}

class _LectureRecorderState extends State<LectureRecorder> {
  PdfDocumentLoader? _pdfDocumentLoader;
  PdfDocument? _pdfDocument;
  int _currentPageIndex = 0;
  Record? _audioRecorder;
  bool _recorderIsInited = false;
  bool _isRecording = false;
  String _audioPath = '';
  int _startSlide = 0;
  List<dynamic> _slideTimestamps = [];
  late DateTime _startTime;
  late String _elapsedTime;
  final _stopwatch = Stopwatch();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Timer? _timer;

  bool _isMerging = false;

  bool _wakelockWhileRecording = true;

  int _videoQuality = 720;

  @override
  void initState() {
    super.initState();
    _initAudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    super.dispose();
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

    Map<String, dynamic> settings = await getSettings();
    _videoQuality = settings['videoQuality'];
    _wakelockWhileRecording = settings['wakelockWhileRecording'];

    if (_wakelockWhileRecording) Wakelock.enable();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
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
      _slideTimestamps = [
        [null, DateTime.now().millisecondsSinceEpoch]
      ];
      _startSlide = _currentPageIndex;
      _startTime = DateTime.now();
    });
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _stopwatch.stop();
    _timer?.cancel();
    await _audioRecorder!.stop();
    setState(() {
      _isRecording = false;
      _slideTimestamps.add([null, DateTime.now().millisecondsSinceEpoch]);
    });
    // Merge audio and video after stopping the recording
    _mergeAudioAndVideo();

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
      print('Error while picking the PDF file: $e');
    }
  }

  Future<void> deleteCache(videoPath) async {
    File videoFile = File(videoPath);
    File audioFile = File(_audioPath);
    if (await videoFile.exists()) await videoFile.delete();
    if (await videoFile.exists()) await audioFile.delete();
  }

  Future<bool> _generateVideoFromSlides() async {
    if (_pdfDocument == null) return false;

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
    final tempDir = await getTemporaryDirectory();
    final videoPath = '${tempDir.path}/video_slides.mp4';

    // Create a temporary file with the list of input files and durations
    List<int> slideIndices = [_startSlide];
    List<int> slideDurations = [];

    for (int i = 1; i < _slideTimestamps.length - 1; i++) {
      int duration = _slideTimestamps[i][1] - _slideTimestamps[i - 1][1];
      slideDurations.add(duration);

      if (_slideTimestamps[i][0]) {
        // Forward button pressed
        slideIndices.add(slideIndices.last + 1);
      } else {
        // Backward button pressed
        slideIndices.add(slideIndices.last - 1);
      }
    }
    slideDurations.add(
        _slideTimestamps.last[1]); //get time when the recording was stopped

    final concatFileContent = List.generate(slideIndices.length, (i) {
      return 'file ${slideImages[slideIndices[i]].path}\nduration ${slideDurations[i] / 1000}';
    }).join('\n');
    final concatFilePath = '${tempDir.path}/concat.txt';
    final concatFile = File(concatFilePath);
    await concatFile.writeAsString(concatFileContent);

    // Generate the video using the concat demuxer
    bool isSuccess = false;
    await FFmpegKit.execute(
            '-f concat -safe 0 -i $concatFilePath -vsync vfr -pix_fmt yuv420p -y $videoPath')
        .then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('Generated video from slides successfully: $videoPath');
        isSuccess = true;
      } else {
        var output = await session.getFailStackTrace();
        print('Error generating video from slides: $output');
        await deleteCache(videoPath);
        _showErrorDialog('Error generating video from slides: $output');
      }
    });

    // Clean up temporary slide image files and concat file
    for (final imageFile in slideImages) {
      await imageFile.delete();
    }
    await concatFile.delete();

    return isSuccess;
  }

  void _mergeAudioAndVideo() async {
    setState(() {
      _isMerging = true;
    });
    bool isVideoGenerated = await _generateVideoFromSlides();
    if (!isVideoGenerated) {
      print('Failed to generate video from slides, aborting merge');
      setState(() {
        _isMerging = false;
      });
      return;
    }

    // Merge the video stream with the recorded audio
    Directory tempDir = await getTemporaryDirectory();
    String videoPath = '${tempDir.path}/video_slides.mp4';

    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyMMddHH').format(now);
    Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    String lectureFile = 'lecture_$formattedDate.mp4';
    String outputPath = '${appDocumentsDir.path}/$lectureFile';

    File mergedFile = File(outputPath);
    if (await mergedFile.exists()) await mergedFile.delete();

    await FFmpegKit.execute(
            '-i $videoPath -i $_audioPath -c:v copy -c:a aac $outputPath')
        .then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('Merged video and audio successfully: $outputPath');
        //delete audio and video files
        deleteCache(videoPath);
        //share the lecture video
        await Share.shareFiles([outputPath], text: 'Lecture video');
      } else {
        var output = await session.getFailStackTrace();
        print('Error merging video: $output');
        await deleteCache(videoPath);
        _showErrorDialog('Error merging video: $output');
      }
    });

    //reset vars
    _isRecording = false;
    _slideTimestamps = [];
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
          title: Text('Error Occurred'),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              child: Text('Copy Error Message'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: errorMessage));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error message copied to clipboard'),
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Lecture Recorder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Settings()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LectureHistory()),
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
              CircularProgressIndicator()
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
                      style: TextStyle(fontSize: 16),
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
                  Expanded(
                    child: Center(
                      child: Text(
                        'Add a PDF using the "+" button to get started',
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
                              setState(() {
                                _currentPageIndex--;
                              });
                              if (_isRecording) {
                                _slideTimestamps.add([
                                  false,
                                  DateTime.now().millisecondsSinceEpoch
                                ]);
                              }
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
                            setState(() {
                              _currentPageIndex++;
                            });
                            if (_isRecording) {
                              _slideTimestamps.add([
                                true,
                                DateTime.now().millisecondsSinceEpoch
                              ]);
                            }
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
