import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _videoQuality = 'medium';
  bool _wakelockWhileRecording = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('videoQuality', _videoQuality);
    await prefs.setBool('wakelockWhileRecording', _wakelockWhileRecording);
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _videoQuality = prefs.getString('videoQuality') ?? 'medium';
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
            trailing: DropdownButton<String>(
              value: _videoQuality,
              items: [
                DropdownMenuItem(child: Text('Low (480h)'), value: 'low'),
                DropdownMenuItem(child: Text('Medium (720h)'), value: 'medium'),
                DropdownMenuItem(child: Text('High (1080h)'), value: 'high'),
              ],
              onChanged: (String? newValue) {
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
