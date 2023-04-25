import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:file_picker/file_picker.dart';
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
          _pdfDocumentLoader = PdfDocumentLoader.openAsset(
              file.path); // This line can be removed.
          _pdfDocument = doc;
        });
      }
    } catch (e) {
      print('Error while picking the PDF file: $e');
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
