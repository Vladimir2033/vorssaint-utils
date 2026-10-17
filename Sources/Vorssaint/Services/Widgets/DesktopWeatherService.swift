// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Fetches the weather card's forecasts from Open-Meteo while the card is on:
/// at once, then every 30 minutes, one request per city with nothing but its
/// coordinates and the unit. A failed fetch keeps the last forecast, which
/// the card shows with its time, rather than an empty card.
@MainActor
final class DesktopWeatherService: ObservableObject {
    static let shared = DesktopWeatherService()

    @Published private(set) var reports: [String: WeatherReport] = [:]
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private init() {}

    var cities: [WeatherCity] {
        DesktopWeather.decodeCities(UserDefaults.standard.stringArray(forKey: DefaultsKey.desktopWidgetWeatherCities))
    }

    func setCities(_ cities: [WeatherCity]) {
        UserDefaults.standard.set(DesktopWeather.encodeCities(cities), forKey: DefaultsKey.desktopWidgetWeatherCities)
        let kept = Set(cities.map(\.id))
        reports = reports.filter { kept.contains($0.key) }
        if timer != nil { refresh() }
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: DesktopWeather.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
    }

    private var fahrenheit: Bool {
        UserDefaults.standard.string(forKey: DefaultsKey.temperatureUnit) == TemperatureUnit.fahrenheit.rawValue
    }

    func refresh() {
        task?.cancel()
        let cities = self.cities
        let fahrenheit = self.fahrenheit
        let session = self.session
        task = Task { [weak self] in
            for city in cities {
                guard !Task.isCancelled, let url = DesktopWeather.forecastURL(for: city, fahrenheit: fahrenheit),
                      let reply = try? await session.data(from: url),
                      (reply.1 as? HTTPURLResponse)?.statusCode == 200,
                      let report = DesktopWeather.report(fromForecast: reply.0, fetchedAt: Date()) else { continue }
                self?.reports[city.id] = report
            }
        }
    }

    /// The cities Open-Meteo knows by that name, for the picker in Settings.
    func search(_ query: String, language: String) async -> [WeatherCity] {
        guard let url = DesktopWeather.searchURL(for: query, language: language),
              let reply = try? await session.data(from: url),
              (reply.1 as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return DesktopWeather.cities(fromSearch: reply.0)
    }
}
