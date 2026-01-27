# 1. Ignore Flutter's references to Google Play Store dynamic delivery
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# 2. Ignore WireGuard's references to code-safety annotations
-dontwarn javax.annotation.**
-dontwarn javax.annotation.meta.**

# 3. Ensure WireGuard native logic remains untouched (re-adding just in case)
-keep class com.wireguard.android.backend.** { *; }
-keep class com.wireguard.crypto.** { *; }
-keep class com.wireguard.util.** { *; }
-keep class * extends android.net.VpnService { *; }