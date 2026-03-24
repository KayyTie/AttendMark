import 'package:flutter/material.dart';
import '../screens/session_list_screen.dart';
import '../screens/settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import '../screens/export_data_screen.dart';
import '../screens/import_data_screen.dart';

class AppDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/app_icon.png',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AttendMark',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: currentIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Calendar'),
              selected: currentIndex == 1,
              onTap: () => onTabSelected(1),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Schedule'),
              selected: currentIndex == 2,
              onTap: () => onTabSelected(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_copy),
              title: const Text('Sessions'),
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SessionListScreen()),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DATA',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey))),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExportDataScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Import Data'),
              onTap: () async {
                final nav = Navigator.of(context);
                nav.pop();
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                );
                if (result != null && result.files.single.path != null) {
                  nav.push(
                    MaterialPageRoute(
                        builder: (_) => ImportDataScreen(
                            filePath: result.files.single.path!)),
                  );
                }
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
