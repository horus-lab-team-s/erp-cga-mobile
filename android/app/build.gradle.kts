import java.util.Properties

/**
 * La clé de signature du cabinet, quand elle est posée sur le poste.
 *
 * ⚠️ ANDROID REFUSE D'INSTALLER UNE MISE À JOUR SIGNÉE AUTREMENT QUE LA
 * VERSION EN PLACE. Le gabarit de Flutter laissait la version livrée signée
 * avec la clé de DÉBOGAGE — une clé générée par l'outil, différente sur chaque
 * poste. Publiée telle quelle, la première mise à jour aurait obligé chaque
 * adhérent à désinstaller puis réinstaller, en perdant sa session.
 *
 * ⚠️ LA CLÉ N'EST PAS DANS LE DÉPÔT, ET NE DOIT JAMAIS Y ÊTRE. Elle se pose
 * dans `android/key.properties`, ignoré par git. Le fichier absent, on retombe
 * sur la clé de débogage AVEC UN AVERTISSEMENT ÉCRIT : construire pour essayer
 * reste possible, publier sans s'en apercevoir ne l'est plus.
 */
val proprietesDeSignature = Properties().apply {
    val fichier = rootProject.file("key.properties")
    if (fichier.exists()) fichier.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "cm.cgabrcg.cga_mobile"
    compileSdk = flutter.compileSdkVersion
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
        applicationId = "cm.cgabrcg.cga_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("cabinet") {
            // ⚠️ Lu depuis `key.properties`, jamais écrit ici : un mot de passe
            // de clé dans le dépôt est un mot de passe public.
            keyAlias = proprietesDeSignature.getProperty("keyAlias")
            keyPassword = proprietesDeSignature.getProperty("keyPassword")
            storeFile = proprietesDeSignature.getProperty("storeFile")?.let { file(it) }
            storePassword = proprietesDeSignature.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = if (proprietesDeSignature.getProperty("storeFile") != null) {
                signingConfigs.getByName("cabinet")
            } else {
                logger.warn(
                    "⚠️  CGA : `android/key.properties` absent — la version livrée est " +
                        "signée avec la CLÉ DE DÉBOGAGE. Bon pour essayer sur un " +
                        "téléphone, JAMAIS pour publier."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
