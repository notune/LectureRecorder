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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    await Share.shareFiles([lecturePath]);
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
