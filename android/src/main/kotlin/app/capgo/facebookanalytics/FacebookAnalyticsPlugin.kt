package app.capgo.facebookanalytics

import android.app.Application
import android.os.Bundle
import com.facebook.FacebookException
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsConstants
import com.facebook.appevents.AppEventsLogger
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import java.math.BigDecimal
import java.util.Currency
import org.json.JSONObject

@CapacitorPlugin(name = "FacebookAnalytics")
class FacebookAnalyticsPlugin : Plugin() {

    private val implementation = FacebookAnalytics()
    private lateinit var logger: AppEventsLogger

    /* GymIsLife fork (24 Oct 2026): consent-gated. Every logging call is refused until initAppEvents()
       has run in this process, and the app calls that only after an explicit, stored yes. The SDK caches
       these switches on the device and the cache wins over the manifest, so they are set explicitly here
       and on stop rather than left to AndroidManifest defaults. */
    @Volatile private var consented = false

    private fun refuseWithoutConsent(call: PluginCall): Boolean {
        if (consented) return false
        call.reject("App Events are not started (no consent in this session)")
        return true
    }

    override fun load() {
        // Keep Capacitor registration side-effect free until Meta SDK metadata is configured.
    }

    @PluginMethod
    fun initAppEvents(call: PluginCall) {
        val application = context.applicationContext as? Application

        if (application == null) {
            call.reject("Unable to resolve Android application context")
            return
        }

        try {
            @Suppress("DEPRECATION")
            FacebookSdk.sdkInitialize(
                application,
                object : FacebookSdk.InitializeCallback {
                    override fun onInitialized() {
                        try {
                            FacebookSdk.setAutoLogAppEventsEnabled(false)
                            FacebookSdk.setAutoLogMetaDataEnabled(false)
                            FacebookSdk.setAutoLogProductImprovementEnabled(false)
                            FacebookSdk.setMonitorEnabled(false)
                            FacebookSdk.setAdvertiserIDCollectionEnabled(true)
                            FacebookSdk.setAutoInitEnabled(true)
                            FacebookSdk.fullyInitialize()
                            AppEventsLogger.activateApp(application)
                            consented = true
                            call.resolve()
                        } catch (error: FacebookException) {
                            call.reject(error.message ?: "Failed to activate Facebook App Events")
                        }
                    }
                },
            )
        } catch (error: FacebookException) {
            call.reject(error.message ?: "Failed to activate Facebook App Events")
        }
    }

    /* Withdrawal: no further events from this plugin, and auto-init, auto-logging and advertiser-ID
       collection all written back to false in the SDK's on-device cache, so the next launch does not
       initialise the SDK either. */
    @PluginMethod
    fun stopAppEvents(call: PluginCall) {
        consented = false
        try {
            FacebookSdk.setAutoInitEnabled(false)
            FacebookSdk.setAutoLogAppEventsEnabled(false)
            FacebookSdk.setAutoLogMetaDataEnabled(false)
            FacebookSdk.setAutoLogProductImprovementEnabled(false)
            FacebookSdk.setMonitorEnabled(false)
            FacebookSdk.setAdvertiserIDCollectionEnabled(false)
        } catch (error: Exception) {
            // The SDK was never initialised in this process: nothing is running, and the cache was
            // never switched on by this plugin. Still a successful withdrawal.
        }
        call.resolve()
    }

    @PluginMethod
    fun logEvent(call: PluginCall) {
        if (refuseWithoutConsent(call)) return
        val event = call.getString("event")

        if (event.isNullOrBlank()) {
            call.reject("Must provide an event")
            return
        }

        try {
            val currency = call.getString("currency")

            if (currency != null && currency.isBlank()) {
                call.reject("Currency must not be empty")
                return
            }

            val parameters = buildParameters(call.getObject("params", null), currency)
            val valueToSum = call.getDouble("valueToSum")
            val eventsLogger = getLogger()

            when {
                valueToSum != null && parameters.size() > 0 -> eventsLogger.logEvent(event, valueToSum, parameters)
                valueToSum != null -> eventsLogger.logEvent(event, valueToSum)
                parameters.size() > 0 -> eventsLogger.logEvent(event, parameters)
                else -> eventsLogger.logEvent(event)
            }

            call.resolve()
        } catch (error: FacebookException) {
            call.reject(error.message ?: "Failed to log Facebook event")
        }
    }

    @PluginMethod
    fun logPurchase(call: PluginCall) {
        if (refuseWithoutConsent(call)) return
        val amount = call.getDouble("amount")
        val currencyCode = call.getString("currency")

        if (amount == null) {
            call.reject("Must provide an amount")
            return
        }

        if (currencyCode.isNullOrBlank()) {
            call.reject("Must provide a currency")
            return
        }

        val currency = try {
            Currency.getInstance(currencyCode)
        } catch (error: IllegalArgumentException) {
            call.reject("Invalid currency code: $currencyCode")
            return
        }

        try {
            val parameters = buildParameters(call.getObject("params", null))
            val eventsLogger = getLogger()

            if (parameters.size() > 0) {
                eventsLogger.logPurchase(BigDecimal.valueOf(amount), currency, parameters)
            } else {
                eventsLogger.logPurchase(BigDecimal.valueOf(amount), currency)
            }

            call.resolve()
        } catch (error: FacebookException) {
            call.reject(error.message ?: "Failed to log Facebook purchase")
        }
    }

    @PluginMethod
    fun enableAdvertiserTracking(call: PluginCall) {
        if (refuseWithoutConsent(call)) return
        FacebookSdk.setAdvertiserIDCollectionEnabled(true)
        call.resolve()
    }

    @PluginMethod
    fun disableAdvertiserTracking(call: PluginCall) {
        FacebookSdk.setAdvertiserIDCollectionEnabled(false)
        call.resolve()
    }

    @PluginMethod
    fun getAdvertiserTrackingStatus(call: PluginCall) {
        val ret = JSObject().apply {
            put("status", FacebookSdk.getAdvertiserIDCollectionEnabled())
        }

        call.resolve(ret)
    }

    @PluginMethod
    fun getPluginVersion(call: PluginCall) {
        val ret = JSObject().apply {
            put("version", implementation.getPluginVersion())
        }
        call.resolve(ret)
    }

    private fun getLogger(): AppEventsLogger {
        if (!::logger.isInitialized) {
            logger = AppEventsLogger.newLogger(context)
        }

        return logger
    }

    private fun buildParameters(params: JSObject?, currency: String? = null): Bundle {
        val bundle = Bundle()

        params?.keys()?.forEach { key ->
            when (val value = params.opt(key)) {
                null, JSONObject.NULL -> Unit
                is Boolean -> bundle.putString(key, if (value) "1" else "0")
                is String -> bundle.putString(key, value)
                is Int -> bundle.putInt(key, value)
                is Long -> bundle.putLong(key, value)
                is Float -> bundle.putFloat(key, value)
                is Double -> bundle.putDouble(key, value)
                is Number -> bundle.putDouble(key, value.toDouble())
                else -> bundle.putString(key, value.toString())
            }
        }

        if (!currency.isNullOrBlank()) {
            bundle.putString(AppEventsConstants.EVENT_PARAM_CURRENCY, currency)
        }

        return bundle
    }
}
