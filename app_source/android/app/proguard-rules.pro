# Protect TensorFlow Lite from being stripped or obfuscated
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }
-keepnames class org.tensorflow.lite.** { *; }

# Protect Flutter plugins
-keep class io.flutter.plugins.** { *; }
-keep class com.baseflow.geolocator.** { *; }