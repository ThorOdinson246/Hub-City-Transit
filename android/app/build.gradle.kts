plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.mukeshpoudel.hctransit"
    // Pinned deliberately. Reading these from the Flutter SDK made the API level
    // the app declares to Play a property of whichever Flutter version happened
    // to be installed on the build machine, with nothing in git to explain a
    // rejection. Google Play requires new apps to target API 36 from
    // 2026-08-31. Changing these is a reviewed commit, not an ambient effect.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mukeshpoudel.hctransit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Belongs to `android`, not inside `buildTypes`. It resolved there by Kotlin
    // DSL scoping, but it read as if signing were a property of the build type.
    if (keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Fail loudly. This previously fell back to the debug signing config,
            // so a missing key.properties produced a minified, shrunk,
            // debug-signed AAB and exited 0 — indistinguishable from a real
            // release until Play rejected the upload, and non-deterministic on CI
            // where the debug keystore is regenerated per runner.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (project.hasProperty("allowUnsignedRelease")) {
                logger.warn("key.properties missing — producing an UNSIGNED release build. Not uploadable to Play.")
                null
            } else {
                throw GradleException(
                    "key.properties not found. A release build must be signed with the upload key. " +
                    "Pass -PallowUnsignedRelease to build an unsigned artifact deliberately."
                )
            }

            ndk {
                // Play warns on every upload without these, and any native crash
                // in libflutter.so is otherwise unsymbolicated.
                debugSymbolLevel = "FULL"
            }
        }
    }
}

flutter {
    source = "../.."
}
