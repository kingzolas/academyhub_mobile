// [NOVO] Bloco buildscript para carregar o plugin do Google
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Esta linha adiciona o plugin do Google Services ao projeto
        classpath("com.google.gms:google-services:4.4.1")
    }
}

// --- O RESTANTE DO SEU ARQUIVO PERMANECE IGUAL ---
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}