# Flutter wrapper and engine keep rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Flutter plugins reflection and JNI targets
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.llfbandit.record.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }

# Firebase and Google Play Services rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Background messaging and entry points
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
