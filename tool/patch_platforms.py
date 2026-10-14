#!/usr/bin/env python3
"""يعدّل ملفات Android/iOS المولَّدة: الصلاحيات، اسم التطبيق، minSdk، منصة iOS، معرّف الحزمة."""
import re, sys, glob, pathlib

PKG = sys.argv[1]
ROLE = "driver"
APP_LABEL = "Sikka Driver"

# ---------- Android ----------
mf = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = mf.read_text(encoding="utf-8")
perms = """    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
"""
if "ACCESS_FINE_LOCATION" not in s:
    s = s.replace("<application", perms + "    <application", 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="%s"' % APP_LABEL, s, count=1)
# استعلامات الحزم لفتح الاتصال/الرسائل (Android 11+)
if "<queries>" not in s:
    s = s.replace("</manifest>", """    <queries>
        <intent><action android:name="android.intent.action.DIAL" /></intent>
        <intent><action android:name="android.intent.action.SENDTO" /><data android:scheme="sms" /></intent>
        <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent>
    </queries>
</manifest>""")
mf.write_text(s, encoding="utf-8")

# صلاحيات الإشعارات والخدمة الأمامية
_extra = ["android.permission.POST_NOTIFICATIONS", "android.permission.VIBRATE", "android.permission.WAKE_LOCK"]
if ROLE == "driver":
    _extra += ["android.permission.FOREGROUND_SERVICE", "android.permission.FOREGROUND_SERVICE_LOCATION"]
s = mf.read_text(encoding="utf-8")
for _p in _extra:
    if _p not in s:
        s = s.replace("<application", '    <uses-permission android:name="%s" />\n    <application' % _p, 1)
mf.write_text(s, encoding="utf-8")

# ---------- التطبيق المصغّر (flutter_overlay_window) للسائق ----------
if ROLE == "driver":
    s = mf.read_text(encoding="utf-8")
    for _p in ["android.permission.SYSTEM_ALERT_WINDOW", "android.permission.FOREGROUND_SERVICE_SPECIAL_USE"]:
        if _p not in s:
            s = s.replace("<application", '    <uses-permission android:name="%s" />\n    <application' % _p, 1)
    if "OverlayService" not in s:
        s = s.replace("</application>", """        <service android:name="flutter.overlay.window.flutter_overlay_window.OverlayService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="driver_online_bubble" />
        </service>
    </application>""", 1)
    mf.write_text(s, encoding="utf-8")

for g in glob.glob("android/app/build.gradle*"):
    p = pathlib.Path(g); t = p.read_text(encoding="utf-8")
    # Android API 36 is required by flutter_plugin_android_lifecycle / file_picker.
    patterns = [
        (r'(?m)^(\s*)compileSdk\s*=.*$', r'\g<1>compileSdk = 36'),
        (r'(?m)^(\s*)compileSdkVersion\s+.*$', r'\g<1>compileSdkVersion 36'),
    ]
    changed = False
    for pattern, replacement in patterns:
        if re.search(pattern, t):
            t = re.sub(pattern, replacement, t, count=1)
            changed = True
            break
    if not changed:
        raise SystemExit('ERROR: compileSdk declaration not found in ' + str(p))
    if not re.search(r'(?m)^\s*compileSdk(?:Version)?\s*(?:=\s*)?36\s*$', t):
        raise SystemExit('ERROR: failed to force compileSdk 36 in ' + str(p))
    t = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', t)
    t = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', t)
    t = re.sub(r'applicationId\s*=\s*"[^"]*"', 'applicationId = "%s"' % PKG, t)
    t = re.sub(r'applicationId\s+"[^"]*"', 'applicationId "%s"' % PKG, t)
    # flutter_local_notifications يتطلب core library desugaring
    if g.endswith(".kts"):
        if "isCoreLibraryDesugaringEnabled" not in t:
            t, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", t, count=1)
            if n == 0:
                raise SystemExit("ERROR: compileOptions block not found in " + str(p))
        if "coreLibraryDesugaring(" not in t:
            t += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    else:
        if "coreLibraryDesugaringEnabled" not in t:
            t, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", t, count=1)
            if n == 0:
                raise SystemExit("ERROR: compileOptions block not found in " + str(p))
        if "coreLibraryDesugaring " not in t:
            t += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    p.write_text(t, encoding="utf-8")

# ---------- فرض compileSdk 36 على كل مكتبات الـ plugins (مثل file_picker) ----------
# السبب: التعديل أعلاه يغيّر compileSdk للتطبيق (app) فقط، بينما file_picker
# وبقية الـ plugins لها ملفات build.gradle خاصة (compileSdk = 34) فيفشل
# :file_picker:checkReleaseAarMetadata. لذلك نفرض القيمة على كل المشاريع الفرعية.
KTS_BLOCK = """// SIKKA_FORCE_COMPILE_SDK
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.javaClass.methods
                    .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                    ?.invoke(androidExt, 36)
            } catch (e: Exception) {
                println("compileSdk override skipped for ${project.name}: $e")
            }
        }
    }
}

"""
GROOVY_BLOCK = """// SIKKA_FORCE_COMPILE_SDK
subprojects {
    afterEvaluate { p ->
        def androidExt = p.extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.compileSdk = 36
            } catch (Throwable e) {
                println("compileSdk override skipped for ${p.name}: ${e}")
            }
        }
    }
}

"""
_root = None
for name, block in (("android/build.gradle.kts", KTS_BLOCK), ("android/build.gradle", GROOVY_BLOCK)):
    cand = pathlib.Path(name)
    if cand.exists():
        _root = (cand, block)
        break
if _root is None:
    raise SystemExit("ERROR: root android/build.gradle(.kts) not found")
_p, _block = _root
_t = _p.read_text(encoding="utf-8")
if "SIKKA_FORCE_COMPILE_SDK" not in _t:
    # لازم يتسجّل قبل أي subprojects { evaluationDependsOn(":app") } وإلا يفشل afterEvaluate
    _p.write_text(_block + _t, encoding="utf-8")
print("forced compileSdk 36 for all subprojects in", _p)


# ---------- Firebase Cloud Messaging (إشعارات ستارة الهاتف والتطبيق مغلق) ----------
# ضع ملف google-services.json (من إعدادات مشروع Firebase لحزمة com.sikka.driver) في جذر المشروع؛ يُنسخ ويُفعَّل تلقائياً.
import shutil
_gs = pathlib.Path("google-services.json")
if _gs.exists():
    shutil.copy(_gs, "android/app/google-services.json")
    GS_VER = "4.4.2"
    for name in ("android/settings.gradle.kts", "android/settings.gradle"):
        sp = pathlib.Path(name)
        if sp.exists():
            t = sp.read_text(encoding="utf-8")
            if "com.google.gms.google-services" not in t:
                if name.endswith(".kts"):
                    t = re.sub(r'(plugins\s*\{)', lambda m: m.group(1) + '\n    id("com.google.gms.google-services") version "' + GS_VER + '" apply false', t, count=1)
                else:
                    t = re.sub(r'(plugins\s*\{)', lambda m: m.group(1) + '\n    id "com.google.gms.google-services" version "' + GS_VER + '" apply false', t, count=1)
                sp.write_text(t, encoding="utf-8")
    for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
        ap = pathlib.Path(name)
        if ap.exists():
            t = ap.read_text(encoding="utf-8")
            if "com.google.gms.google-services" not in t:
                if name.endswith(".kts"):
                    t = re.sub(r'(plugins\s*\{)', lambda m: m.group(1) + '\n    id("com.google.gms.google-services")', t, count=1)
                else:
                    t = re.sub(r'(plugins\s*\{)', lambda m: m.group(1) + '\n    id "com.google.gms.google-services"', t, count=1)
                ap.write_text(t, encoding="utf-8")
    print("google-services.json applied")
else:
    print("WARNING: google-services.json غير موجود — إشعارات FCM قد لا تصل والتطبيق مغلق")

# ---------- iOS ----------
plist = pathlib.Path("ios/Runner/Info.plist")
t = plist.read_text(encoding="utf-8")
add = """	<key>NSLocationWhenInUseUsageDescription</key>
	<string>يستخدم التطبيق موقعك لتحديد نقطة الانطلاق وعرض الرحلة على الخريطة.</string>
"""
if ROLE == "driver":
    add += """	<key>NSPhotoLibraryUsageDescription</key>
	<string>لرفع مستندات التحقق (الهوية، الرخصة، الاستمارة).</string>
	<key>NSCameraUsageDescription</key>
	<string>لالتقاط صور مستندات التحقق.</string>
"""
add += """	<key>LSApplicationQueriesSchemes</key>
	<array><string>tel</string><string>sms</string><string>https</string></array>
"""
if "NSLocationWhenInUseUsageDescription" not in t:
    t = t.replace("</dict>\n</plist>", add + "</dict>\n</plist>")
t = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", r"\g<1>%s\g<2>" % APP_LABEL, t)
plist.write_text(t, encoding="utf-8")

pod = pathlib.Path("ios/Podfile")
if pod.exists():
    pt = pod.read_text(encoding="utf-8")
    pt = re.sub(r"#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.0'", pt, count=1)
    pod.write_text(pt, encoding="utf-8")

pb = pathlib.Path("ios/Runner.xcodeproj/project.pbxproj")
if pb.exists():
    x = pb.read_text(encoding="utf-8")
    def _bid(m):
        return "PRODUCT_BUNDLE_IDENTIFIER = %s%s;" % (PKG, ".RunnerTests" if m.group(1).endswith("RunnerTests") else "")
    x = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = (com\.sikka\.[A-Za-z0-9_.]+);", _bid, x)
    pb.write_text(x, encoding="utf-8")
print("patched OK")
