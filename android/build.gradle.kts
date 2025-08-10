allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Put all build outputs in <project>/build (1 level above android/)
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val subBuild = newBuildDir.dir(name)
    layout.buildDirectory.set(subBuild)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
