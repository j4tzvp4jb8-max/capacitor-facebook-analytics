import Foundation
import AppTrackingTransparency
import UIKit
import Capacitor
import FBSDKCoreKit

@objc(FacebookAnalyticsPlugin)
public class FacebookAnalyticsPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "FacebookAnalyticsPlugin"
    public let jsName = "FacebookAnalytics"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "initAppEvents", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "logEvent", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "logPurchase", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "enableAdvertiserTracking", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disableAdvertiserTracking", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getAdvertiserTrackingStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopAppEvents", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestTrackingAuthorization", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getTrackingAuthorizationStatus", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = FacebookAnalytics()

    /* GymIsLife fork (24 Oct 2026): consent-gated. Nothing in this plugin touches the Meta SDK until
       initAppEvents() - which the app calls only after an explicit, stored yes - and every logging call
       is refused until then, in this process. load() is not overridden, so registration has no side
       effects. Automatic logging is forced OFF here and on stop, because the SDK caches these switches
       in UserDefaults and the cache wins over Info.plist. */
    private var consented = false

    @objc func initAppEvents(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            Settings.shared.isAutoLogAppEventsEnabled = false
            Settings.shared.isAdvertiserIDCollectionEnabled = true
            ApplicationDelegate.shared.initializeSDK()
            AppEvents.shared.activateApp()
            self.consented = true
            call.resolve()
        }
    }

    /* Withdrawal. The iOS SDK cannot be un-initialised inside a running process, so this stops every
       further event from this plugin, switches advertiser-ID collection and (iOS 15-16) advertiser
       tracking off, and leaves auto-logging off. On the next launch the app does not call
       initAppEvents(), so the SDK is never initialised again. */
    @objc func stopAppEvents(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.consented = false
            Settings.shared.isAutoLogAppEventsEnabled = false
            Settings.shared.isAdvertiserIDCollectionEnabled = false
            self.setAdvertiserTrackingEnabled(false)
            call.resolve()
        }
    }

    /* Apple's App Tracking Transparency prompt. Apple shows it only while the app is ACTIVE, so this
       waits for that rather than resolving "notDetermined" from the background. Never initialises the
       Meta SDK itself. */
    @objc func requestTrackingAuthorization(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let ask = {
                ATTrackingManager.requestTrackingAuthorization { status in
                    call.resolve(["status": Self.trackingStatusName(status)])
                }
            }
            if UIApplication.shared.applicationState == .active {
                ask()
                return
            }
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                if let observer = token { NotificationCenter.default.removeObserver(observer) }
                ask()
            }
        }
    }

    @objc func getTrackingAuthorizationStatus(_ call: CAPPluginCall) {
        call.resolve(["status": Self.trackingStatusName(ATTrackingManager.trackingAuthorizationStatus)])
    }

    private static func trackingStatusName(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "denied"
        }
    }

    @objc func logEvent(_ call: CAPPluginCall) {
        guard consented else {
            call.reject("App Events are not started (no consent in this session)")
            return
        }
        guard let event = call.getString("event"), !event.isEmpty else {
            call.reject("Must provide an event")
            return
        }

        let currency = call.getString("currency")

        if let currency = currency, currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            call.reject("Currency must not be empty")
            return
        }

        let parameters = buildParameters(call.getObject("params"), currency: currency)
        let eventName = AppEvents.Name(rawValue: event)

        if let valueToSum = call.getDouble("valueToSum") {
            AppEvents.shared.logEvent(eventName, valueToSum: valueToSum, parameters: parameters)
        } else if let parameters = parameters {
            AppEvents.shared.logEvent(eventName, parameters: parameters)
        } else {
            AppEvents.shared.logEvent(eventName)
        }

        call.resolve()
    }

    @objc func logPurchase(_ call: CAPPluginCall) {
        guard consented else {
            call.reject("App Events are not started (no consent in this session)")
            return
        }
        guard let amount = call.getDouble("amount") else {
            call.reject("Must provide an amount")
            return
        }

        guard let currency = call.getString("currency"), !currency.isEmpty else {
            call.reject("Must provide a currency")
            return
        }

        AppEvents.shared.logPurchase(amount: amount, currency: currency, parameters: buildParameters(call.getObject("params")))
        call.resolve()
    }

    @objc func enableAdvertiserTracking(_ call: CAPPluginCall) {
        guard consented else {
            call.reject("App Events are not started (no consent in this session)")
            return
        }
        setAdvertiserTrackingEnabled(true)
        call.resolve()
    }

    @objc func disableAdvertiserTracking(_ call: CAPPluginCall) {
        setAdvertiserTrackingEnabled(false)
        call.resolve()
    }

    @objc func getAdvertiserTrackingStatus(_ call: CAPPluginCall) {
        call.resolve([
            "status": getAdvertiserTrackingStatus()
        ])
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve([
            "version": implementation.getPluginVersion()
        ])
    }

    private func setAdvertiserTrackingEnabled(_ enabled: Bool) {
        if #available(iOS 17.0, *) {
            return
        }

        applyLegacyAdvertiserTrackingEnabled(enabled)
    }

    @available(iOS, obsoleted: 17.0)
    private func applyLegacyAdvertiserTrackingEnabled(_ enabled: Bool) {
        Settings.shared.isAdvertiserTrackingEnabled = enabled
    }

    private func getAdvertiserTrackingStatus() -> Bool {
        if #available(iOS 17.0, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .authorized
        }

        return Settings.shared.isAdvertiserTrackingEnabled
    }

    private func buildParameters(_ params: [String: Any]?, currency: String? = nil) -> [AppEvents.ParameterName: Any]? {
        var parameters: [AppEvents.ParameterName: Any] = [:]

        params?.forEach { key, value in
            if value is NSNull {
                return
            }

            if let boolValue = value as? Bool {
                parameters[AppEvents.ParameterName(rawValue: key)] = boolValue ? "1" : "0"
                return
            }

            if value is String || value is NSNumber {
                parameters[AppEvents.ParameterName(rawValue: key)] = value
            } else {
                parameters[AppEvents.ParameterName(rawValue: key)] = String(describing: value)
            }
        }

        if let currency = currency {
            parameters[AppEvents.ParameterName(rawValue: "fb_currency")] = currency
        }

        return parameters.isEmpty ? nil : parameters
    }
}
