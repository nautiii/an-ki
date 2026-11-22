package com.github.nautiii.an_ki

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds.Phone
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lien d'une personne à un numéro de son répertoire (P5), sans
 * `READ_CONTACTS` : le sélecteur du système montre le répertoire, AnKi ne
 * reçoit que le numéro choisi, par l'autorisation temporaire qu'Android
 * accorde sur cette seule ligne. Le composeur et l'app de SMS s'ouvrent par
 * des intents qui ne demandent aucune permission (`ACTION_DIAL` n'appelle pas
 * de lui-même). `flutter_contacts` ne rend le numéro choisi qu'avec
 * `READ_CONTACTS`, d'où ce canal.
 */
class PhoneContactChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler(this)
    }

    /** Réponse du sélecteur ouvert, en attente de son résultat. */
    private var pendingPick: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickPhone" -> pickPhone(result)
            "dial" -> {
                val number = call.argument<String>("number")
                    ?: return result.error("bad_args", "number is required", null)
                result.success(start(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null))))
            }
            "sendSms" -> {
                val number = call.argument<String>("number")
                    ?: return result.error("bad_args", "number is required", null)
                val intent = Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", number, null))
                    .putExtra("sms_body", call.argument<String>("body") ?: "")
                result.success(start(intent))
            }
            else -> result.notImplemented()
        }
    }

    private fun pickPhone(result: MethodChannel.Result) {
        if (pendingPick != null) {
            return result.error("busy", "A contact picker is already open", null)
        }
        val intent = Intent(Intent.ACTION_PICK).setType(Phone.CONTENT_TYPE)
        try {
            activity.startActivityForResult(intent, PICK_PHONE_REQUEST)
            pendingPick = result
        } catch (e: Exception) {
            // Aucun sélecteur, ou une activité qui refuse d'être lancée.
            result.error("unavailable", "No contact picker on this device", null)
        }
    }

    /**
     * Résultat d'une activité lancée par [MainActivity] ; vrai quand c'était
     * le sélecteur de ce canal.
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_PHONE_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        // Seul le répertoire est lu : AnKi déclare READ_CONTACTS pour l'import,
        // une URI d'ailleurs serait lue avec ses droits.
        if (uri.authority != ContactsContract.AUTHORITY) {
            result.error("unavailable", "The picker answered outside the contacts", null)
            return true
        }
        try {
            val phone = readPhone(uri)
            if (phone != null) {
                result.success(phone)
            } else {
                // Une ligne choisie mais sans numéro lisible : pas une annulation.
                result.error("unavailable", "The picked row has no number", null)
            }
        } catch (e: Exception) {
            // Autorisation temporaire absente, colonne inconnue d'un sélecteur
            // tiers : rien n'est lu.
            result.error("unavailable", "The picked contact can't be read", null)
        }
        return true
    }

    /** Numéro et nom du contact de la ligne choisie ; null si elle est vide. */
    private fun readPhone(uri: Uri): Map<String, String>? =
        activity.contentResolver
            .query(uri, arrayOf(Phone.NUMBER, Phone.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val number = cursor.getString(0)?.trim().orEmpty()
                if (number.isEmpty()) return@use null
                mapOf("number" to number, "name" to cursor.getString(1).orEmpty())
            }

    /** Ouvre [intent] ; faux quand aucune app ne le prend en charge. */
    private fun start(intent: Intent): Boolean =
        try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingPick?.success(null)
        pendingPick = null
    }

    private companion object {
        const val CHANNEL = "an_ki/phone_contact"
        const val PICK_PHONE_REQUEST = 0x5050
    }
}
