import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.cotrainr.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    tasks.withType<JavaCompile> {
        options.compilerArgs.add("-Xlint:-options")
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cotrainr.app"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to the debug signing key for a production build.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Copy APK to Flutter-expected location after build.
afterEvaluate {
    tasks.named("assembleDebug") {
        doLast {
            val flutterApkDir = file("../../build/app/outputs/flutter-apk")
            flutterApkDir.mkdirs()

            val apkFile = file("build/outputs/flutter-apk/app-debug.apk")
            val fallbackApkFile = file("build/outputs/apk/debug/app-debug.apk")
            val flutterApkFile = file("../../build/app/outputs/flutter-apk/app-debug.apk")

            val sourceApk = when {
                apkFile.exists() -> apkFile
                fallbackApkFile.exists() -> fallbackApkFile
                else -> null
            }

            if (sourceApk != null) {
                sourceApk.copyTo(flutterApkFile, overwrite = true)
                println("Copied APK to ${flutterApkFile.absolutePath}")
            } else {
                println("Warning: APK not found in expected locations")
            }
        }
    }

    tasks.named("assembleRelease") {
        doFirst {
            if (!hasReleaseKeystore) {
                throw GradleException(
                    "Release signing is not configured. Create android/key.properties from android/key.properties.example and keep the real keystore/passwords out of Git."
                )
            }
        }
        doLast {
            val flutterApkDir = file("../../build/app/outputs/flutter-apk")
            flutterApkDir.mkdirs()

            val apkFile = file("build/outputs/flutter-apk/app-release.apk")
            val fallbackApkFile = file("build/outputs/apk/release/app-release.apk")
            val flutterApkFile = file("../../build/app/outputs/flutter-apk/app-release.apk")

            val sourceApk = when {
                apkFile.exists() -> apkFile
                fallbackApkFile.exists() -> fallbackApkFile
                else -> null
            }

            if (sourceApk != null) {
                sourceApk.copyTo(flutterApkFile, overwrite = true)
                println("Copied APK to ${flutterApkFile.absolutePath}")
            } else {
                println("Warning: APK not found in expected locations")
            }
        }
    }
}
