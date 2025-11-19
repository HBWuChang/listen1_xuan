allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    afterEvaluate {
        if (
            project.plugins.hasPlugin("com.android.application") ||
            project.plugins.hasPlugin("com.android.library")
        ) {
            project.extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
                buildToolsVersion = "36.0.0"

                defaultConfig {
                    minSdk = 24
                    targetSdk = 36
                }

                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

allprojects {
    tasks.withType<JavaCompile> {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
}
