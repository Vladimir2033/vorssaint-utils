// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What leaves the Mac for the weather card (a city's coordinates, the unit,
/// the search text) and how the replies are read: the next hours on the
/// city's own clock, and a broken or odd reply never shown as a forecast.
enum DesktopWeatherTests {
    private static let rio = WeatherCity(name: "Rio de Janeiro", region: "Rio de Janeiro", country: "Brasil",
                                         latitude: -22.90642, longitude: -43.18223)

    static func run(_ suite: TestSuite) {
        requests(suite)
        search(suite)
        forecast(suite)
        saved(suite)
        conditions(suite)
    }

    private static func requests(_ suite: TestSuite) {
        let url = DesktopWeather.forecastURL(for: rio, fahrenheit: false)?.absoluteString ?? ""
        suite.expect(url.hasPrefix("https://api.open-meteo.com/v1/forecast?"), "the forecast goes to Open-Meteo over HTTPS")
        suite.expect(url.contains("latitude=-22.906") && url.contains("longitude=-43.182"),
                     "only the rounded coordinates are sent: \(url)")
        suite.expect(!url.contains("Rio") && !url.contains("Brasil"), "the city's name is not sent with the forecast")
        suite.expect(url.contains("temperature_unit=celsius"), "Celsius by default")
        suite.expect(DesktopWeather.forecastURL(for: rio, fahrenheit: true)?.absoluteString.contains("temperature_unit=fahrenheit") == true,
                     "Fahrenheit when the app is set to it")
        let search = DesktopWeather.searchURL(for: "  São Paulo ", language: "pt")?.absoluteString ?? ""
        suite.expect(search.hasPrefix("https://geocoding-api.open-meteo.com/v1/search?") && search.contains("language=pt")
                         && search.contains("name=S%C3%A3o%20Paulo"),
                     "the search sends the trimmed name and the language: \(search)")
        suite.expect(DesktopWeather.searchURL(for: " a ", language: "pt") == nil, "a one-letter search is not sent")
    }

    private static func search(_ suite: TestSuite) {
        let reply = Data("""
        {"results":[{"id":1,"name":"Rio de Janeiro","latitude":-22.90642,"longitude":-43.18223,"country":"Brasil","admin1":"Rio de Janeiro"},
                    {"id":2,"name":"Nowhere","latitude":120,"longitude":10},
                    {"id":3,"name":"Rio Claro","latitude":-22.41,"longitude":-47.56}]}
        """.utf8)
        let cities = DesktopWeather.cities(fromSearch: reply)
        suite.expect(cities.map(\.name) == ["Rio de Janeiro", "Rio Claro"],
                     "found cities are kept and impossible coordinates dropped: \(cities.map(\.name))")
        suite.expect(cities.last?.region == "" && cities.last?.country == "", "a city without region or country still counts")
        suite.expect(DesktopWeather.cities(fromSearch: Data(#"{"generationtime_ms":0.5}"#.utf8)).isEmpty,
                     "a reply with no results finds nothing")
        suite.expect(DesktopWeather.cities(fromSearch: Data("not json".utf8)).isEmpty, "a broken reply finds nothing")
    }

    private static func forecast(_ suite: TestSuite) {
        let reply = Data("""
        {"utc_offset_seconds":-10800,
         "current":{"time":"2026-10-17T22:30","temperature_2m":24.4,"weather_code":95,"is_day":0},
         "hourly":{"time":["2026-10-17T21:00","2026-10-17T22:00","2026-10-17T23:00","2026-10-18T00:00","2026-10-18T01:00","2026-10-18T02:00","2026-10-18T03:00","2026-10-18T04:00"],
                   "temperature_2m":[25,24.6,24.2,null,23.4,23.1,22.9,22.5],
                   "weather_code":[95,95,61,61,63,2,0,0],
                   "is_day":[0,0,0,0,0,0,0,0]},
         "daily":{"temperature_2m_max":[27.8,26],"temperature_2m_min":[19.2,18]}}
        """.utf8)
        let fetched = Date(timeIntervalSince1970: 1_792_300_000)
        guard let report = DesktopWeather.report(fromForecast: reply, fetchedAt: fetched) else {
            suite.expect(false, "a well-formed forecast is read")
            return
        }
        suite.expect(report.condition == .thunderstorm && !report.isDay && report.temperature == 24.4,
                     "the current conditions are read")
        suite.expect(report.high == 27.8 && report.low == 19.2, "today's high and low are read")
        suite.expect(report.hours.map(\.hour) == [23, 1, 2, 3, 4],
                     "the next five hours after now on the city's clock, a gap skipped: \(report.hours.map(\.hour))")
        suite.expect(report.hours.first?.condition == .rain && report.hours[2].condition == .partlyCloudy,
                     "each hour keeps its own condition")
        suite.expect(report.fetchedAt == fetched, "the report says when it was fetched")

        let broken = Data(#"{"utc_offset_seconds":0,"current":{"time":"x","temperature_2m":"warm","weather_code":0,"is_day":1}}"#.utf8)
        suite.expect(DesktopWeather.report(fromForecast: broken, fetchedAt: fetched) == nil,
                     "a reply that is not a forecast is never shown as one")
        let bare = Data(#"{"utc_offset_seconds":3600,"current":{"time":"2026-10-17T10:00","temperature_2m":-3,"weather_code":71,"is_day":1}}"#.utf8)
        let minimal = DesktopWeather.report(fromForecast: bare, fetchedAt: fetched)
        suite.expect(minimal?.condition == .snow && minimal?.hours.isEmpty == true && minimal?.high == nil,
                     "a forecast without hours or days still shows the current weather")
    }

    private static func saved(_ suite: TestSuite) {
        let five = (0..<5).map { WeatherCity(name: "C\($0)", region: "", country: "", latitude: Double($0), longitude: 1) }
        let stored = DesktopWeather.encodeCities(five)
        suite.expect(stored.count == DesktopWeather.maxCities, "at most four cities are saved")
        let read = DesktopWeather.decodeCities(stored + ["{broken", stored[0]])
        suite.expect(read == Array(five.prefix(4)), "the saved cities read back, a broken or repeated entry skipped")
        suite.expect(DesktopWeather.decodeCities(nil).isEmpty, "no saved list is no cities")
        suite.expect(rio.id == "-22.906,-43.182", "a city is known by its rounded coordinates")
        suite.expect(DesktopWeather.degrees(23.6) == "24°" && DesktopWeather.degrees(-0.4) == "0°"
                         && DesktopWeather.degrees(.nan) == "–",
                     "temperatures round to whole degrees")
    }

    private static func conditions(_ suite: TestSuite) {
        let expected: [(Int, WeatherCondition)] = [(0, .clear), (2, .partlyCloudy), (3, .cloudy), (45, .fog),
                                                   (53, .drizzle), (63, .rain), (75, .snow), (81, .showers),
                                                   (95, .thunderstorm), (42, .cloudy)]
        for (code, condition) in expected {
            suite.expect(WeatherCondition(code: code) == condition, "WMO code \(code) reads as \(condition)")
        }
        suite.expect(WeatherCondition.clear.symbol(isDay: false) == "moon.stars.fill"
                         && WeatherCondition.clear.symbol(isDay: true) == "sun.max.fill",
                     "a clear night draws the moon")
    }
}
