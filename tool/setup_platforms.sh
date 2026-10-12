#!/usr/bin/env bash
# يولّد مجلدي android/ و ios/ ويطبّق الصلاحيات والإعدادات المطلوبة (يُشغَّل مرة واحدة بعد استنساخ المشروع)
set -euo pipefail
APP_NAME="sikka_driver"
PKG="com.sikka.driver"

flutter create --platforms=android,ios --org com.sikka --project-name "$APP_NAME" --no-overwrite .
flutter pub get
python3 tool/patch_platforms.py "$PKG"
dart run flutter_launcher_icons
echo "تم التجهيز. شغّل: flutter run"
