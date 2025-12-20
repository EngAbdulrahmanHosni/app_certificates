#!/usr/bin/env dart
// ignore_for_file: avoid_print
/*
  Android Keystore Generator (secure-ish, CI/CD friendly)

  Features:
  - Interactive by default
  - Strong password generation (Random.secure)
  - Prevents accidental overwrite unless --overwrite
  - Optional verification step (--verify)
  - CI/CD mode: non-interactive via flags/env (--ci)
  - Config file stores NON-secret defaults by default
  - ALL apps are generated under ./apps/<app_name>/
*/

import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _configFileName = '.keystore_config.json';
const _appsBaseDir = 'apps';

Future<void> main(List<String> args) async {
  final flags = _parseArgs(args);

  _banner();

  // Check keytool
  if (!await _isKeytoolAvailable()) {
    _err('keytool command not found.');
    print('Install Java JDK then ensure "keytool" is in PATH.');
    exit(1);
  }

  final config = await _loadConfig();
  final ciMode = flags.boolFlag('ci') || (Platform.environment['CI'] == 'true');

  // App name
  final appName = flags.value('app') ??
      (ciMode
          ? (Platform.environment['APP_NAME'] ?? '')
          : _prompt('App name (e.g., my_app)', required: true));

  if (appName.trim().isEmpty) {
    _err('App name is required.');
    exit(2);
  }

  final safeAppDir = _sanitizeDirName(appName.trim());
  if (safeAppDir != appName.trim()) {
    print('ℹ️  Using safe directory name: "$safeAppDir"');
  }

  // Ensure apps/ exists
  final appsDir = Directory(_appsBaseDir);
  if (!await appsDir.exists()) {
    await appsDir.create(recursive: true);
  }

  // Defaults (non-secret)
  final keyAlias = flags.value('alias') ?? config['keyAlias'] ?? 'key';
  final validity = flags.value('validity') ?? config['validity'] ?? '10000';

  final commonName = flags.value('cn') ?? config['commonName'] ?? 'Unknown';
  final organizationalUnit =
      flags.value('ou') ?? config['organizationalUnit'] ?? 'Development';
  final organization =
      flags.value('o') ?? config['organization'] ?? 'My Company';
  final city = flags.value('l') ?? config['city'] ?? 'Unknown';
  final state = flags.value('st') ?? config['state'] ?? 'Unknown';
  final countryCode = flags.value('c') ?? config['countryCode'] ?? 'US';

  // Passwords
  final savePassword = flags.boolFlag('save-password');
  final storePassword =
      flags.value('storepass') ??
          Platform.environment['KEYSTORE_PASSWORD'] ??
          (config.containsKey('storePassword')
              ? config['storePassword']!
              : _generatePassword());

  final keyPassword =
      flags.value('keypass') ??
          Platform.environment['KEY_PASSWORD'] ??
          storePassword;

  // Paths
  final appBasePath = '$_appsBaseDir/$safeAppDir';
  final certDir = Directory('$appBasePath/cert');
  final keystorePath = '${certDir.path}/key.jks';
  final propertiesFile = File('$appBasePath/key.properties');

  // Overwrite protection
  final overwrite = flags.boolFlag('overwrite');
  if (!overwrite) {
    if (await File(keystorePath).exists() ||
        await propertiesFile.exists()) {
      _err('App "$safeAppDir" already exists inside "$_appsBaseDir/".');
      print('Use --overwrite to replace existing files.');
      exit(3);
    }
  }

  // Create directories
  await certDir.create(recursive: true);

  final dname =
      'CN=$commonName, OU=$organizationalUnit, O=$organization, L=$city, ST=$state, C=$countryCode';

  print('\n✅ Configuration:');
  print('   App path:      $appBasePath');
  print('   Alias:         $keyAlias');
  print('   Validity:      $validity days');
  print(flags.boolFlag('print-password')
      ? '   Password:      $storePassword'
      : '   Password:      (hidden)');

  // Generate keystore
  print('\n🔐 Generating keystore...');
  final genResult = await _runKeytool([
    '-genkeypair',
    '-v',
    '-keystore',
    keystorePath,
    '-storetype',
    'JKS',
    '-keyalg',
    'RSA',
    '-keysize',
    '2048',
    '-validity',
    validity,
    '-alias',
    keyAlias,
    '-storepass',
    storePassword,
    '-keypass',
    keyPassword,
    '-dname',
    dname,
  ]);

  if (genResult.exitCode != 0) {
    stderr.write(genResult.stderr);
    exit(10);
  }
  stdout.write(genResult.stdout);

  // key.properties
  await propertiesFile.writeAsString('''
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=cert/key.jks
''', flush: true);

  // Save config (non-secret)
  final nextConfig = <String, String>{
    'keyAlias': keyAlias,
    'commonName': commonName,
    'organizationalUnit': organizationalUnit,
    'organization': organization,
    'city': city,
    'state': state,
    'countryCode': countryCode,
    'validity': validity,
  };

  if (savePassword) {
    nextConfig['storePassword'] = storePassword;
    print('⚠️  --save-password enabled. NEVER commit $_configFileName');
  }

  if (!flags.boolFlag('no-save-config')) {
    await _saveConfig(nextConfig);
  }

  // Summary
  print('\n══════════════════════════════════════');
  print('✅ DONE');
  print('══════════════════════════════════════');
  print('📦 App:        $appBasePath');
  print('📂 Keystore:   $keystorePath');
  print('📄 Properties: ${propertiesFile.path}');
  print('🔑 Alias:      $keyAlias');
  print('══════════════════════════════════════\n');

  // Verify
  final verify = flags.boolFlag('verify') ||
      (!ciMode && _yesNo('Verify keystore now?', defaultYes: false));

  if (verify) {
    print('\n🔍 Verifying keystore...\n');
    final verifyResult = await _runKeytool([
      '-list',
      '-v',
      '-keystore',
      keystorePath,
      '-alias',
      keyAlias,
      '-storepass',
      storePassword,
    ]);
    stdout.write(verifyResult.stdout);
    if (verifyResult.exitCode != 0) {
      stderr.write(verifyResult.stderr);
      exit(11);
    }
  }

  print('\nNext steps:');
  print('cp $appBasePath/key.properties android/');
  print('cp -r $appBasePath/cert android/');
  print('\n⚠️ Backup keystore & passwords securely.');
}

