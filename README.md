# Keystore Vault — مخزن مفاتيح توقيع تطبيقات Android

هذا المشروع وظيفته **حفظ ملفات التوقيع (Keystore) وملفات `key.properties` لكل تطبيقاتك في مكان واحد** بعيد عن مشاريع التطبيقات، علشان تقلل جدًا خطر ضياع المفاتيح.

> ⚠️ مهم جدًا: ملفات التوقيع وملفات الخصائص **أسرار**. لا ترفعها لمستودع عام أبدًا.

---

## الفكرة في سطرين
- لكل تطبيق عندك فولدر مستقل داخل الـ Vault.
- كل فولدر يحتوي:
  - `cert/key.jks` (الـ Keystore)
  - `key.properties` (بيانات الربط في Gradle/Flutter)

هذا نفس الهيكل المذكور في النسخة السابقة من الـ README (وجود `[app_name]/cert/key.jks` و`key.properties`). fileciteturn0file0L21-L27

---

## المتطلبات
- Dart SDK
- Java JDK (عشان `keytool`)

تأكد إن الأمر ده شغال:
```bash
keytool -help
```

---

## توليد Keystore جديد (الطريقة المفضلة)

### تفاعليًا (Interactive)
```bash
dart generate_keystore.dart
```
سيطلب منك **اسم التطبيق فقط** (مثل: `my_app`) ويستخدم إعدادات افتراضية للباقي.

### وضع CI/CD (بدون تفاعل)
```bash
dart generate_keystore.dart --ci --app my_app --print-password
```

> في وضع CI يمكن أيضًا تمرير القيم عبر Environment Variables:
- `APP_NAME`
- `KEYSTORE_PASSWORD` (اختياري)
- `KEY_PASSWORD` (اختياري)

---

## أين تُحفظ الملفات؟
بعد التوليد ستجد:
```
my_app/
  cert/
    key.jks
  key.properties
```

---

## طريقة ربط الملفات داخل مشروع Flutter/Android

داخل مشروع Flutter:
1) انسخ الملفات:
```bash
cp -r <vault>/my_app/cert android/
cp <vault>/my_app/key.properties android/
```

2) عدّل `android/app/build.gradle` (مثال مختصر):
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
  signingConfigs {
    release {
      keyAlias keystoreProperties['keyAlias']
      keyPassword keystoreProperties['keyPassword']
      storeFile file(keystoreProperties['storeFile'])
      storePassword keystoreProperties['storePassword']
    }
  }
}
```

(الفكرة الأساسية موجودة أيضًا في README القديم). fileciteturn0file0L86-L115

---

## إعدادات السكربت وملف الكونفيج
السكربت يستخدم ملف:
- `.keystore_config.json`

✅ افتراضيًا: يحفظ **إعدادات غير سرّية فقط** (مثل alias وبيانات الشهادة).  
⚠️ لا يحفظ كلمة المرور إلا إذا استخدمت:
```bash
dart generate_keystore.dart --save-password
```

> لا نوصي بهذا إلا لو الريبو **خاص** وعندك Access Controls قوية، ومع ذلك تأكد إن الملف في `.gitignore`.

---

## مميزات النسخة المحسّنة من السكربت
- توليد كلمة مرور قوية بـ `Random.secure()`
- منع الكتابة فوق ملفات موجودة إلا مع `--overwrite`
- وضع CI عبر `--ci` و Env Vars
- خيار تحقق `--verify`
- خيار إظهار كلمة المرور فقط عند الحاجة `--print-password`

---

## GitHub Actions (Workflow جاهز)
ستجد Workflow جاهز في:
`.github/workflows/keystore_vault.yml`

- يعمل **Lint/Analyze/Format** للسكربت.
- ويحتوي تشغيل يدوي (workflow_dispatch) لتوليد Keystore في CI عند الحاجة.

> ⚠️ تذكير: رفع keystore كـ artifact في GitHub Actions قد يكون خطرًا إذا كانت إعدادات الخصوصية غير مضبوطة. استخدمه فقط داخل Repo خاص وبسياسة وصول صارمة.

---

## .gitignore المقترح
استخدم الملف المرفق `.gitignore` داخل هذا الـ Vault.

---

## Best Practices سريعة
- اعمل Backup مشفر (1Password / Bitwarden / Google Drive مشفر)
- نسختين على الأقل في أماكن مختلفة
- لا تشارك كلمات المرور على الشات أو التذاكر

راجع أيضًا: `SECURITY.md`
