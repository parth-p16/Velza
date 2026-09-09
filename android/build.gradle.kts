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

subprojects {
    val configureProject = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            for (method in android.javaClass.methods) {
                if (method.name == "compileSdkVersion" || method.name == "setCompileSdkVersion" || method.name == "setCompileSdk") {
                    try {
                        if (method.parameterTypes.size == 1) {
                            val paramType = method.parameterTypes[0]
                            if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                                method.invoke(android, 36)
                            }
                        }
                    } catch (_: Throwable) {
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        configureProject()
    } else {
        project.afterEvaluate {
            configureProject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
