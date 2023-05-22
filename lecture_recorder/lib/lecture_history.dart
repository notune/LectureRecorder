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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_extend/share_extend.dart';

class LectureHistory extends StatefulWidget {
  const LectureHistory({Key? key}) : super(key: key);

  @override
  _LectureHistoryState createState() => _LectureHistoryState();
}

class _LectureHistoryState extends State<LectureHistory> {
  late List<String> lectureFiles = [];

  @override
  void initState() {
    super.initState();
    _getLectureFiles();
  }

  Future<void> _getLectureFiles() async {
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final List<String> fileList = Directory(appDocumentsDir.path)
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((filename) =>
            filename.startsWith('lecture_') && filename.endsWith('.mp4'))
        .toList();
    setState(() {
      lectureFiles = fileList;
    });
  }

  Future<void> _shareLecture(String lectureFile) async {
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    String lecturePath = '${appDocumentsDir.path}/$lectureFile';
    await ShareExtend.share(lecturePath, "video");
  }

  Future<void> _deleteLecture(String lectureFile) async {
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    String lecturePath = '${appDocumentsDir.path}/$lectureFile';
    File file = File(lecturePath);
    await file.delete();
    await _getLectureFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture History'),
      ),
      body: lectureFiles.isEmpty
          ? Center(
              child: Text(
                'No recordings available.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: lectureFiles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(lectureFiles[index]),
                  onTap: () => _shareLecture(lectureFiles[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteLecture(lectureFiles[index]),
                  ),
                );
              },
            ),
    );
  }
}
