import 'dart:io';

void main() {
  final appsDir = Directory('apps');
  if (!appsDir.existsSync()) {
    print('Error: apps/ directory not found.');
    exit(1);
  }

  // Get list of app directories, sorted alphabetically
  final apps =
      appsDir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(Platform.pathSeparator).last)
          .where((name) => !name.startsWith('.')) // Ignore hidden folders
          .toList()
        ..sort();

  if (apps.isEmpty) {
    print('Warning: No apps found in apps/ directory.');
  }

  final workflowFile = File('.github/workflows/download_app.yml');
  if (!workflowFile.existsSync()) {
    print('Error: .github/workflows/download_app.yml not found.');
    exit(1);
  }

  final content = workflowFile.readAsStringSync();

  // Regex to find the options list under app_name input
  // It looks for:
  //       app_name:
  //         ...
  //         options:
  //           - app1
  //           - app2
  final regex = RegExp(
    r'(app_name:[\s\S]*?options:)(\s*\n\s*-\s*[a-zA-Z0-9_]+)+',
    multiLine: true,
  );

  if (!regex.hasMatch(content)) {
    print(
      'Error: Could not find "options" list under "app_name" in workflow file.',
    );
    // Check if we can find just the options key to append to if it's empty or different format?
    // For now, let's assume the strict format we will generate.
    exit(1);
  }

  final newOptions = apps.map((app) => '          - $app').join('\n');

  final newContent = content.replaceAllMapped(regex, (match) {
    return '${match.group(1)}\n$newOptions';
  });

  if (content != newContent) {
    workflowFile.writeAsStringSync(newContent);
    print('Updated download_app.yml with ${apps.length} apps.');
  } else {
    print('No changes needed for download_app.yml.');
  }
}
