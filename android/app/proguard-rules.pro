# 抑制 AGP 8.13 + R8 在 url_launcher_android 上的缺类噪声。
# 这些类由插件按场景注册，当前应用运行时不需要额外 keep 规则。
-dontwarn io.flutter.plugins.urllauncher.Messages$UrlLauncherApi
-dontwarn io.flutter.plugins.urllauncher.UrlLauncher

# Tink 通过 flutter_secure_storage 间接引入，仅引用这些编译期注解。
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
