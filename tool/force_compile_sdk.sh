#!/usr/bin/env bash
# Appends a compileSdk override for all Android plugin subprojects.
set -e
if [ -f android/build.gradle.kts ]; then
  cat >> android/build.gradle.kts <<'KTS'

subprojects {
    if (name != "app") {
        afterEvaluate {
            val ext = extensions.findByName("android")
            if (ext != null) {
                try {
                    ext.javaClass.methods.first {
                        it.name == "compileSdkVersion" && it.parameterTypes.size == 1 &&
                            it.parameterTypes[0] == Int::class.javaPrimitiveType
                    }.invoke(ext, 36)
                } catch (e: Exception) {
                    println("compileSdk override skipped for $name: $e")
                }
            }
        }
    }
}
KTS
else
  cat >> android/build.gradle <<'GRADLE'

subprojects {
    if (project.name != 'app') {
        afterEvaluate { p ->
            if (p.hasProperty('android')) { p.android.compileSdkVersion 36 }
        }
    }
}
GRADLE
fi
