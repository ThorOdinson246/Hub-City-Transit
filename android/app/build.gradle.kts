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
    // Pinned, not read from the Flutter SDK: otherwise the API level we declare
    // to Play depends on whoever's laptop built it. Play needs 36 from 2026-08-31.
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

    // Belongs here, not in buildTypes — it resolved there by DSL scoping but read
    // as if signing were a property of the build type.
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
            // Used to fall back to debug signing and exit 0, so you only found out
            // when Play rejected the upload.
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
                // Without these, native crashes come back unsymbolicated.
                debugSymbolLevel = "FULL"
            }
        }
    }
}

flutter {
    source = "../.."
}
