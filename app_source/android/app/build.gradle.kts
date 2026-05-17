plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.rice_quality_scanner"
    compileSdk = 36
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    aaptOptions {
        noCompress += listOf("tflite", "lite")
    }

    defaultConfig {
        applicationId = "com.example.rice_quality_scanner"
        minSdk = 28
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")

            ndk {
                debugSymbolLevel = "NONE"
            }
        }
    }
}

configurations.all {
    resolutionStrategy {
        force("org.tensorflow:tensorflow-lite:2.14.0")
        force("org.tensorflow:tensorflow-lite-api:2.14.0")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // No direct TFLite dependencies needed here
}