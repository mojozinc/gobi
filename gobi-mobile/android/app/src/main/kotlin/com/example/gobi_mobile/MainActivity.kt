package com.example.gobi_mobile

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            val dataDir = applicationContext.dataDir
            File(dataDir, "app_flutter").mkdirs()
            File(dataDir, "files").mkdirs()
            File(dataDir, "cache").mkdirs()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onCreate(savedInstanceState)
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }
}
