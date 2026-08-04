#!/system/bin/sh
set -eu

jdk="$1"
sdk="$2"
workspace="$3"
build="$workspace/direct-android"
apk="$workspace/app.apk"

java="$jdk/bin/java"
javac="$jdk/bin/javac"
jar="$jdk/bin/jar"
keytool="$jdk/bin/keytool"
aapt2="$sdk/build-tools/36.0.0/aapt2"
d8="$sdk/build-tools/36.0.0/lib/d8.jar"
apksigner="$sdk/build-tools/36.0.0/lib/apksigner.jar"
android_jar="$sdk/platforms/android-36/android.jar"

echo FLUTTWARE_DIRECT_STEP_PREPARE
rm -rf "$build"
mkdir -p "$build/res/values" "$build/src/dev/fluttware/generated" \
  "$build/gen" "$build/classes" "$build/dex"

printf '%s\n' \
  '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="dev.fluttware.generated">' \
  '  <application android:theme="@style/AppTheme" android:label="Fluttware Direct">' \
  '    <activity android:name=".MainActivity" android:exported="true">' \
  '      <intent-filter>' \
  '        <action android:name="android.intent.action.MAIN" />' \
  '        <category android:name="android.intent.category.LAUNCHER" />' \
  '      </intent-filter>' \
  '    </activity>' \
  '  </application>' \
  '</manifest>' > "$build/AndroidManifest.xml"

printf '%s\n' \
  '<resources>' \
  '  <style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar" />' \
  '</resources>' > "$build/res/values/styles.xml"

printf '%s\n' \
  'package dev.fluttware.generated;' \
  'import android.app.Activity;' \
  'import android.os.Bundle;' \
  'import android.widget.TextView;' \
  'public final class MainActivity extends Activity {' \
  '  @Override public void onCreate(Bundle state) {' \
  '    super.onCreate(state);' \
  '    TextView view = new TextView(this);' \
  '    view.setText("FLUTTWARE DIRECT APK OK\\nNo Gradle was used.");' \
  '    view.setTextSize(24);' \
  '    view.setPadding(48, 96, 48, 48);' \
  '    setContentView(view);' \
  '  }' \
  '}' > "$build/src/dev/fluttware/generated/MainActivity.java"

echo FLUTTWARE_DIRECT_STEP_AAPT2_COMPILE
"$aapt2" compile --dir "$build/res" -o "$build/compiled-res.zip"

echo FLUTTWARE_DIRECT_STEP_AAPT2_LINK
"$aapt2" link --auto-add-overlay -I "$android_jar" --manifest "$build/AndroidManifest.xml" \
  --java "$build/gen" --min-sdk-version 26 --target-sdk-version 28 \
  --version-code 1 --version-name 1.0 -R "$build/compiled-res.zip" \
  -o "$build/resources.apk"

echo FLUTTWARE_DIRECT_STEP_JAVAC
"$javac" -source 8 -target 8 -bootclasspath "$android_jar" \
  -d "$build/classes" \
  "$build/src/dev/fluttware/generated/MainActivity.java" \
  "$build/gen/dev/fluttware/generated/R.java"

echo FLUTTWARE_DIRECT_STEP_D8
"$jar" cf "$build/classes.jar" -C "$build/classes" .
"$java" -cp "$d8" com.android.tools.r8.D8 \
  --lib "$android_jar" --min-api 26 --output "$build/dex" "$build/classes.jar"

echo FLUTTWARE_DIRECT_STEP_PACKAGE
cp "$build/resources.apk" "$build/unsigned.apk"
"$jar" uf "$build/unsigned.apk" -C "$build/dex" classes.dex

if [ ! -f "$workspace/direct-debug.jks" ]; then
  echo FLUTTWARE_DIRECT_STEP_KEYGEN
  "$keytool" -genkeypair -noprompt -keystore "$workspace/direct-debug.jks" \
    -storepass android -keypass android -alias androiddebugkey \
    -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 \
    -validity 10000
fi

echo FLUTTWARE_DIRECT_STEP_SIGN
rm -f "$apk"
"$java" -cp "$apksigner" com.android.apksigner.ApkSignerTool sign \
  --ks "$workspace/direct-debug.jks" --ks-pass pass:android \
  --key-pass pass:android --ks-key-alias androiddebugkey \
  --out "$apk" "$build/unsigned.apk"

echo FLUTTWARE_DIRECT_STEP_VERIFY
"$java" -cp "$apksigner" com.android.apksigner.ApkSignerTool verify --verbose "$apk"
test -s "$apk"
echo FLUTTWARE_DIRECT_APK_OK
echo "FLUTTWARE_DIRECT_APK_PATH=$apk"
