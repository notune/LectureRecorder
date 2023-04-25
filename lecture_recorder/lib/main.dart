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
  String _audioPath =
      'audio_record.mp4'; // You can choose your preferred audio format

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
    await _audioRecorder!.startRecorder(
      toFile: _audioPath,
      codec: Codec.aacMP4,
      audioSource: AudioSource.microphone,
    );
    setState(() {
      _isRecording = true;
    });
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    await _audioRecorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    //_mergeAudioAndVideo(videoPath, audioPath)
  }

  // Other variables and methods for handling audio, video, and recording will be placed here.
  // ...
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

  void _mergeAudioAndVideo(String videoPath, String audioPath) async {
    final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
    String outputPath = 'merged_output.mp4'; // Output file path
    int returnCode = await _flutterFFmpeg.execute(
        '-i $videoPath -i $audioPath -c copy -map 0:v:0 -map 1:a:0 $outputPath');

    if (returnCode == 0) {
      // Success
      print('Merged video and audio successfully: $outputPath');
    } else {
      // Error
      print('Error merging video and audio: $returnCode');
    }
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
                  onPressed: _currentPageIndex > 0
                      ? () {
                          setState(() {
                            _currentPageIndex--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  onPressed: () {
                    // Implement a method to get the total number of pages in the PDF
                    // and use it to check if the _currentPageIndex is within the range.
                    setState(() {
                      _currentPageIndex++;
                    });
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
