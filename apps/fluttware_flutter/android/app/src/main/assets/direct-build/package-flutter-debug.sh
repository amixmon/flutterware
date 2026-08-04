#!/system/bin/sh
set -eu

jdk="$1"
sdk="$2"
debug_tools="$3"
kernel="$4"
work="$5"
apk="$6"
package="$7"
app_label="$8"
keystore="$9"
launcher_icon="${10}"

java="$jdk/bin/java"
jar="$jdk/bin/jar"
aapt2="$sdk/build-tools/36.0.0/aapt2"
apksigner="$sdk/build-tools/36.0.0/lib/apksigner.jar"
android_jar="$sdk/platforms/android-36/android.jar"
template="$debug_tools/apk-template"
build="$work/package"

case "$package" in
  ''|*[!a-zA-Z0-9_.]*)
    echo "Invalid Android package: $package" >&2
    exit 2
    ;;
esac

for required in "$template/classes.dex" "$template/lib/arm64-v8a/libflutter.so" \
  "$debug_tools/vm_snapshot_data" "$debug_tools/isolate_snapshot_data" "$kernel"; do
  if [ ! -s "$required" ]; then
    echo "FLUTTWARE_PACKAGE_MISSING=$required" >&2
    exit 2
  fi
done
if [ ! -s "$launcher_icon" ]; then
  echo "FLUTTWARE_PACKAGE_MISSING=$launcher_icon" >&2
  exit 2
fi

echo "Preparing Android package"
rm -rf "$build"
mkdir -p "$build/res/values" "$build/res/mipmap-xxxhdpi" \
  "$build/payload/assets/flutter_assets"
mkdir -p "$(dirname "$apk")" "$(dirname "$keystore")"
cp "$launcher_icon" "$build/res/mipmap-xxxhdpi/ic_launcher.png"

printf '%s\n' \
  "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\" package=\"$package\">" \
  '  <uses-permission android:name="android.permission.INTERNET" />' \
  "  <application android:name=\"android.app.Application\" android:label=\"$app_label\" android:icon=\"@mipmap/ic_launcher\" android:roundIcon=\"@mipmap/ic_launcher\" android:theme=\"@style/NormalTheme\" android:usesCleartextTraffic=\"true\">" \
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

echo "Compiling Android resources"
"$aapt2" compile --dir "$build/res" -o "$build/compiled-res.zip"
"$aapt2" link --auto-add-overlay -I "$android_jar" \
  --manifest "$build/AndroidManifest.xml" --min-sdk-version 26 \
  --target-sdk-version 36 --version-code 1 --version-name 0.1.0 \
  -R "$build/compiled-res.zip" -o "$build/resources.apk"

echo "Merging Flutter engine and assets"
cp -R "$template/." "$build/payload/"
cp "$kernel" "$build/payload/assets/flutter_assets/kernel_blob.bin"
cp "$debug_tools/vm_snapshot_data" \
  "$build/payload/assets/flutter_assets/vm_snapshot_data"
cp "$debug_tools/isolate_snapshot_data" \
  "$build/payload/assets/flutter_assets/isolate_snapshot_data"

cp "$build/resources.apk" "$build/unsigned.apk"
"$jar" uf "$build/unsigned.apk" -C "$build/payload" .

if [ ! -f "$keystore" ]; then
  echo "Creating local signing key"
  "$jdk/bin/keytool" -genkeypair -noprompt \
    -keystore "$keystore" -storepass android \
    -keypass android -alias fluttware \
    -dname 'CN=Flutterware Local Build,O=Flutterware,C=ET' \
    -keyalg RSA -keysize 2048 -validity 10000
fi

echo "Signing APK"
rm -f "$apk.tmp"
"$java" -cp "$apksigner" com.android.apksigner.ApkSignerTool sign \
  --ks "$keystore" --ks-pass pass:android \
  --key-pass pass:android --ks-key-alias fluttware \
  --out "$apk.tmp" "$build/unsigned.apk"

"$java" -cp "$apksigner" com.android.apksigner.ApkSignerTool verify --verbose "$apk.tmp"
mv "$apk.tmp" "$apk"
test -s "$apk"
echo "APK ready ($(wc -c < "$apk") bytes)"
