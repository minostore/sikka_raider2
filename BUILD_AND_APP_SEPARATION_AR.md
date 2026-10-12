# تجهيز Sikka Driver

هذا مشروع Flutter مستقل. معرّف Android: `com.sikka.driver` واسم التطبيق: `Sikka Driver`.

من جهاز عليه Flutter وAndroid SDK شغّل من جذر المشروع:
```bash
bash tool/setup_platforms.sh
flutter build apk --release
```

المشروع الآخر يستخدم معرّفًا مختلفًا حتى يمكن تثبيت التطبيقين معًا. ملفات APK المرفوعة وحدها لا تحتوي على كود Flutter المصدر؛ لذلك التعديل يكون على هذا المشروع ثم إعادة البناء.
