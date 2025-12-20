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
  final appsDir = Directory('apps');
  final readmeFile = File('README.md');
  final historyFile = File('Keystore_History.md');
  final htmlFile = File('Keystore_Dashboard.html');

  if (!appsDir.existsSync()) {
    stderr.writeln('apps/ directory not found.');
    exit(1);
  }

  final appFolders = appsDir
      .listSync(followLinks: false)
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final rows = <Map<String, String>>[];

  for (final dir in appFolders) {
    final name = dir.uri.pathSegments.isNotEmpty
        ? dir.uri.pathSegments[dir.uri.pathSegments.length - 2]
        : dir.path.split(Platform.pathSeparator).last;

    final keystorePath = '${dir.path}/cert/key.jks';
    final keystoreExists = File(keystorePath).existsSync();

    // last update from git (best effort)
    final lastUpdate = await _run(
      'git',
      args: ['log', '-1', '--format=%Y-%m-%d', '--', dir.path],
    );
    final lastUpdateFinal = lastUpdate.isEmpty ? '-' : lastUpdate;

    rows.add({
      'name': name,
      'folder': dir.path,
      'keystore': keystoreExists ? '✅ Exists' : '❌ Missing',
      'status': keystoreExists ? '🟢 Active' : '🔴 Broken',
      'lastUpdate': lastUpdateFinal,
    });
  }

  final historyText = historyFile.existsSync()
      ? historyFile.readAsStringSync()
      : '# Keystore History\n\n_No history yet_\n';

  // ===== README.md =====
  final readme = StringBuffer()
    ..writeln('# 🔐 Android Keystore Vault Dashboard')
    ..writeln()
    ..writeln('هذا المستودع مسؤول عن إدارة وتخزين keystores لجميع التطبيقات.')
    ..writeln()
    ..writeln('## 📊 Applications Overview')
    ..writeln()
    ..writeln('| App Name | Folder | Keystore | Last Update | Status |')
    ..writeln('|--------|--------|---------|------------|--------|');

  for (final r in rows) {
    readme.writeln(
      '| ${r['name']} | `${r['folder']}` | ${r['keystore']} | ${r['lastUpdate']} | ${r['status']} |',
    );
  }

  readme
    ..writeln()
    ..writeln('## 🕒 Recent Activity')
    ..writeln('> يتم توليد هذا القسم تلقائيًا من `Keystore_History.md`')
    ..writeln()
    ..writeln(historyText.trim())
    ..writeln()
    ..writeln('---')
    ..writeln('_Last updated automatically by CI_');

  readmeFile.writeAsStringSync(readme.toString());

  // ===== HTML Dashboard =====
  final now = DateTime.now().toUtc().toIso8601String().replaceAll('T', ' ').replaceAll('Z', ' UTC');

  final htmlRows = rows.map((r) {
    final statusClass = (r['status']!.contains('🟢')) ? 'ok' : 'bad';
    final ksClass = (r['keystore']!.contains('✅')) ? 'ok' : 'bad';
    return '''
      <tr>
        <td class="mono">${_escapeHtml(r['name']!)}</td>
        <td class="mono">${_escapeHtml(r['folder']!)}</td>
        <td><span class="pill $ksClass">${_escapeHtml(r['keystore']!)}</span></td>
        <td class="mono">${_escapeHtml(r['lastUpdate']!)}</td>
        <td><span class="pill $statusClass">${_escapeHtml(r['status']!)}</span></td>
      </tr>
    ''';
  }).join('\n');

  final html = '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Android Keystore Vault Dashboard</title>
  <style>
    :root { color-scheme: dark; }
    body { margin:0; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial; background:#0b0f17; color:#e8eefc; }
    .wrap { max-width: 1100px; margin: 0 auto; padding: 28px 18px; }
    h1 { margin: 0 0 8px; font-size: 24px; }
    .sub { color:#b7c2dd; margin: 0 0 18px; }
    .card { background:#111827; border:1px solid #1f2a44; border-radius:16px; padding:16px; box-shadow: 0 10px 30px rgba(0,0,0,.25); }
    table { width:100%; border-collapse: collapse; overflow:hidden; border-radius: 12px; }
    th, td { padding: 12px 10px; border-bottom:1px solid #1f2a44; vertical-align: top; }
    th { text-align:left; font-size: 13px; color:#b7c2dd; background:#0f1626; }
    tr:hover td { background: rgba(255,255,255,.03); }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono"; font-size: 13px; }
    .pill { display:inline-block; padding: 4px 10px; border-radius: 999px; font-size: 12px; border:1px solid #263556; }
    .ok { background: rgba(34,197,94,.12); border-color: rgba(34,197,94,.35); }
    .bad { background: rgba(239,68,68,.12); border-color: rgba(239,68,68,.35); }
    .section { margin-top: 18px; }
    pre { white-space: pre-wrap; word-wrap: break-word; background:#0f1626; border:1px solid #1f2a44; padding: 14px; border-radius: 12px; color:#dbe7ff; }
    .footer { margin-top: 16px; color:#93a4c7; font-size: 12px; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>🔐 Android Keystore Vault Dashboard</h1>
    <p class="sub">Auto-generated dashboard — Last update: ${_escapeHtml(now)}</p>

    <div class="card">
      <h2 style="margin:0 0 10px; font-size:16px;">📊 Applications Overview</h2>
      <table>
        <thead>
          <tr>
            <th>App Name</th>
            <th>Folder</th>
            <th>Keystore</th>
            <th>Last Update</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          $htmlRows
        </tbody>
      </table>

      <div class="section">
        <h2 style="margin:14px 0 10px; font-size:16px;">🕒 Recent Activity</h2>
        <pre>${_escapeHtml(historyText.trim())}</pre>
      </div>

      <div class="footer">Generated by CI — do not edit manually.</div>
    </div>
  </div>
</body>
</html>
''';

  htmlFile.writeAsStringSync(html);

  stdout.writeln('✅ Generated README.md and Keystore_Dashboard.html');
}
