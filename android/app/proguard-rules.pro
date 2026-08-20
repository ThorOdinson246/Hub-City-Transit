# Keep Flutter entry points and generated plugin registrant classes.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Plugin implementations. These survive today only because GeneratedPluginRegistrant
# constructs them directly; anything moving to reflective or deferred registration
# breaks method channels at runtime, in release only, with a MissingPluginException
# that never reproduces in debug.
-keep class io.flutter.plugins.** { *; }

# Note: there is deliberately no rule here for Dart's generated *.g.dart
# serializers. They are compiled to AOT native code and are outside R8's reach
# entirely — a `-keep class **.g.** { *; }` rule matches Java package names and
# protects nothing, while implying the models are covered.

# Flutter's embedding references Play Core split-install classes internally,
# but a standard APK build doesn't ship them — safe to suppress these warnings.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
