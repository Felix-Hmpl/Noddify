pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "noddify-android"

// core: the session format, storage and stats as plain Kotlin, tested on the JVM.
// app: the Android app with the Connect IQ link and the screens.
include(":core", ":app")
