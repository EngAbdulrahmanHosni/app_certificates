#!/usr/bin/env dart
// ignore_for_file: avoid_print

/*
  Android Keystore Generator (CI/CD safe)

  - Generates keystore under apps/<app_name>/
  - Supports CI mode
  - Auto fallback if KEY_PASSWORD is missing or empty
*/

import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _configFileName = '.keystore_config.json';
const _appsBaseDir = 'apps';

Future<void> main(List<String> args) async {
  final flags = _parseArgs(args);

  _banner();

  if (!await _isKeytoolAvailable()) {
    _err('keytool not found. Install JDK.');
    exit(1);
  }

  final ciMode = flags.boolFlag('ci') || Platform.environment['CI'] == 'true';
  final config = await _loadConfig();

  final appName = flags.value('app') ??
      (ciMode ? Platform.environment['APP_NAME'] ?? '' : _prompt('App name', required: true));

  if (appName.trim().isEmpty) {
    _err('App name is required');
    exit(2);
  }

  final safeApp = _sanitizeDirName(appName);
  if (!await Directory(_appsBaseDir).exists()) {
    await Directory(_appsBaseDir).create();
  }

  final appDir = '$_appsBaseDir/$safeApp';
  final certDir = Directory('$appDir/cert');
  final keystorePath = '${certDir.path}/key.jks';
  final propsFile = File('$appDir/key.properties');

  if (!flags.boolFlag('overwrite')) {
    if (await File(keystorePath).exists()) {
      _err('Keystore already exists. Use --overwrite');
      exit(3);
    }
  }

  await certDir.create(recursive: true);

  final keyAlias = flags.value('alias') ?? config['keyAlias'] ?? 'key';
  final validity = flags.value('validity') ?? config['validity'] ?? '10000';

  final storePassword =
      flags.value('storepass') ??
      Platform.environment['KEYSTORE_PASSWORD'] ??
      _generatePassword();

  String? envKeyPass = Platform.environment['KEY_PASSWORD'];
  if (envKeyPass != null && envKeyPass.trim().isEmpty) {
    envKeyPass = null;
  }

  final keyPassword =
      flags.value('keypass') ??
      envKeyPass ??
      storePassword;

  print('\n✅ Configuration:');
  print('   App path: $appDir');
  print('   Alias: $keyAlias');
  print('   Validity: $validity days');
  print('   Password: (hidden)');

  final dname = 'CN=Unknown, OU=Dev, O=Company, L=NA, ST=NA, C=US';

  final result = await _runKeytool([
    '-genkeypair',
    '-keystore', keystorePath,
    '-storetype', 'JKS',
    '-keyalg', 'RSA',
    '-keysize', '2048',
    '-validity', validity,
    '-alias', keyAlias,
    '-storepass', storePassword,
    '-keypass', keyPassword,
    '-dname', dname,
  ]);

  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exit(10);
  }

  await propsFile.writeAsString('''
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=cert/key.jks
''');

  print('\n════════════════════════════');
  print('✅ DONE');
  print('════════════════════════════');
  print('Keystore: $keystorePath');
  print('Properties: ${propsFile.path}');
}

void _banner() {
  print('════════════════════════════');
  print(' Android Keystore Generator ');
  print('════════════════════════════');
}

Future<bool> _isKeytoolAvailable() async {
  try {
    final r = await _runKeytool(['-help']);
    return r.exitCode == 0 || r.exitCode == 1;
  } catch (_) {
    return false;
  }
}

Future<ProcessResult> _runKeytool(List<String> args) =>
    Process.run('keytool', args, runInShell: Platform.isWindows);

String _sanitizeDirName(String s) =>
    s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

String _generatePassword({int length = 28}) {
  final r = Random.secure();
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#%_-';
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

String _prompt(String msg, {bool required = false}) {
  while (true) {
    stdout.write('$msg: ');
    final v = stdin.readLineSync()?.trim() ?? '';
    if (required && v.isEmpty) continue;
    return v;
  }
}

Future<Map<String, String>> _loadConfig() async {
  try {
    final f = File(_configFileName);
    if (!await f.exists()) return {};
    final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return j.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    return {};
  }
}

class _Flags {
  final Map<String, String?> v;
  final Set<String> b;
  _Flags(this.v, this.b);
  String? value(String k) => v[k];
  bool boolFlag(String k) => b.contains(k);
}

_Flags _parseArgs(List<String> a) {
  final v = <String, String?>{};
  final b = <String>{};
  String? p;
  for (final x in a) {
    if (x.startsWith('--')) {
      final s = x.substring(2);
      if (s.contains('=')) {
        final sp = s.split('=');
        v[sp[0]] = sp.sublist(1).join('=');
      } else {
        p = s;
        b.add(s);
      }
    } else if (p != null) {
      b.remove(p);
      v[p!] = x;
      p = null;
    }
  }
  return _Flags(v, b);
}
