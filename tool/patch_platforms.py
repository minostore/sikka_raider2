#!/usr/bin/env python3
"""يعدّل ملفات Android/iOS المولَّدة: الصلاحيات، اسم التطبيق، minSdk، منصة iOS، معرّف الحزمة."""
import re, sys, glob, pathlib

PKG = sys.argv[1]
ROLE = "driver"
APP_LABEL = "sikka rider"

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

for g in glob.glob("android/app/build.gradle*"):
    p = pathlib.Path(g); t = p.read_text(encoding="utf-8")
    t = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', t)
    t = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', t)
    t = re.sub(r'applicationId\s*=\s*"[^"]*"', 'applicationId = "%s"' % PKG, t)
    t = re.sub(r'applicationId\s+"[^"]*"', 'applicationId "%s"' % PKG, t)
    p.write_text(t, encoding="utf-8")

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
