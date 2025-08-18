To set up the application icons using `LOGO_APP` and `LOGO_APP_DARK`, we need to update the Android Manifest and configure the app icons. Here's how:

1. First, update the Android Manifest to support adaptive icons:

### [AndroidManifest.xml](file:///d%3A/hiddify-next-main/g4a4/g4a4/android/app/src/main/AndroidManifest.xml)

```xml


<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="g4a4"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round">
        <!-- ...existing code... -->
    </application>
</manifest>
```

2. Create a new file for your icons configuration:

### [ic_launcher.xml](file:///d%3A/hiddify-next-main/g4a4/g4a4/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml)

```xml


Made changes.

<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

3. Update the Flutter configuration to use the icons:

### [pubspec.yaml](file:///d%3A/hiddify-next-main/g4a4/g4a4/pubspec.yaml)

```yaml


Made changes.

# ...existing code...

flutter:
  # ...existing code...
  
  assets:
    - assets/flags/
    - assets/
    - assets/gifs/
    - assets/icons/

flutter_icons:
  android: true
  ios: true
  image_path: "assets/icons/LOGO_APP.png"
  image_path_android: "assets/icons/LOGO_APP.png"
  image_path_ios: "assets/icons/LOGO_APP.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icons/LOGO_APP.png"
  remove_alpha_ios: true
  web:
    generate: true
    image_path: "assets/icons/LOGO_APP.png"
    background_color: "#FFFFFF"
    theme_color: "#FFFFFF"

flutter_native_splash:
  # ...existing code...
  android_12:
    image: assets/icons/LOGO_APP.png
    icon_background_color: "#FFFFFF"
    image_dark: assets/icons/LOGO_APP_DARK.png
    icon_background_color_dark: "#000000"
```

4. Add the flutter_launcher_icons package:

### [build.gradle](file:///d%3A/hiddify-next-main/g4a4/g4a4/android/app/build.gradle)

```gradle


Made changes.

// ...existing code...

dependencies {
    // ...existing dependencies...
    implementation 'androidx.core:core:1.10.0'
}

// Add this at the end of the file
flutter_icons:
  android: true
  ios: true
  image_path: "../assets/icons/LOGO_APP.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "../assets/icons/LOGO_APP.png"
```

After making these changes:

1. Add your icon files:
   - Put `LOGO_APP.png` in `assets/icons/`
   - Put `LOGO_APP_DARK.png` in `assets/icons/`

2. Run the following commands:
```bash
flutter pub add flutter_launcher_icons
flutter pub get
flutter pub run flutter_launcher_icons
```

This will:
1. Use `LOGO_APP` for light mode
2. Use `LOGO_APP_DARK` for dark mode
3. Set up adaptive icons for Android
4. Configure proper icon handling for iOS
5. Set up web icons if needed

Make sure your icon files are high resolution (at least 1024x1024 pixels) and in PNG format.

Made changes.