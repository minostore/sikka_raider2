#!/usr/bin/env python3
"""يوقّع إصدار Release بمفتاح ثابت (من أسرار GitHub) بدل مفتاح debug.
نفس المفتاح مطلوب في كل تحديث؛ وإلا يرفض أندرويد التحديث ويحذّر Play Protect.
القيم تُقرأ من متغيرات البيئة: ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD."""
import glob, os, pathlib, re, sys

need = ["ANDROID_KEYSTORE_PATH", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD"]
missing = [k for k in need if not os.environ.get(k)]
if missing:
    print("::warning::مفتاح التوقيع غير مضبوط (" + ", ".join(missing) + ") — سيُوقَّع APK بمفتاح debug وقد يظهر تحذير Play Protect ولن تنجح التحديثات بين نسخ بمفاتيح مختلفة.")
    sys.exit(0)

done = False
for g in glob.glob("android/app/build.gradle*"):
    p = pathlib.Path(g); t = p.read_text(encoding="utf-8")
    if "SIKKA_RELEASE_SIGNING" in t:
        done = True; continue
    kts = g.endswith(".kts")
    if kts:
        block = '''    // SIKKA_RELEASE_SIGNING
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
'''
        t, n = re.subn(r"(?m)^(\s*)buildTypes\s*\{", lambda m: block + m.group(0), t, count=1)
        t = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("release")', t)
    else:
        block = '''    // SIKKA_RELEASE_SIGNING
    signingConfigs {
        release {
            storeFile file(System.getenv("ANDROID_KEYSTORE_PATH"))
            storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias System.getenv("ANDROID_KEY_ALIAS")
            keyPassword System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
'''
        t, n = re.subn(r"(?m)^(\s*)buildTypes\s*\{", lambda m: block + m.group(0), t, count=1)
        t = re.sub(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.release', t)
    if n == 0:
        raise SystemExit("ERROR: buildTypes block not found in " + g)
    p.write_text(t, encoding="utf-8")
    done = True
    print("Release signing applied to", g)
if not done:
    raise SystemExit("ERROR: android/app/build.gradle not found")
