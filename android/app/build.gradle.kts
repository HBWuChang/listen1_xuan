import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 引用 key.properties 文件
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val storeFileVal = file(
    System.getenv("KEYSTORE") ?: keystoreProperties.getProperty("storeFile") ?: "xuan.jks"
)
val storePasswordVal = System.getenv("KEYSTORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
val keyAliasVal = System.getenv("KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
val keyPasswordVal = System.getenv("KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")

android {
    namespace = "com.xiebian.listen1_xuan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    defaultConfig {
        applicationId = "com.xiebian.listen1_xuan"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 添加签名配置
        create("release") {
            storeFile = storeFileVal
            storePassword = storePasswordVal
            keyAlias = keyAliasVal
            keyPassword = keyPasswordVal
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true           // 删除无用代码
            isShrinkResources = true         // 删除无用资源
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    val exoplayerVersion = "1.7.1"
    implementation("androidx.media3:media3-exoplayer:$exoplayerVersion")
    implementation("androidx.media3:media3-exoplayer-dash:$exoplayerVersion")
    implementation("androidx.media3:media3-ui-compose:$exoplayerVersion")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
