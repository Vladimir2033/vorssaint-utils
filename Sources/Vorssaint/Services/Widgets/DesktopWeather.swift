// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A city the weather card follows, as the person picked it from the search.
struct WeatherCity: Codable, Equatable, Identifiable {
    var name: String
    /// The state or region, to tell apart two cities of the same name.
    var region: String
    var country: String
    var latitude: Double
    var longitude: Double

    /// Stable for a saved city: the coordinates, rounded the way they are sent.
    var id: String { String(format: "%.3f,%.3f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude) }
}

/// What the weather is doing, from the WMO code the forecast reports.
enum WeatherCondition: String, Codable, Equatable {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, showers, thunderstorm

    init(code: Int) {
        switch code {
        case 0: self = .clear
        case 1, 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57: self = .drizzle
        case 61, 63, 65, 66, 67: self = .rain
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 80, 81, 82: self = .showers
        case 95, 96, 99: self = .thunderstorm
        default: self = .cloudy
        }
    }

    /// The SF Symbol drawn for it, by day or by night.
    func symbol(isDay: Bool) -> String {
        switch self {
        case .clear: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .showers: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }
}

/// One city's forecast, as the card draws it.
struct WeatherReport: Equatable {
    struct Hour: Equatable {
        /// The hour on the city's own clock, 0...23.
        var hour: Int
        var temperature: Double
        var condition: WeatherCondition
        var isDay: Bool
    }

    var temperature: Double
    var condition: WeatherCondition
    var isDay: Bool
    var high: Double?
    var low: Double?
    /// The next hours after the current one, at most `DesktopWeather.hours`.
    var hours: [Hour]
    var fetchedAt: Date
}

/// Open-Meteo, the forecast service the person chose: free, no account and
/// no key. Only a city's coordinates go out, plus the unit and the language
/// for the search. Pure, so the requests and the reading of the replies are
/// tested with replies written out by hand.
enum DesktopWeather {
    static let maxCities = 4
    static let hours = 5
    static let refreshInterval: TimeInterval = 30 * 60

    static func forecastURL(for city: WeatherCity, fahrenheit: Bool) -> URL? {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        parts?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), city.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), city.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
        ]
        return parts?.url
    }

    static func searchURL(for query: String, language: String) -> URL? {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { return nil }
        var parts = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        parts?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "json"),
        ]
        return parts?.url
    }

    private struct SearchReply: Decodable {
        struct Result: Decodable {
            var name: String
            var latitude: Double
            var longitude: Double
            var country: String?
            var admin1: String?
        }
        var results: [Result]?
    }

    /// The cities a search found; none for a reply that is not one.
    static func cities(fromSearch data: Data) -> [WeatherCity] {
        guard let reply = try? JSONDecoder().decode(SearchReply.self, from: data) else { return [] }
        return (reply.results ?? []).compactMap { result in
            guard result.latitude.isFinite, result.longitude.isFinite,
                  (-90...90).contains(result.latitude), (-180...180).contains(result.longitude) else { return nil }
            return WeatherCity(name: result.name, region: result.admin1 ?? "", country: result.country ?? "",
                               latitude: result.latitude, longitude: result.longitude)
        }
    }

    private struct ForecastReply: Decodable {
        struct Current: Decodable {
            var time: String
            var temperature_2m: Double
            var weather_code: Int
            var is_day: Int
        }
        struct Hourly: Decodable {
            var time: [String]
            var temperature_2m: [Double?]
            var weather_code: [Int?]
            var is_day: [Int?]
        }
        struct Daily: Decodable {
            var temperature_2m_max: [Double?]
            var temperature_2m_min: [Double?]
        }
        var utc_offset_seconds: Int
        var current: Current
        var hourly: Hourly?
        var daily: Daily?
    }

    /// A city's forecast, or nil for a reply that is not one. Times in the
    /// reply are the city's local clock ("2026-10-17T14:30") with its offset
    /// given apart, so they are read in that offset.
    static func report(fromForecast data: Data, fetchedAt: Date) -> WeatherReport? {
        guard let reply = try? JSONDecoder().decode(ForecastReply.self, from: data),
              reply.current.temperature_2m.isFinite,
              let zone = TimeZone(secondsFromGMT: reply.utc_offset_seconds) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = formatter.date(from: reply.current.time) ?? fetchedAt

        var upcoming: [WeatherReport.Hour] = []
        if let hourly = reply.hourly {
            let count = min(hourly.time.count, hourly.temperature_2m.count, hourly.weather_code.count, hourly.is_day.count)
            for index in 0..<count {
                guard upcoming.count < hours,
                      let time = formatter.date(from: hourly.time[index]), time > now,
                      let temperature = hourly.temperature_2m[index], temperature.isFinite,
                      let code = hourly.weather_code[index] else { continue }
                upcoming.append(.init(hour: calendar.component(.hour, from: time), temperature: temperature,
                                      condition: WeatherCondition(code: code), isDay: (hourly.is_day[index] ?? 1) == 1))
            }
        }
        let high = reply.daily?.temperature_2m_max.first.flatMap { $0 }.flatMap { $0.isFinite ? $0 : nil }
        let low = reply.daily?.temperature_2m_min.first.flatMap { $0 }.flatMap { $0.isFinite ? $0 : nil }
        return WeatherReport(temperature: reply.current.temperature_2m,
                             condition: WeatherCondition(code: reply.current.weather_code),
                             isDay: reply.current.is_day == 1, high: high, low: low,
                             hours: upcoming, fetchedAt: fetchedAt)
    }

    /// The saved list: one JSON city per entry, so a bad entry costs only itself.
    static func decodeCities(_ stored: [String]?) -> [WeatherCity] {
        let decoder = JSONDecoder()
        var seen = Set<String>()
        return (stored ?? []).compactMap { text in
            guard let city = try? decoder.decode(WeatherCity.self, from: Data(text.utf8)),
                  seen.insert(city.id).inserted else { return nil }
            return city
        }
        .prefix(maxCities)
        .map { $0 }
    }

    static func encodeCities(_ cities: [WeatherCity]) -> [String] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return cities.prefix(maxCities).compactMap { city in
            (try? encoder.encode(city)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    /// "24°", rounded the way a glance reads it.
    static func degrees(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return "\(Int(value.rounded()))°"
    }
}
