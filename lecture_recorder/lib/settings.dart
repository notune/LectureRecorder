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
