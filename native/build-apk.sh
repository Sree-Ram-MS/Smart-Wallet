#!/usr/bin/env bash
# Builds SmartWallet-Native-v0.5.apk without Gradle: aapt2 + javac + d8 + apksigner.
# Needs: JDK 17 (javac, keytool) and Android SDK platform 34 + build-tools 34.0.0.
# Toolchain defaults point at the copies already installed on this machine
# (~/workspace/period-tracker/tools); override with JAVA_HOME / ANDROID_SDK_ROOT.
# Phase 5: also needs the vendored Google Sign-In SDK in libs/ —
# run ./fetch-libs.sh once first (downloads from Google Maven).
set -euo pipefail
cd "$(dirname "$0")"

if [ -z "${JAVA_HOME:-}" ] && [ -x "$HOME/workspace/period-tracker/tools/jdk/bin/javac" ]; then
  export JAVA_HOME="$HOME/workspace/period-tracker/tools/jdk"
fi
if [ -n "${JAVA_HOME:-}" ]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

ANDROID_JAR="${ANDROID_JAR:-}"
BUILD_TOOLS="${BUILD_TOOLS:-}"
if [ -z "$ANDROID_JAR" ]; then
  for root in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "$HOME/Android/Sdk" "$HOME/workspace/period-tracker/tools/android-sdk"; do
    if [ -n "$root" ] && [ -f "$root/platforms/android-34/android.jar" ]; then
      ANDROID_JAR="$root/platforms/android-34/android.jar"
      BUILD_TOOLS="$root/build-tools/34.0.0"
      break
    fi
  done
fi

PKG=app/src/main/java/com/smartwallet/smart_wallet

if [ "${1:-}" = "test" ]; then
  # Pure-Java classes (models, WalletLogic, the Phase 4 codecs) plus
  # the Phase 5 pure pieces (SessionGate, DriveCodec) and the widget
  # provider's pure formatting statics (compiled against android.jar
  # stubs; only the statics run).
  : "${ANDROID_JAR:?android.jar (platform 34) not found - set ANDROID_SDK_ROOT}"
  rm -rf build/test-classes && mkdir -p build/test-classes
  javac -encoding UTF-8 -cp "$ANDROID_JAR" -d build/test-classes \
    "$PKG/Account.java" "$PKG/Category.java" "$PKG/SplitMember.java" \
    "$PKG/Transaction.java" "$PKG/PlannedPayment.java" "$PKG/DebtCredit.java" \
    "$PKG/Template.java" "$PKG/UserProfile.java" "$PKG/WalletDb.java" \
    "$PKG/WalletLogic.java" \
    "$PKG/MiniJson.java" "$PKG/BackupCodec.java" "$PKG/CsvCodec.java" \
    "$PKG/SessionGate.java" "$PKG/DriveCodec.java" \
    "$PKG/WidgetFormat.java" \
    tests/TestWalletLogic.java tests/TestPhase4.java tests/TestPhase5.java
  java -cp "build/test-classes:$ANDROID_JAR" TestWalletLogic
  java -cp "build/test-classes:$ANDROID_JAR" TestPhase4
  java -cp "build/test-classes:$ANDROID_JAR" TestPhase5
  exit 0
fi

: "${ANDROID_JAR:?android.jar (platform 34) not found - set ANDROID_SDK_ROOT}"
: "${BUILD_TOOLS:?build-tools 34.0.0 not found}"

if [ ! -d libs/jars ] || [ -z "$(ls libs/jars/*.jar 2>/dev/null)" ]; then
  echo "ERROR: libs/jars is empty — run ./fetch-libs.sh first (Phase 5 vendored SDK)." >&2
  exit 1
fi
LIB_CP=$(ls libs/jars/*.jar | tr '\n' ':')

# Clean build outputs but KEEP build/debug.keystore, so every Phase build is
# signed with the same key and can install over the previous one.
rm -rf build/compiled build/classes build/dex build/gen \
  build/base.apk build/unsigned.apk build/aligned.apk build/sources.txt
mkdir -p build/compiled build/classes build/dex build/gen
SRC=app/src/main

# 1. Resources -> compiled + linked base APK (also generates R.java for
#    our package AND, via --extra-packages, for every vendored library).
"$BUILD_TOOLS/aapt2" compile --dir "$SRC/res" -o build/compiled/res.zip
RES_ZIPS="build/compiled/res.zip"
EXTRA_PACKAGES=""
for d in libs/x/*/; do
  name=$(basename "$d")
  if [ -d "$d/res" ] && [ -n "$(find "$d/res" -type f | head -1)" ]; then
    "$BUILD_TOOLS/aapt2" compile --dir "$d/res" -o "build/compiled/lib-$name.zip"
    RES_ZIPS="$RES_ZIPS build/compiled/lib-$name.zip"
  fi
  pkg=$(grep -o 'package="[^"]*"' "$d/AndroidManifest.xml" | head -1 | sed 's/package="//; s/"$//')
  if [ -n "$pkg" ]; then
    EXTRA_PACKAGES="${EXTRA_PACKAGES:+$EXTRA_PACKAGES:}$pkg"
  fi
done
"$BUILD_TOOLS/aapt2" link -I "$ANDROID_JAR" \
  --manifest "$SRC/AndroidManifest.xml" \
  --java build/gen \
  --extra-packages "$EXTRA_PACKAGES" \
  --auto-add-overlay \
  -o build/base.apk $RES_ZIPS

# 2. Java -> classes -> dex (app code + the vendored library jars;
#    d8 emits as many classes*.dex as needed).
find "$SRC/java" build/gen -name '*.java' > build/sources.txt
javac -encoding UTF-8 -source 8 -target 8 -cp "$ANDROID_JAR:$LIB_CP" \
  -d build/classes @build/sources.txt
"$BUILD_TOOLS/d8" --lib "$ANDROID_JAR" --min-api 26 --output build/dex \
  $(find build/classes -name '*.class') libs/jars/*.jar

# 3. Pack dex, align, sign with a project-local debug key
cp build/base.apk build/unsigned.apk
(cd build/dex && zip -q ../unsigned.apk classes*.dex)
"$BUILD_TOOLS/zipalign" -f 4 build/unsigned.apk build/aligned.apk
if [ ! -f build/debug.keystore ]; then
  keytool -genkeypair -keystore build/debug.keystore -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
"$BUILD_TOOLS/apksigner" sign --ks build/debug.keystore --ks-pass pass:android \
  --key-pass pass:android --out SmartWallet-Native-v0.5.apk build/aligned.apk
"$BUILD_TOOLS/apksigner" verify SmartWallet-Native-v0.5.apk

ls -l SmartWallet-Native-v0.5.apk
sha256sum SmartWallet-Native-v0.5.apk
echo "OK: SmartWallet-Native-v0.5.apk"
