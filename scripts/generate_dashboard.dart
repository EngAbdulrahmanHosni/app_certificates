#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

Future<void> main() async {
  final readme = File('README.md');
  final history = File('Keystore_History.md');
  final appsDir = Directory('apps');

  final buffer = StringBuffer();

  // Header
  buffer.writeln('# 🔐 Android Keystore Vault Dashboard');
  buffer.writeln();
  buffer.writeln('هذا المستودع مسؤول عن إدارة وتخزين keystores لجميع التطبيقات.');
  buffer.writeln();

  // Applications Overview
  buffer.writeln('## 📊 Applications Overview');
  buffer.writeln();
  buffer.writeln('| App Name | Folder | Keystore | Last Update | Status |');
  buffer.writeln('|--------|--------|---------|------------|--------|');

  if (await appsDir.exists()) {
    final apps = appsDir
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final app in apps) {
      final name = app.uri.pathSegments.last;
      final keystore = File('${app.path}/cert/key.jks');

      final hasKeystore = await keystore.exists();
      final ksStatus = hasKeystore ? '✅ Exists' : '❌ Missing';
      final status = hasKeystore ? '🟢 Active' : '🔴 Broken';

      final lastUpdate = await _lastGitUpdate(app.path);

      buffer.writeln(
        '| $name | `${app.path}` | $ksStatus | $lastUpdate | $status |',
      );
    }
  }

  buffer.writeln();
  buffer.writeln('## 🕒 Recent Activity');
  buffer.writeln('> يتم توليد هذا القسم تلقائيًا من `Keystore_History.md`');
  buffer.writeln();

  if (await history.exists()) {
    final lines = await history.readAsLines();
    if (lines.length > 1) {
      // Skip header line
      for (var i = 1; i < lines.length; i++) {
        buffer.writeln(lines[i]);
      }
    } else {
      buffer.writeln('_No history yet_');
    }
  } else {
    buffer.writeln('_No history yet_');
  }

  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln('_Last updated automatically by CI_');

  await readme.writeAsString(buffer.toString(), flush: true);

  print('✅ README dashboard generated successfully');
}

Future<String> _lastGitUpdate(String path) async {
  try {
    final result = await Process.run(
      'git',
      ['log', '-1', '--format=%Y-%m-%d', '--', path],
      runInShell: true,
    );

    if (result.exitCode == 0) {
      final out = result.stdout.toString().trim();
      return out.isEmpty ? '-' : out;
    }
  } catch (_) {}

  return '-';
}
