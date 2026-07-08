plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.music"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        create("release") {
            keyAlias = System.getenv("CM_KEY_ALIAS") ?: "444music"
            keyPassword = System.getenv("CM_KEY_PASSWORD") ?: "Music112@"
            storeFile = System.getenv("CM_KEYSTORE_PATH")?.let { file(it) } ?: file("key.jks")
            storePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: "Music112@"
        }
    }

    defaultConfig {
        applicationId = "com.app444music.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
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

subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.ApplicationExtension::class.java)?.apply {
            compileSdk = 36
            defaultConfig.minSdk = 21
        }
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.apply {
            compileSdk = 36
            defaultConfig.minSdk = 21
        }
    }
}
