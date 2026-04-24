import com.android.build.api.dsl.CommonExtension

val minAndroidCompileSdk = 34

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        if (!plugins.hasPlugin("com.android.application") && !plugins.hasPlugin("com.android.library")) {
            return@afterEvaluate
        }

        extensions.configure<CommonExtension<*, *, *, *, *, *>>("android") {
            compileSdk = maxOf(compileSdk ?: 0, minAndroidCompileSdk)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
