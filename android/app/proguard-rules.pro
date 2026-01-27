# Flutter standard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WireGuard specific rules
# This prevents the backend and JNI bridge from being renamed or removed
-keep class com.wireguard.android.backend.** { *; }
-keep class com.wireguard.crypto.** { *; }
-keep class com.wireguard.util.** { *; }

# Also keep the specific VpnService if it's in a different package
-keep class * extends android.net.VpnService { *; }