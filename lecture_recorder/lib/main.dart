import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

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

class LectureRecorder extends StatefulWidget {
  const LectureRecorder({Key? key}) : super(key: key);

  @override
  _LectureRecorderState createState() => _LectureRecorderState();
}

class _LectureRecorderState extends State<LectureRecorder> {
  PdfDocumentLoader? _pdfDocumentLoader;
  PdfDocument? _pdfDocument;
  int _currentPageIndex = 0;
  FlutterSoundRecorder? _audioRecorder;
  bool _recorderIsInited = false;
  bool _isRecording = false;
  String _audioPath = '';
  List<dynamic> _slideTimestamps = [];

  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _initAudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder?.closeRecorder();
    super.dispose();
  }

  Future<void> _initAudioRecorder() async {
    _audioRecorder = FlutterSoundRecorder();

    // Request microphone permission
    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }
    }

    // Initialize the recorder
    await _audioRecorder!.openRecorder();
    setState(() {
      _recorderIsInited = true;
    });
  }

  void _startRecording() async {
    if (!_recorderIsInited) return;
    Directory tempDir = await getTemporaryDirectory();
    _audioPath = '${tempDir.path}/audio_record.mp4';
    await _audioRecorder!.startRecorder(
      toFile: _audioPath,
      codec: Codec.aacMP4,
      audioSource: AudioSource.microphone,
    );
    setState(() {
      _isRecording = true;
      _slideTimestamps.add([true, DateTime.now().millisecondsSinceEpoch]);
    });
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    await _audioRecorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    // Merge audio and video after stopping the recording
    _mergeAudioAndVideo();
  }

  Future<void> _selectPdfAndLoad() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
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

  Future<void> _generateVideoFromSlides() async {
    if (_pdfDocument == null) return;

    List<File> slideImages = [];

    // Convert PDF pages to images
    for (int i = 0; i < _pdfDocument!.pageCount; i++) {
      final page = await _pdfDocument!.getPage(i + 1);
      final aspectRatio = page.width / page.height;
      final targetHeight = 720;
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

    final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

    // Create a temporary file with the list of input files and durations
    List<int> slideIndices = [0];
    List<int> slideDurations = [];

    for (int i = 1; i < _slideTimestamps.length; i++) {
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
    slideDurations.add(5000); // Set a default duration for the last slide

    final concatFileContent = List.generate(slideIndices.length, (i) {
      return 'file ${slideImages[slideIndices[i]].path}\nduration ${slideDurations[i] / 1000}';
    }).join('\n');
    final concatFilePath = '${tempDir.path}/concat.txt';
    final concatFile = File(concatFilePath);
    await concatFile.writeAsString(concatFileContent);

    // Generate the video using the concat demuxer
    int returnCode = await _flutterFFmpeg.execute(
        '-f concat -safe 0 -i $concatFilePath -vsync vfr -pix_fmt yuv420p -y $videoPath');

    if (returnCode == 0) {
      // Success
      print('Generated video from slides successfully: $videoPath');
    } else {
      // Error
      print('Error generating video from slides: $returnCode');
    }

    // Clean up temporary slide image files and concat file
    for (final imageFile in slideImages) {
      await imageFile.delete();
    }
    await concatFile.delete();

    _flutterFFmpeg.cancel();
  }

  void _mergeAudioAndVideo() async {
    setState(() {
      _isMerging = true;
    });
    await _generateVideoFromSlides();

    // Merge the video stream with the recorded audio
    final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
    Directory tempDir = await getTemporaryDirectory();
    String videoPath = '${tempDir.path}/video_slides.mp4';
    String outputPath = '${tempDir.path}/merged_output.mp4'; // Output file path
    int returnCode = await _flutterFFmpeg.execute(
        '-i $videoPath -i $_audioPath -c copy -map 0:v:0 -map 1:a:0 $outputPath');

    if (returnCode == 0) {
      // Success
      print('Merged video and audio successfully: $outputPath');
      //delete audio and video files
      File videoFile = File(videoPath);
      File audioFile = File(_audioPath);
      await videoFile.delete();
      await audioFile.delete();
    } else {
      // Error
      print('Error merging video and audio: $returnCode');
    }
    _flutterFFmpeg.cancel();
    setState(() {
      _isMerging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture Recorder'),
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
                  IconButton(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
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
                IconButton(
                  //Backwards Button
                  onPressed: _currentPageIndex > 0
                      ? () {
                          setState(() {
                            _currentPageIndex--;
                          });
                          if (_isRecording) {
                            _slideTimestamps.add(
                                [false, DateTime.now().millisecondsSinceEpoch]);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  //Forward Button
                  onPressed: () {
                    // Implement a method to get the total number of pages in the PDF
                    // and use it to check if the _currentPageIndex is within the range.
                    setState(() {
                      _currentPageIndex++;
                    });
                    if (_isRecording) {
                      _slideTimestamps
                          .add([true, DateTime.now().millisecondsSinceEpoch]);
                    }
                  },
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _selectPdfAndLoad();
        },
        tooltip: 'Select PDF',
        child: const Icon(Icons.add),
      ),
    );
  }
}
