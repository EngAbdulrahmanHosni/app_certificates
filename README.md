# App Certifications Manager

A repository for managing Android app signing keys and certificates with automated generation tools.

## Quick Start

### Generate a New Keystore (Automated)

Use the Dart script to generate a new keystore with one command:

```bash
dart generate_keystore.dart
```

The script will only ask for the **app name**. Everything else is automatically configured:
- Password: Auto-generated secure password
- Key alias: `key` (default)
- Certificate details: Default values from saved configuration

**Note:** The script saves all configuration (including the password) to `.keystore_config.json` and reuses it for future keystores. This means you only need to enter the app name for subsequent keystore generations!

### Manual Keystore Generation

If you prefer to create a keystore manually:

```bash
keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your-key-alias
```

## Repository Structure

```
app_certifications/
├── README.md
├── generate_keystore.dart       # Automated keystore generator
└── [app_name]/
    ├── cert/
    │   └── key.jks              # Java KeyStore file
    └── key.properties           # Keystore configuration
```

## How to Create a Keystore

### Prerequisites

- Java Development Kit (JDK) installed
- `keytool` command available (comes with JDK)

### Method 1: Using the Dart Script (Recommended)

1. Run the generator:
   ```bash
   dart generate_keystore.dart
   ```

2. Follow the interactive prompts

3. Your keystore will be created in `[app_name]/cert/key.jks`

### Method 2: Manual Creation

1. **Generate the keystore:**
   ```bash
   keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
   ```

2. **Create directory structure:**
   ```bash
   mkdir -p my_app/cert
   mv key.jks my_app/cert/
   ```

3. **Create key.properties file:**
   ```properties
   storePassword=your-store-password
   keyPassword=your-key-password
   keyAlias=my-key-alias
   storeFile=cert/key.jks
   ```

### Keystore Parameters Explained

- **keystore**: Output filename for your keystore
- **keyalg**: Algorithm (RSA recommended)
- **keysize**: Key size in bits (2048 or higher)
- **validity**: Validity period in days (10000 = ~27 years)
- **alias**: Unique identifier for this key

## Using the Keystore in Your Flutter/Android Project

### Step 1: Copy Files

Copy the app directory to your Flutter project:

```bash
cp -r my_app/key.properties android/
cp -r my_app/cert android/
```

### Step 2: Update build.gradle

Edit `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

### Step 3: Build Signed APK/AAB

```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

## Verifying Your Keystore

Check keystore information:

```bash
keytool -list -v -keystore cert/key.jks -alias your-alias
```

Check APK signature:

```bash
keytool -printcert -jarfile app-release.apk
```

## Security Best Practices

⚠️ **CRITICAL SECURITY NOTES**

1. **Never commit to public repositories**
   - Add to `.gitignore` in your app projects
   - Keep this repo private

2. **Backup Strategy**
   - Store encrypted backups in multiple secure locations
   - Use cloud storage with encryption (Google Drive, Dropbox, 1Password)
   - Keep offline copies in secure physical locations

3. **Access Control**
   - Limit access to authorized team members only
   - Use strong, unique passwords
   - Consider using a password manager

4. **Password Management**
   - Use strong passwords (16+ characters)
   - Don't reuse passwords across apps
   - Store passwords separately from keystores

5. **If Keys Are Lost**
   - You **cannot** update your published app
   - You must publish as a new app with a new package name
   - All existing users must reinstall

## Troubleshooting

### Command Not Found: keytool

Install JDK:
```bash
# macOS
brew install openjdk

# Linux (Ubuntu/Debian)
sudo apt install openjdk-11-jdk

# Check installation
keytool -version
```

### Permission Denied

Make script executable:
```bash
chmod +x generate_keystore.dart
```

### Keystore Password Forgotten

Unfortunately, there's no way to recover a forgotten keystore password. You must:
1. Generate a new keystore
2. Publish as a new app (if already published)

## Adding to .gitignore

Add these lines to your Flutter project's `.gitignore`:

```gitignore
# Keystore files
*.jks
*.keystore
key.properties
android/key.properties
android/cert/
.keystore_config.json
```

## Environment Variables (Alternative)

For CI/CD pipelines, use environment variables instead of committed files:

```gradle
signingConfigs {
    release {
        keyAlias System.getenv("KEY_ALIAS")
        keyPassword System.getenv("KEY_PASSWORD")
        storeFile file(System.getenv("KEYSTORE_FILE"))
        storePassword System.getenv("KEYSTORE_PASSWORD")
    }
}
```

## Support

For issues or questions about keystore generation, refer to:
- [Android Developer Documentation](https://developer.android.com/studio/publish/app-signing)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
