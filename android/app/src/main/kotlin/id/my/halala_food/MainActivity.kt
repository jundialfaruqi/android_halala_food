package id.my.halala_food

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.halala.food/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDevModeEnabled" -> {
                    result.success(checkDevMode())
                }
                "isMockLocationEnabled" -> {
                    result.success(checkMockLocation())
                }
                "killApp" -> {
                    killApplication()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkDevMode(): Boolean {
        return try {
            val devOptions = Settings.Global.getInt(
                contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            )
            val adb = Settings.Global.getInt(
                contentResolver,
                Settings.Global.ADB_ENABLED,
                0
            )
            devOptions != 0 || adb != 0
        } catch (e: Exception) {
            false
        }
    }

    private fun checkMockLocation(): Boolean {
        try {
            val mockLocationSetting = Settings.Secure.getString(
                contentResolver,
                "mock_location"
            )
            if (mockLocationSetting != null && mockLocationSetting != "0") {
                return true
            }
        } catch (_: Exception) {}

        try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            if (locationManager != null) {
                val providers = locationManager.getProviders(true)
                for (provider in providers) {
                    val location: Location = locationManager.getLastKnownLocation(provider) ?: continue
                    val isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        location.isMock
                    } else {
                        @Suppress("DEPRECATION")
                        location.isFromMockProvider
                    }
                    if (isMock) {
                        return true
                    }
                }
            }
        } catch (_: Exception) {}

        return false
    }

    private fun killApplication() {
        try {
            finishAffinity()
            Process.killProcess(Process.myPid())
            exitProcess(0)
        } catch (e: Exception) {
            exitProcess(0)
        }
    }
}
