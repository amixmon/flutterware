#!/system/bin/sh
set -eu

jdk="$1"
sdk="$2"
workspace="$3"
debug_tools="$4"

java="$jdk/bin/java"
jar="$jdk/bin/jar"
aapt2="$sdk/build-tools/36.0.0/aapt2"
apksigner="$sdk/build-tools/36.0.0/lib/apksigner.jar"
android_jar="$sdk/platforms/android-36/android.jar"
template="$debug_tools/apk-template"
kernel="$workspace/flutter-direct-debug/app.dill"
build="$workspace/direct-flutter-apk"
apk="$workspace/flutter-app.apk"

for required in "$template/classes.dex" "$template/lib/arm64-v8a/libflutter.so" \
  "$debug_tools/vm_snapshot_data" "$debug_tools/isolate_snapshot_data" "$kernel"; do
  if [ ! -s "$required" ]; then
    echo "FLUTTWARE_DIRECT_FLUTTER_MISSING=$required" >&2
    exit 2
  fi
done

echo FLUTTWARE_DIRECT_FLUTTER_STEP_PREPARE
rm -rf "$build"
mkdir -p "$build/res/values" "$build/payload/assets/flutter_assets"

printf '%s\n' \
  '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="dev.fluttware.fluttergenerated">' \
  '  <uses-permission android:name="android.permission.INTERNET" />' \
  '  <application android:name="android.app.Application" android:label="Fluttware Flutter" android:theme="@style/NormalTheme" android:usesCleartextTraffic="true">' \
  '    <activity android:name="com.example.fluttware_reference.MainActivity" android:exported="true" android:launchMode="singleTop" android:taskAffinity="" android:theme="@style/LaunchTheme" android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode" android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize">' \
  '      <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />' \
  '      <intent-filter>' \
  '        <action android:name="android.intent.action.MAIN" />' \
  '        <category android:name="android.intent.category.LAUNCHER" />' \
  '      </intent-filter>' \
  '    </activity>' \
  '    <meta-data android:name="flutterEmbedding" android:value="2" />' \
  '    <uses-library android:name="androidx.window.extensions" android:required="false" />' \
  '    <uses-library android:name="androidx.window.sidecar" android:required="false" />' \
  '  </application>' \
  '</manifest>' > "$build/AndroidManifest.xml"

printf '%s\n' \
  '<resources>' \
  '  <style name="LaunchTheme" parent="android:style/Theme.Material.Light.NoActionBar">' \
  '    <item name="android:windowBackground">@android:color/white</item>' \
  '  </style>' \
  '  <style name="NormalTheme" parent="android:style/Theme.Material.Light.NoActionBar">' \
  '    <item name="android:windowBackground">?android:colorBackground</item>' \
  '  </style>' \
  '</resources>' > "$build/res/values/styles.xml"

echo FLUTTWARE_DIRECT_FLUTTER_STEP_AAPT2
"$aapt2" compile --dir "$build/res" -o "$build/compiled-res.zip"
"$aapt2" link --auto-add-overlay -I "$android_jar" \
  --manifest "$build/AndroidManifest.xml" --min-sdk-version 26 \
  --target-sdk-version 36 --version-code 1 --version-name 0.1.0 \
  -R "$build/compiled-res.zip" -o "$build/resources.apk"

echo FLUTTWARE_DIRECT_FLUTTER_STEP_ASSETS
cp -R "$template/." "$build/payload/"
cp "$kernel" "$build/payload/assets/flutter_assets/kernel_blob.bin"
cp "$debug_tools/vm_snapshot_data" \
  "$build/payload/assets/flutter_assets/vm_snapshot_data"
cp "$debug_tools/isolate_snapshot_data" \
  "$build/payload/assets/flutter_assets/isolate_snapshot_data"

echo FLUTTWARE_DIRECT_FLUTTER_STEP_PACKAGE
cp "$build/resources.apk" "$build/unsigned.apk"
"$jar" uf "$build/unsigned.apk" -C "$build/payload" .

if [ ! -f "$workspace/direct-debug.jks" ]; then
  echo FLUTTWARE_DIRECT_FLUTTER_STEP_KEYGEN
  "$jdk/bin/keytool" -genkeypair -noprompt \
    -keystore "$workspace/direct-debug.jks" -storepass android \
    -keypass android -alias androiddebugkey \
    -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 \
    -validity 10000
fi

echo FLUTTWARE_DIRECT_FLUTTER_STEP_SIGN
rm -f "$apk"
"$java" -cp "$apksigner" com.android.apksigner.ApkSignerTool sign \
  --ks "$workspace/direct-debug.jks" --ks-pass pass:android \
  --key-pass pass:android --ks-key-alias androiddebugkey \
  --out "$apk" "$build/unsigned.apk"

echo FLUTTWARE_DIRECT_FLUTTER_STEP_VERIFY
"$java" -cp "$apksigner" com.android.apksigner.ApkSignerTool verify --verbose "$apk"
test -s "$apk"
echo "FLUTTWARE_DIRECT_FLUTTER_APK_SIZE=$(wc -c < "$apk")"
echo "FLUTTWARE_DIRECT_FLUTTER_APK_PATH=$apk"
echo FLUTTWARE_DIRECT_FLUTTER_APK_OK
