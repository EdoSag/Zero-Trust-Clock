import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. On CI the workflow restores the keystore from repository
// secrets and exports the CM_* variables (same names the other Zero Trust apps
// use). Locally, put the keystore details in android/key.properties.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.sagron.zerotrustclock"
    // Newer androidx libraries (pulled in by the shared core's plugins) need
    // API 37 to compile against; targetSdk, the runtime behaviour, stays Flutter's.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.sagron.zerotrustclock"
        // 28: the shared core keeps the biometric unlock key in the Keystore.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Two editions from one module:
    //   full     the clock with the optional Zero-Trust account.
    //            `flutter build apk --flavor full` (the default flavor).
    //   offline  the same clock with no INTERNET permission: no account, no
    //            sync, no downloads. `flutter build apk --flavor offline`.
    flavorDimensions += "edition"
    productFlavors {
        create("full") {
            dimension = "edition"
        }
        create("offline") {
            dimension = "edition"
            // Its own app, so it can sit next to the full edition and never
            // updates into it.
            applicationIdSuffix = ".offline"
        }
    }

    signingConfigs {
        create("release") {
            if (System.getenv("CM_BUILD_DIR") != null) {
                storeFile = file(System.getenv("CM_BUILD_DIR") + "/codemagic.keystore")
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            } else if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Without a release keystore (a fresh local checkout), fall back to
            // the debug keys so `flutter run --release` still works.
            signingConfig = if (System.getenv("CM_BUILD_DIR") != null || keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Reads QR codes and barcodes for the "scan a code" wake-up task, on
    // the phone: plain Java, no Google services (Apache 2.0).
    implementation("com.google.zxing:core:3.5.3")
    // The alarm scheduler's unit tests (engine/core is plain Kotlin).
    // org.json is part of Android; on the test machine it comes from here.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
