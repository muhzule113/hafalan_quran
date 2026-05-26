# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Play Core (missing classes fix)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Supabase
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.gson.** { *; }
-keep class kotlinx.serialization.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# flutter_sound
-keep class com.xtl.xy.** { *; }
-keep class com.dooboolab.** { *; }
-keep class net.jpountz.** { *; }
-dontwarn com.xtl.**
-dontwarn com.dooboolab.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# permission_handler
-keep class com.baseflow.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# ExoPlayer (used by flutter_sound)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# device_info_plus
-keep class io.flutter.plugins.deviceinfo.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
