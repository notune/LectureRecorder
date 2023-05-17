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
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  int _videoQuality = 720;
  bool _wakelockWhileRecording = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('videoQuality', _videoQuality);
    await prefs.setBool('wakelockWhileRecording', _wakelockWhileRecording);
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _videoQuality = prefs.getInt('videoQuality') ?? 720;
      _wakelockWhileRecording = prefs.getBool('wakelockWhileRecording') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Video Quality'),
            trailing: DropdownButton<int>(
              value: _videoQuality,
              items: [
                DropdownMenuItem<int>(
                    child: const Text('Low (480h)'), value: 480),
                DropdownMenuItem<int>(
                    child: const Text('Medium (720h)'), value: 720),
                DropdownMenuItem<int>(
                    child: const Text('High (1080h)'), value: 1080),
              ],
              onChanged: (int? newValue) {
                setState(() {
                  _videoQuality = newValue!;
                });
                _saveSettings();
              },
            ),
          ),
          ListTile(
            title: const Text('Wakelock while recording'),
            trailing: Switch(
              value: _wakelockWhileRecording,
              onChanged: (bool newValue) {
                setState(() {
                  _wakelockWhileRecording = newValue;
                });
                _saveSettings();
              },
            ),
          ),
        ],
      ),
    );
  }
}
