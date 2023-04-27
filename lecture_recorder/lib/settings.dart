import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _videoQuality = 'medium';
  bool _wakelockWhileRecording = true;

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
              },
            ),
          ),
        ],
      ),
    );
  }
}
