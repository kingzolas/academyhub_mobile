plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.academyhub_mobile"
    compileSdk = flutter.compileSdkVersion
    
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        
        // [NOVO] ADICIONE ESTA LINHA:
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.academyhub_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // [OPCIONAL] Se der erro de multidex depois, descomente a linha abaixo:
        // multiDexEnabled = true 
    }
    // 👇 ADICIONE ESTE BLOCO AQUI 👇
   lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
    // 👆 FIM DO BLOCO 👆

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false 
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Importa o Firebase BoM (que você já tinha)
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    
    // [ATUALIZAÇÃO] Mude de 2.0.4 para 2.1.4 aqui:
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}