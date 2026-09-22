allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some older plugins (e.g. vosk_flutter 0.3.46) predate AGP's mandatory
// `namespace` declaration and only set the legacy `package` attribute in
// their AndroidManifest.xml, which AGP 9.x no longer falls back to — that
// fails the build with "Namespace not specified". Backfill it here from
// each such subproject's own manifest, using reflection (getNamespace/
// setNamespace) rather than an AGP type import, since this root script
// doesn't itself apply the Android plugin. No-op for any subproject that
// already declares a namespace.
//
// Registered before evaluationDependsOn(":app") below, which forces early
// evaluation of ":app" — afterEvaluate can't be registered on a project
// that's already evaluated, so this block must run first.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val extClass = androidExt.javaClass
        val getNamespace = extClass.methods.find { it.name == "getNamespace" && it.parameterCount == 0 }
        val setNamespace = extClass.methods.find { it.name == "setNamespace" && it.parameterCount == 1 }
        if (getNamespace == null || setNamespace == null) return@afterEvaluate
        if (getNamespace.invoke(androidExt) != null) return@afterEvaluate

        val manifestFile = file("src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) return@afterEvaluate
        val packageName = Regex("package\\s*=\\s*\"([^\"]+)\"")
            .find(manifestFile.readText())
            ?.groupValues
            ?.get(1)
        if (packageName != null) {
            setNamespace.invoke(androidExt, packageName)
            logger.lifecycle("Backfilled namespace '$packageName' for subproject '${project.name}' (no namespace in its build.gradle).")
        }
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


