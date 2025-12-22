import 'dart:convert';
import 'dart:io';

Future<String> _run(String cmd, {List<String> args = const []}) async {
  final result = await Process.run(cmd, args, runInShell: true);
  if (result.exitCode != 0) {
    // لا نفشل هنا دائمًا لأن git log ممكن يفشل لو مفيش history
    return '';
  }
  return (result.stdout ?? '').toString().trim();
}

String _escapeHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

Future<void> main(List<String> args) async {
  final readmeFile = File('README.md');
  final historyFile = File('Keystore_History.md');
  final htmlFile = File('Keystore_Dashboard.html');

  // Load history if exists
  final historyText = historyFile.existsSync()
      ? historyFile.readAsStringSync()
      : '# Keystore History\n\n_No history yet_\n';

  final now = DateTime.now().toUtc().toIso8601String().replaceAll('T', ' ').replaceAll('Z', ' UTC'); 

  // ===== README.md =====
  final readme = StringBuffer()
    ..writeln('# 🔐 Android Keystore Vault')
    ..writeln()
    ..writeln('This repository manages Android Keystores for all applications.')
    ..writeln()
    ..writeln('## 🚀 How to Generate a Keystore')
    ..writeln()
    ..writeln('You can generate a new keystore or update an existing one manually via GitHub Actions:')
    ..writeln()
    ..writeln('1. Go to the **Actions** tab.')
    ..writeln('2. Select **Generate Android Keystore** from the sidebar.')
    ..writeln('3. Click **Run workflow**.')
    ..writeln('4. Fill in the inputs:')
    ..writeln('   - **App name**: Folder name under `apps/` (e.g., `my_app`).')
    ..writeln('   - **Keystore password**: (Optional) Leave empty to checking auto-generate.')
    ..writeln('   - **Key password**: (Optional) Leave empty to use keystore password.')
    ..writeln('   - **Verify**: Check to verify the keystore after generation.')
    ..writeln('   - **Commit changes**: Uncheck if you only want to test without saving.')
    ..writeln()
    ..writeln('---')
    ..writeln('Last updated: $now');

  readmeFile.writeAsStringSync(readme.toString());

  // Delete HTML dashboard as it is no longer requested/maintained in this simplified view
  if (htmlFile.existsSync()) {
    htmlFile.deleteSync();
  }

  stdout.writeln('✅ Generated README.md (Documentation Mode)');
}
