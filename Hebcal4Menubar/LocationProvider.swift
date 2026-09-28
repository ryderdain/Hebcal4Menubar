//
//  LocationProvider.swift
//  Hebcal4Menubar
//
//  Where the sunset is computed for. Primary: the Mac's current location
//  (Core Location, city-level accuracy), with its time zone and name from
//  reverse geocoding. Fallback: a place you choose (default Munich), used
//  when the current location is off, not permitted or not known yet.
//

import CoreLocation
import Foundation

/// A named place with the time zone the Zmanim API needs.
struct Place: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var tzid: String

    static let munich = Place(name: "Munich", latitude: 48.1374, longitude: 11.5755,
                              tzid: "Europe/Berlin")

    var location: Location { Location(latitude: latitude, longitude: longitude, tzid: tzid) }

    /// Identity for caches: a sunset fetched for one place is not valid for another.
    var cacheKey: String { String(format: "%.3f,%.3f,%@", latitude, longitude, tzid) }
}

enum PlaceSource { case current, fallback }

enum PlaceInputError: LocalizedError {
    case empty, notFound(String), badCoordinates, noTimeZone, badTimeZone(String)

    var errorDescription: String? {
        switch self {
        case .empty:               return "Enter a city, or coordinates as “lat, lon”."
        case .notFound(let q):     return "No place found for “\(q)”."
        case .badCoordinates:      return "Latitude must be −90…90 and longitude −180…180."
        case .noTimeZone:          return "No time zone found for these coordinates. Add one: “lat, lon, Europe/Berlin”."
        case .badTimeZone(let tz): return "Unknown time zone “\(tz)”. Use an IANA name, for example Europe/Berlin."
        }
    }
}

final class LocationProvider: NSObject, CLLocationManagerDelegate {

    /// Called on the main thread whenever the effective place or status changes.
    var onChange: (() -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastRequest: Date?
    private var lastError: String?

    private enum Keys {
        static let useCurrent = "location.useCurrent"
        static let fallback = "location.fallback"
        static let current = "location.lastCurrent"
    }

    /// Use the Mac's current location when permitted (default on).
    var useCurrent: Bool {
        get { UserDefaults.standard.object(forKey: Keys.useCurrent) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.useCurrent)
            if newValue { requestIfPossible(force: true) }
            notify()
        }
    }

    /// The place used when the current location is not available.
    var fallback: Place {
        get { load(Keys.fallback) ?? .munich }
        set { save(newValue, Keys.fallback); notify() }
    }

    /// Last current location found (kept across launches, so offline works).
    private(set) var current: Place? {
        get { load(Keys.current) }
        set { save(newValue, Keys.current) }
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return true
        default: return false
        }
    }

    /// The place to use now, and where it came from.
    var effective: (place: Place, source: PlaceSource) {
        if useCurrent, isAuthorized, let c = current { return (c, .current) }
        return (fallback, .fallback)
    }

    /// One line for the menu that says which place is in use and why.
    var statusLine: String {
        let (place, source) = effective
        if source == .current { return "Location: \(place.name) (current)" }
        guard useCurrent else { return "Location: \(place.name) (fallback; current location off)" }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return "Location: \(place.name) (fallback; Location Services not allowed)"
        case .notDetermined:
            return "Location: \(place.name) (fallback; waiting for permission)"
        default:
            if let e = lastError { return "Location: \(place.name) (fallback; \(e))" }
            return "Location: \(place.name) (fallback; finding current location…)"
        }
    }

    var needsSystemSettings: Bool {
        useCurrent && [.denied, .restricted].contains(manager.authorizationStatus)
    }

    // MARK: Lifecycle

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer   // sunset needs a city, not a street
        requestIfPossible(force: true)
    }

    /// Ask for a new fix if the last request is older than `maxAge` seconds.
    func refreshIfStale(maxAge: TimeInterval = 3600) {
        if let last = lastRequest, Date().timeIntervalSince(last) < maxAge { return }
        requestIfPossible(force: false)
    }

    private func requestIfPossible(force: Bool) {
        guard useCurrent else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            lastRequest = Date()
            manager.requestLocation()
        default:
            break
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestIfPossible(force: true)
        notify()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // Skip the reverse geocoding when we have not moved more than 1 km.
        if let c = current,
           CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: loc) < 1000 {
            lastError = nil
            notify()
            return
        }
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self else { return }
            let pm = placemarks?.first
            // Without geocoding (offline), the Mac's own zone is the best guess
            // for where the Mac is right now.
            let tz = pm?.timeZone?.identifier ?? TimeZone.current.identifier
            let name = pm?.locality ?? pm?.name
                ?? String(format: "%.2f, %.2f", loc.coordinate.latitude, loc.coordinate.longitude)
            self.current = Place(name: name, latitude: loc.coordinate.latitude,
                                 longitude: loc.coordinate.longitude, tzid: tz)
            self.lastError = nil
            self.notify()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let e = error as? CLError, e.code == .locationUnknown {
            lastError = "no location fix yet"
        } else {
            lastError = error.localizedDescription
        }
        notify()
    }

    // MARK: Manual fallback entry

    /// Resolve user input into a Place. Accepts a city or address, "lat, lon",
    /// or "lat, lon, Area/City" (an IANA time zone).
    static func resolve(_ input: String, geocoder: CLGeocoder = CLGeocoder(),
                        completion: @escaping (Result<Place, Error>) -> Void) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return completion(.failure(PlaceInputError.empty)) }

        let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2, let lat = Double(parts[0]), let lon = Double(parts[1]) {
            guard (-90...90).contains(lat), (-180...180).contains(lon) else {
                return completion(.failure(PlaceInputError.badCoordinates))
            }
            if parts.count >= 3 {
                let tz = parts[2]
                guard TimeZone(identifier: tz) != nil else {
                    return completion(.failure(PlaceInputError.badTimeZone(tz)))
                }
                let name = String(format: "%.2f, %.2f", lat, lon)
                return completion(.success(Place(name: name, latitude: lat, longitude: lon, tzid: tz)))
            }
            geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)) { pms, _ in
                guard let pm = pms?.first, let tz = pm.timeZone?.identifier else {
                    return completion(.failure(PlaceInputError.noTimeZone))
                }
                let name = pm.locality ?? pm.name ?? String(format: "%.2f, %.2f", lat, lon)
                completion(.success(Place(name: name, latitude: lat, longitude: lon, tzid: tz)))
            }
            return
        }

        geocoder.geocodeAddressString(text) { pms, _ in
            guard let pm = pms?.first, let loc = pm.location else {
                return completion(.failure(PlaceInputError.notFound(text)))
            }
            guard let tz = pm.timeZone?.identifier else {
                return completion(.failure(PlaceInputError.noTimeZone))
            }
            let name = pm.locality ?? pm.name ?? text
            completion(.success(Place(name: name, latitude: loc.coordinate.latitude,
                                      longitude: loc.coordinate.longitude, tzid: tz)))
        }
    }

    // MARK: Persistence

    private func load(_ key: String) -> Place? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Place.self, from: data)
    }

    private func save(_ place: Place?, _ key: String) {
        if let place, let data = try? JSONEncoder().encode(place) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func notify() {
        if Thread.isMainThread { onChange?() } else { DispatchQueue.main.async { self.onChange?() } }
    }
}
