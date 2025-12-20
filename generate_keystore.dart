#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  print('═══════════════════════════════════════════════════');
  print('   Android Keystore Generator');
  print('═══════════════════════════════════════════════════\n');

  // Check if keytool is available
  if (!await isKeytoolAvailable()) {
    print('❌ Error: keytool command not found!');
    print('Please install Java JDK:');
    print('  macOS:   brew install openjdk');
    print('  Linux:   sudo apt install openjdk-11-jdk');
    print('  Windows: Download from https://www.oracle.com/java/technologies/downloads/');
    exit(1);
  }

  // Load saved configuration if exists
  final config = await loadConfig();
  
  // Gather information
  print('Please provide the following information:\n');

  final appName = prompt('App name (e.g., my_app)', required: true);
  
  // Use saved config or defaults for everything else
  final keyAlias = config['keyAlias'] ?? 'key';
  final storePassword = config['storePassword'] ?? generatePassword();
  final keyPassword = storePassword;
  
  final commonName = config['commonName'] ?? 'Unknown';
  final organizationalUnit = config['organizationalUnit'] ?? 'Development';
  final organization = config['organization'] ?? 'My Company';
  final city = config['city'] ?? 'Unknown';
  final state = config['state'] ?? 'Unknown';
  final countryCode = config['countryCode'] ?? 'US';
  final validity = config['validity'] ?? '10000';
  
  print('\n✅ Using configuration:');
  print('   Key alias: $keyAlias');
  print('   Organization: $organization');
  print('   Validity: $validity days\n');

  // Create directory structure
  final certDir = Directory('$appName/cert');
  
  print('\n📁 Creating directory structure...');
  await certDir.create(recursive: true);

  // Generate keystore
  print('🔐 Generating keystore...\n');

  final keystorePath = '${certDir.path}/key.jks';
  final dname = 'CN=$commonName, OU=$organizationalUnit, O=$organization, L=$city, ST=$state, C=$countryCode';

  final result = await Process.run('keytool', [
    '-genkey',
    '-v',
    '-keystore', keystorePath,
    '-keyalg', 'RSA',
    '-keysize', '2048',
    '-validity', validity,
    '-alias', keyAlias,
    '-storepass', storePassword,
    '-keypass', keyPassword,
    '-dname', dname,
  ]);

  if (result.exitCode != 0) {
    print('❌ Error generating keystore:');
    print(result.stderr);
    exit(1);
  }

  print(result.stdout);

  // Create key.properties file
  print('\n📝 Creating key.properties file...');
  
  final propertiesContent = '''storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=cert/key.jks
''';

  final propertiesFile = File('$appName/key.properties');
  await propertiesFile.writeAsString(propertiesContent);

  // Save configuration for future use
  await saveConfig({
    'keyAlias': keyAlias,
    'storePassword': storePassword,
    'commonName': commonName,
    'organizationalUnit': organizationalUnit,
    'organization': organization,
    'city': city,
    'state': state,
    'countryCode': countryCode,
    'validity': validity,
  });

  // Success message
  print('\n✅ Keystore generated successfully!\n');
  print('═══════════════════════════════════════════════════');
  print('   Summary');
  print('═══════════════════════════════════════════════════');
  print('📦 App name:      $appName');
  print('🔑 Key alias:     $keyAlias');
  print('🔐 Password:      $storePassword');
  print('📂 Keystore:      $keystorePath');
  print('📄 Properties:    ${propertiesFile.path}');
  print('⏰ Valid for:     $validity days (~${(int.parse(validity) / 365).toStringAsFixed(1)} years)');
  print('═══════════════════════════════════════════════════\n');

  print('Next steps:');
  print('1. Copy files to your Flutter project:');
  print('   cp $appName/key.properties android/');
  print('   cp -r $appName/cert android/\n');
  print('2. Update android/app/build.gradle (see README.md)');
  print('3. Build your release APK/AAB:');
  print('   flutter build apk --release\n');
  
  print('⚠️  IMPORTANT: Backup these files securely!');
  print('   Losing the keystore means you cannot update your app.\n');

  // Verify keystore
  print('Would you like to verify the keystore now? (y/n): ');
  final verify = stdin.readLineSync()?.toLowerCase();
  
  if (verify == 'y' || verify == 'yes') {
    print('\n🔍 Verifying keystore...\n');
    final verifyResult = await Process.run('keytool', [
      '-list',
      '-v',
      '-keystore', keystorePath,
      '-alias', keyAlias,
      '-storepass', storePassword,
    ]);
    print(verifyResult.stdout);
  }

  print('\n✨ Done!');
}

Future<bool> isKeytoolAvailable() async {
  try {
    final result = await Process.run('keytool', ['-help']);
    return result.exitCode == 0 || result.exitCode == 1; // keytool returns 1 for help
  } catch (e) {
    return false;
  }
}

Future<Map<String, String>> loadConfig() async {
  try {
    final configFile = File('.keystore_config.json');
    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      return json.map((key, value) => MapEntry(key, value.toString()));
    }
  } catch (e) {
    // If config doesn't exist or is invalid, return empty map
  }
  return {};
}

Future<void> saveConfig(Map<String, String> config) async {
  try {
    final configFile = File('.keystore_config.json');
    await configFile.writeAsString(jsonEncode(config));
    print('✅ Configuration saved for future use');
  } catch (e) {
    print('⚠️  Warning: Could not save configuration: $e');
  }
}

String generatePassword() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = timestamp.hashCode.abs();
  return 'Key${random}Secure';
}

String prompt(String message, {String? defaultValue, bool required = false, bool isPassword = false}) {
  while (true) {
    if (defaultValue != null) {
      stdout.write('$message [$defaultValue]: ');
    } else {
      stdout.write('$message: ');
    }

    final input = stdin.readLineSync()?.trim() ?? '';

    if (input.isEmpty && defaultValue != null) {
      return defaultValue;
    }

    if (input.isEmpty && required) {
      print('❌ This field is required. Please try again.');
      continue;
    }

    if (input.isEmpty && !required) {
      return '';
    }

    return input;
  }
}
