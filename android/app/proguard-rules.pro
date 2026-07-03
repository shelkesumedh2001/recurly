# R8 keep rules for Recurly (Task 12).
# Flutter's own engine/embedding rules ship with the Flutter Gradle plugin;
# Firebase/Play services ship consumer rules in their AARs. Only plugins
# that reflect over their own model classes need help here.

# flutter_local_notifications — reflects via Gson when (de)serializing
# scheduled notifications; stripping these breaks every scheduled reminder.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson generic type resolution (used by flutter_local_notifications).
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# home_widget passes widget data over platform channels + a BroadcastReceiver
# that must survive shrinking.
-keep class es.antonborri.home_widget.** { *; }

# Google Sign-In / Credentials: R8 occasionally strips the legacy auth API
# surface google_sign_in still calls into.
-dontwarn com.google.android.gms.auth.**

# Keep Play Core split-install stubs referenced by Flutter's deferred
# components support (not used, but referenced → R8 would fail the build).
-dontwarn com.google.android.play.core.**