void _banner() {
  print('══════════════════════════════════════');
  print('   Android Keystore Generator');
  print('══════════════════════════════════════\n');
}

void _err(String msg) => print('❌ $msg');

Future<bool> _isKeytoolAvailable() async {
  try {
    final r = await _runKeytool(['-help']);
    return r.exitCode == 0 || r.exitCode == 1;
  } catch (_) {
    return false;
  }
}

Future<ProcessResult> _runKeytool(List<String> args) {
  return Process.run('keytool', args, runInShell: Platform.isWindows);
}

String _sanitizeDirName(String input) =>
    input.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

String _generatePassword({int length = 28}) {
  final rand = Random.secure();
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#%_-';
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

String _prompt(String message, {bool required = false}) {
  while (true) {
    stdout.write('$message: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    if (required && input.isEmpty) {
      _err('Required.');
      continue;
    }
    return input;
  }
}

bool _yesNo(String message, {bool defaultYes = true}) {
  stdout.write('$message ${defaultYes ? "[Y/n]" : "[y/N]"}: ');
  final input = (stdin.readLineSync() ?? '').toLowerCase();
  if (input.isEmpty) return defaultYes;
  return input == 'y' || input == 'yes';
}

Future<Map<String, String>> _loadConfig() async {
  try {
    final f = File(_configFileName);
    if (!await f.exists()) return {};
    final Map<String, dynamic> j =
    jsonDecode(await f.readAsString());
    return j.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    return {};
  }
}

Future<void> _saveConfig(Map<String, String> config) async {
  try {
    await File(_configFileName).writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
      flush: true,
    );
    print('✅ Saved defaults to $_configFileName');
  } catch (e) {
    print('⚠️  Could not save config: $e');
  }
}

class _Flags {
  final Map<String, String?> _vals;
  final Set<String> _bools;
  _Flags(this._vals, this._bools);
  String? value(String key) => _vals[key];
  bool boolFlag(String key) => _bools.contains(key);
}

_Flags _parseArgs(List<String> args) {
  final vals = <String, String?>{};
  final bools = <String>{};
  String? pending;

  for (final a in args) {
    if (a.startsWith('--')) {
      pending = null;
      final p = a.substring(2);
      if (p.contains('=')) {
        final s = p.split('=');
        vals[s.first] = s.sublist(1).join('=');
      } else {
        pending = p;
        bools.add(p);
      }
    } else if (pending != null) {
      bools.remove(pending);
      vals[pending] = a;
      pending = null;
    }
  }
  return _Flags(vals, bools);
}
