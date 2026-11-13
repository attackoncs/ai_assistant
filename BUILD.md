# APK 打包完整指南

## 当前环境检查结果

| 组件 | 状态 | 位置 |
|------|------|------|
| Flutter | ✅ 已安装 | `$FLUTTER_ROOT\bin\flutter.bat`（>= 3.19.0） |
| JDK | ✅ 已安装 | `$JAVA_HOME`（JDK 17，推荐 Temurin） |
| Android SDK | ✅ 已安装 | `$ANDROID_HOME`（cmdline-tools\latest + platform-tools + platforms;android-36 + build-tools;36.0.0） |
| Gradle | ✅ 由 Wrapper 管理 | 9.3.1，已改为腾讯云镜像下载 |
| 依赖仓库 | ✅ 已配阿里云镜像 | 见 [国内网络加速](#国内网络加速) |

> 本项目 `compileSdk = 36`（Flutter 3.47 默认），必须安装 `platforms;android-36` 与 `build-tools;36.0.0`。

### 一键环境变量（每条命令内显式设置，PowerShell 不跨命令保持状态）

```powershell
$env:JAVA_HOME='<你的JDK17安装路径>'
$env:ANDROID_HOME='<你的Android SDK路径>'
$env:ANDROID_SDK_ROOT='<你的Android SDK路径>'
$env:Path="$env:JAVA_HOME\bin;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;<你的Flutter路径>\bin;$env:Path"
```

> 不要并行跑多个 `flutter` 命令：Flutter 工具会争用 `bin\cache\flutter.bat.lock`，导致全部卡死。
> 想绕开 `flutter.bat` 的 PowerShell 慢启动，可直接调用快照：
> ```powershell
> dart "$env:FLUTTER_ROOT\bin\cache\flutter_tools.snapshot" build apk --debug
> ```


---

## 步骤 1：安装 JDK 17

推荐 Temurin（Adoptium），免费开源：

```
下载：https://adoptium.net/temurin/releases/?version=17&os=windows&arch=x64&package=jdk
```

安装后把 `%JAVA_HOME%\bin` 加到 PATH。验证：
```powershell
java -version    # 应输出 openjdk version "17.x.x"
keytool -help    # 打包签名需要
```

---

## 步骤 2：安装 Android SDK（两种方式任选）

### 方式 A：Android Studio（推荐，最省心）

```
下载：https://developer.android.com/studio
安装：默认 C:\Program Files\Android\Android Studio
SDK Manager：装 Android SDK Platform 36 + Android SDK Build-Tools 36.0.0 + Android SDK Platform-Tools
```

环境变量：
```powershell
# 用户变量
ANDROID_HOME = <你的Android SDK路径>
ANDROID_SDK_ROOT = <你的Android SDK路径>
# PATH 里加：
# %ANDROID_HOME%\platform-tools
# %ANDROID_HOME%\cmdline-tools\latest\bin
```

### 方式 B：纯 cmdline-tools（轻量）

```
下载：https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
解压到：%ANDROID_HOME%\cmdline-tools\latest\
然后：
sdkmanager --install "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

---

## 步骤 3：把 Flutter 加到 PATH

系统环境变量 Path 里加：
```
<你的Flutter安装路径>\bin
```

然后开个新 PowerShell 窗口验证：
```powershell
flutter --version        # 应输出 Flutter 3.x.x
flutter doctor           # 所有勾选 OK 才能继续
```

doctor 里如果 `Android license status unknown`，跑：
```powershell
flutter doctor --android-licenses
# 一路输入 y 同意
```

---

## 步骤 4：生成 Android 工程 + 打包

```powershell
cd ai_assistant目录

# 1. 生成 android/ 、 ios/ 等平台目录（只在第一次跑）
flutter create --platforms=android .

# 2. 拉依赖
flutter pub get

# 3. 构建 debug APK（最快，debug 签名）
flutter build apk --debug
# 产物在：build\app\outputs\flutter-apk\app-debug.apk

# 4. 构建 release APK（需要签名，见下一节）
flutter build apk --release
# 产物在：build\app\outputs\flutter-apk\app-release.apk
```

**debug APK 可以直接装到手机上测试，不需要签名配置。**

---

## 步骤 5：Release 签名（正式发布需要）

### 5.1 生成 keystore

```powershell
keytool -genkeypair -v `
  -keystore upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

会问你：
- keystore password：记下来（或随便输，debug 无所谓）
- key password：同上
- 姓名/组织/城市等：随便填

### 5.2 创建 `android\key.properties`

```properties
storePassword=你填的密码
keyPassword=你填的密码
keyAlias=upload
storeFile=../upload-keystore.jks
```

### 5.3 修改 `android\app\build.gradle`

在 android { ... } 块里加：

```gradle
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
keystoreProperties.load(new FileInputStream(keystorePropertiesFile))

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
        }
    }
}
```

---

## 常见错误速查

| 错误 | 原因 | 解决 |
|------|------|------|
| `flutter: command not found` | PATH 没加 Flutter | `[Environment]::SetEnvironmentVariable('Path', ...)` |
| `ANDROID_HOME not set` | SDK 未安装 | 装 Android Studio |
| `Could not find or load main class org.gradle.launcher` | Gradle JDK 不匹配 | 装 JDK 17，`flutter config --jdk-dir=<你的JDK17路径>` |
| `Unsupported class file major version 61` | 用了 JDK 8/11 | 换 JDK 17 |
| `License for package Android SDK Build-Tools 34.0.0 not accepted` | 没接受许可 | `flutter doctor --android-licenses` 或 `sdkmanager --licenses` |
| `A problem occurred configuring root project 'android'.` | 首次跑网络下不来 Gradle | 开代理或用国内镜像（见下） |

---

## 国内网络加速

**最关键的一条**：Flutter 引擎产物（~500MB 的 debug 引擎 jar）默认从
`storage.googleapis.com/download.flutter.io` 下载，国内基本不可达，会导致构建无限卡死。
已设置用户环境变量（永久生效）：

```powershell
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL','https://storage.flutter-io.cn','User')
[Environment]::SetEnvironmentVariable('PUB_HOSTED_URL','https://pub.flutter-io.cn','User')
```

若只对单条命令生效：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
```

其余镜像配置（已在工程内生效）：

1. `android/gradle/wrapper/gradle-wrapper.properties`
   ```properties
   distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-9.3.1-all.zip
   ```
2. `android/settings.gradle.kts` 的 `pluginManagement.repositories` 与
   `android/build.gradle.kts` 的 `allprojects.repositories` 都加入阿里云镜像并置于最前：
   ```kotlin
   maven("https://maven.aliyun.com/repository/google")
   maven("https://maven.aliyun.com/repository/public")
   ```

如需全局生效（所有工程），可另建 `%USERPROFILE%\.gradle\init.d\mirror.gradle`：

```gradle
allprojects {
    buildscript {
        repositories {
            maven { url 'https://maven.aliyun.com/repository/google' }
            maven { url 'https://maven.aliyun.com/repository/public' }
            maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        }
    }
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
    }
}
```

