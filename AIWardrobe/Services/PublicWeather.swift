import CoreLocation
import WeatherKit
import Observation

@MainActor @Observable
final class PublicWeather: NSObject, @preconcurrency CLLocationManagerDelegate {
    var celsius: Double?
    var label = L("weatherPrompt")
    var symbol = "cloud.sun"
    var loading = false
    var attributionURL: URL?
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeout: Task<Void, Never>?
    var temperature: String {
        guard let celsius else { return "—" }
        return Self.formattedTemperature(celsius, locale: .current)
    }
    static func formattedTemperature(_ celsius: Double, locale: Locale) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius).formatted(
            .measurement(width: .abbreviated, usage: .weather,
                         numberFormatStyle: .number.precision(.fractionLength(1))).locale(locale)
        )
    }
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers }
    func refresh() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        let location = await withCheckedContinuation { continuation in
            self.continuation = continuation
            // Install the deadline before a synchronous denial can call finish.
            timeout?.cancel()
            timeout = Task { try? await Task.sleep(for: .seconds(20)); if !Task.isCancelled { self.finish(nil) } }
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            default: finish(nil)
            }
        }
        guard let location else { label = L("weatherUnavailable"); celsius = nil; symbol = "cloud"; return }
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            celsius = current.temperature.converted(to: .celsius).value
            label = current.condition.description; symbol = current.symbolName
            attributionURL = try await WeatherService.shared.attribution.legalPageURL
        } catch { label = L("weatherUnavailable"); celsius = nil }
    }
    private func finish(_ location: CLLocation?) {
        timeout?.cancel(); continuation?.resume(returning: location); continuation = nil
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        else if manager.authorizationStatus != .notDetermined { finish(nil) }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { finish(locations.last) }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }
}
