#!/usr/bin/env bash
# fetch-libs.sh — vendor the Google Sign-In SDK (Phase 5) WITHOUT Gradle.
#
# Downloads the AARs/JARs that Flutter's google_sign_in_android 6.2.1
# resolves (play-services-auth 21.2.0 + its POM dependency tree, with
# Gradle-style newest-version conflict resolution) from Google Maven
# (dl.google.com) and Maven Central (Kotlin/Guava, which Google Maven
# does not host), then prepares them for the aapt2+javac+d8 pipeline:
#
#   libs/dl/    the downloaded .aar / .jar files (kept for reference)
#   libs/x/     each AAR extracted (classes.jar, res/, AndroidManifest)
#   libs/jars/  one flat .jar per artifact for javac -cp and d8 input
#
# libs/ is NOT committed to GitHub (binaries); run this script once
# after cloning to recreate it. Requires: curl, unzip, zip.
set -euo pipefail
cd "$(dirname "$0")"
DL=libs/dl
X=libs/x
JARS=libs/jars
mkdir -p "$DL" "$X" "$JARS"

# groupId artifactId version type   (type: aar|jar)
ARTIFACTS="
com.google.android.gms play-services-auth 21.2.0 aar
com.google.android.gms play-services-auth-base 18.0.10 aar
com.google.android.gms play-services-auth-api-phone 18.0.2 aar
com.google.android.gms play-services-base 18.3.0 aar
com.google.android.gms play-services-basement 18.3.0 aar
com.google.android.gms play-services-tasks 18.1.0 aar
com.google.android.gms play-services-fido 20.0.1 aar
androidx.fragment fragment 1.5.7 aar
androidx.activity activity 1.5.1 aar
androidx.loader loader 1.1.0 aar
androidx.core core 1.8.0 aar
androidx.core core-ktx 1.2.0 aar
androidx.lifecycle lifecycle-runtime 2.5.1 aar
androidx.lifecycle lifecycle-viewmodel 2.5.1 aar
androidx.lifecycle lifecycle-viewmodel-savedstate 2.5.1 aar
androidx.lifecycle lifecycle-livedata-core 2.5.1 aar
androidx.lifecycle lifecycle-common 2.5.1 jar
androidx.arch.core core-runtime 2.1.0 aar
androidx.arch.core core-common 2.1.0 jar
androidx.versionedparcelable versionedparcelable 1.1.1 aar
androidx.savedstate savedstate 1.2.0 aar
androidx.viewpager viewpager 1.0.0 aar
androidx.customview customview 1.0.0 aar
androidx.tracing tracing 1.0.0 aar
androidx.annotation annotation 1.5.0 jar
androidx.annotation annotation-experimental 1.1.0 aar
androidx.collection collection 1.1.0 jar
com.google.guava listenablefuture 1.0 jar
org.jetbrains.kotlin kotlin-stdlib 1.6.21 jar
org.jetbrains.kotlin kotlin-stdlib-jdk7 1.6.0 jar
org.jetbrains.kotlin kotlin-stdlib-jdk8 1.6.0 jar
org.jetbrains annotations 13.0 jar
org.jetbrains.kotlinx kotlinx-coroutines-android 1.6.1 jar
org.jetbrains.kotlinx kotlinx-coroutines-core-jvm 1.6.1 jar
"
# Deliberately NOT fetched: androidx.concurrent:concurrent-futures —
# its only class is a stub com.google.common.util.concurrent.
# ListenableFuture that duplicates the real one in Guava's
# listenablefuture-1.0.jar (d8 rejects duplicate classes).

echo "$ARTIFACTS" | while read -r g a v t; do
  [ -z "$g" ] && continue
  file="$a-$v.$t"
  path="${g//.//}/$a/$v/$file"
  if [ ! -s "$DL/$file" ]; then
    if ! curl -sSfL --max-time 180 -o "$DL/$file" \
        "https://dl.google.com/dl/android/maven2/$path"; then
      curl -sSfL --max-time 180 -o "$DL/$file" \
        "https://repo1.maven.org/maven2/$path"
    fi
    echo "downloaded $file"
  fi
  if [ "$t" = "aar" ]; then
    rm -rf "$X/$a-$v"
    mkdir -p "$X/$a-$v"
    unzip -qo "$DL/$file" -d "$X/$a-$v"
    cp "$X/$a-$v/classes.jar" "$JARS/$a-$v.jar"
  else
    cp "$DL/$file" "$JARS/$a-$v.jar"
  fi
done

# The three Kotlin stdlib jars each carry META-INF/versions/9/
# module-info.class — the same class three times, which d8 rejects.
# Strip it from the prepared copies (the downloads stay untouched).
for j in "$JARS"/kotlin-stdlib*.jar; do
  zip -qd "$j" 'META-INF/versions/9/module-info.class' >/dev/null 2>&1 || true
done

echo "Prepared $(ls "$JARS" | wc -l) jars in $JARS/:"
ls -la "$JARS"
