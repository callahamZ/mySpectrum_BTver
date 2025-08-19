// Top-level build file where you can add configuration options common to all sub-projects/modules.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = project.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            project.extensions.getByType<com.android.build.gradle.BaseExtension>().compileSdkVersion(34)
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}