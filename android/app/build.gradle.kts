plugins {
    id("com.android.application")
    // START: FlutterFire Configuration (giữ nếu dùng Firebase)
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")  // Tên chính thức thay vì "kotlin-android"
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.huyphan_app"

    compileSdk = flutter.compileSdkVersion  // Đúng cú pháp Kotlin DSL
    ndkVersion = "27.0.12077973"  // Giữ giá trị bạn set (hoặc flutter.ndkVersion nếu muốn dynamic)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true  // ← BẮT BUỘC thêm dòng này để bật desugaring (bạn thiếu trước đó)
    }

    // kotlinOptions bị deprecated ở Kotlin 2.0+ → migrate sang compilerOptions
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    // Cách thay thế nếu muốn giữ kotlinOptions tạm (vẫn hoạt động nhưng sẽ warning):
    // kotlinOptions {
    //     jvmTarget = "17"
    // }

    defaultConfig {
        applicationId = "com.example.huyphan_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for release
            signingConfig = signingConfigs.getByName("debug")  // tạm dùng debug
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")  // Phiên bản ổn định, hỗ trợ Java 17 tốt
    // Nếu muốn version mới hơn (nếu AGP >=8.5): "2.1.2" hoặc "2.0.3" tùy test
}