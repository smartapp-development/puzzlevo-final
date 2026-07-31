plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smartappdevelopment01.puzzlevo"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = "puzzlevo"
            keyPassword = "puzzlevo123"
            storeFile = file("keystore.jks")
            storePassword = "puzzlevo123"
        }
    }

    defaultConfig {
        applicationId = "com.smartappdevelopment01.puzzlevo"
        minSdk = 24
        targetSdk = 36
        versionCode = 25
        versionName = "2.0.6"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}