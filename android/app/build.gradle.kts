plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.cotrainr_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    
    // Suppress Java 8 obsolete warnings from dependencies
    tasks.withType<JavaCompile> {
        options.compilerArgs.add("-Xlint:-options")
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.cotrainr_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // Required for health package
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Copy APK to Flutter-expected location after build
afterEvaluate {
    tasks.named("assembleDebug") {
        doLast {
            val flutterApkDir = file("../../build/app/outputs/flutter-apk")
            flutterApkDir.mkdirs()
            
            // Try flutter-apk location first, then fallback to apk location
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
        doLast {
            val flutterApkDir = file("../../build/app/outputs/flutter-apk")
            flutterApkDir.mkdirs()
            
            // Try flutter-apk location first, then fallback to apk location
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
