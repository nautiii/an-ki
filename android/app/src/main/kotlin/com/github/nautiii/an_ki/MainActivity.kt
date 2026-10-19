package com.github.nautiii.an_ki

import android.Manifest
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // flutter_local_notifications ne dit pas si Android peut encore
        // afficher sa boîte de permission après un refus : sans elle, seuls
        // les réglages de l'app accordent les notifications
        // (NotificationService.requestAccess).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_PERMISSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canAskAgain" -> result.success(canAskAgainForNotifications())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Vrai quand Android reproposera sa boîte de permission : un seul refus
     * jusqu'ici. Faux après deux refus, et avant Android 13, où les
     * notifications ne se demandent pas (elles se coupent dans les réglages).
     */
    private fun canAskAgainForNotifications(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)

    private companion object {
        const val NOTIFICATION_PERMISSION_CHANNEL = "an_ki/notification_permission"
    }
}
