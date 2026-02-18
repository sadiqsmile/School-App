plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

android {
    namespace = "com.hongirana.school"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by some dependencies (e.g. flutter_local_notifications) that use Java 8+ APIs.
        // See: https://developer.android.com/studio/write/java8-support#library-desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hongirana.school"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ---------------- Release signing (Play Store) ----------------
    // We load signing details from android/key.properties.
    // Keep secrets OUT of git; see android/key.properties.example.
    // Important: we only enable release signing if ALL required fields are present
    // AND the keystore file exists, so a partially-filled key.properties won't
    // accidentally break local builds.
    val keyProperties = Properties()
    val keyPropertiesFile = rootProject.file("key.properties")
    val hasKeyPropsFile = keyPropertiesFile.exists()
    if (hasKeyPropsFile) {
        keyPropertiesFile.inputStream().use { keyProperties.load(it) }
    }

    val releaseStoreFilePath = (keyProperties["storeFile"] as String?)?.trim()
    val releaseStorePassword = (keyProperties["storePassword"] as String?)?.trim()
    val releaseKeyAlias = (keyProperties["keyAlias"] as String?)?.trim()
    val releaseKeyPassword = (keyProperties["keyPassword"] as String?)?.trim()
    val releaseStoreFile = if (releaseStoreFilePath.isNullOrEmpty()) null else file(releaseStoreFilePath)
    val hasReleaseSigning = hasKeyPropsFile &&
            (releaseStoreFile != null) &&
            releaseStoreFile.exists() &&
            !releaseStorePassword.isNullOrEmpty() &&
            !releaseKeyAlias.isNullOrEmpty() &&
            !releaseKeyPassword.isNullOrEmpty()

    signingConfigs {
        // Create a release signing config only if fully configured.
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // IMPORTANT:
            // - For Play Store, you MUST sign with your release keystore.
            // - For local/dev builds (no key.properties), we fall back to debug.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // For AGP 8.x this version is supported; newer versions exist, but keep this explicit and stable.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
