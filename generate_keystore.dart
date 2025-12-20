#!/usr/bin/env dart

import 'dart:io';

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

  // Gather information
  print('Please provide the following information:\n');

  final appName = prompt('App name (e.g., my_app)', required: true);
  final keyAlias = prompt('Key alias', defaultValue: 'key');
  final storePassword = prompt('Store password', required: true, isPassword: true);
  final keyPassword = prompt('Key password (press Enter to use same as store password)', 
                              defaultValue: storePassword, isPassword: true);
  
  print('\n--- Certificate Information ---\n');
  
  final commonName = prompt('Your name or organization', defaultValue: 'Unknown');
  final organizationalUnit = prompt('Organizational unit', defaultValue: 'Development');
  final organization = prompt('Organization', defaultValue: 'My Company');
  final city = prompt('City', defaultValue: 'Unknown');
  final state = prompt('State/Province', defaultValue: 'Unknown');
  final countryCode = prompt('Country code (2 letters)', defaultValue: 'US');
  
  final validity = prompt('Validity in days', defaultValue: '10000');

  // Create directory structure
  final appDir = Directory(appName);
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

  // Success message
  print('\n✅ Keystore generated successfully!\n');
  print('═══════════════════════════════════════════════════');
  print('   Summary');
  print('═══════════════════════════════════════════════════');
  print('📦 App name:      $appName');
  print('🔑 Key alias:     $keyAlias');
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
