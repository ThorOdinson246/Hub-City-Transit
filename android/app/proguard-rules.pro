# Keep Flutter entry points and generated plugin registrant classes.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep JSON-serializable model metadata used by generated code.
-keepattributes Signature
-keepattributes RuntimeVisibleAnnotations
-keep class **.g.** { *; }
