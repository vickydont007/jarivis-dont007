import 'dart:async';
import 'package:dio/dio.dart';

class WeatherData {
  final String city;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final String description;
  final String icon;
  final double windSpeed;
  final int visibility;
  final DateTime timestamp;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.visibility,
    required this.timestamp,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      city: json['name'] ?? '',
      temperature: (json['main']?['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']?['feels_like'] ?? 0).toDouble(),
      humidity: json['main']?['humidity'] ?? 0,
      description: json['weather']?[0]?['description'] ?? '',
      icon: json['weather']?[0]?['icon'] ?? '',
      windSpeed: (json['wind']?['speed'] ?? 0).toDouble(),
      visibility: json['visibility'] ?? 0,
      timestamp: DateTime.now(),
    );
  }

  factory WeatherData.fromOpenMeteo(Map<String, dynamic> json, String city) {
    final current = json['current'] ?? {};
    final weatherCode = current['weather_code'] ?? 0;
    final description = _weatherCodeToDescription(weatherCode);
    final icon = _weatherCodeToIcon(weatherCode);
    
    return WeatherData(
      city: city,
      temperature: (current['temperature_2m'] ?? 0).toDouble(),
      feelsLike: (current['apparent_temperature'] ?? 0).toDouble(),
      humidity: (current['relative_humidity_2m'] ?? 0).toInt(),
      description: description,
      icon: icon,
      windSpeed: (current['wind_speed_10m'] ?? 0).toDouble(),
      visibility: 10000,
      timestamp: DateTime.now(),
    );
  }

  static String _weatherCodeToDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 49) return 'Fog';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rain';
    if (code <= 79) return 'Snow';
    if (code <= 82) return 'Rain showers';
    if (code <= 86) return 'Snow showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  static String _weatherCodeToIcon(int code) {
    if (code == 0) return '01d';
    if (code <= 3) return '02d';
    if (code <= 49) return '50d';
    if (code <= 59) return '09d';
    if (code <= 69) return '10d';
    if (code <= 79) return '13d';
    if (code <= 82) return '09d';
    if (code <= 86) return '13d';
    if (code <= 99) return '11d';
    return '01d';
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'temperature': temperature,
      'feels_like': feelsLike,
      'humidity': humidity,
      'description': description,
      'icon': icon,
      'wind_speed': windSpeed,
      'visibility': visibility,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String getTemperatureString() {
    return '${temperature.toStringAsFixed(1)}°C';
  }

  String getFeelsLikeString() {
    return 'Feels like ${feelsLike.toStringAsFixed(1)}°C';
  }

  String getIconUrl() {
    return 'https://openweathermap.org/img/wn/$icon@2x.png';
  }
}

class WeatherForecast {
  final List<WeatherData> daily;
  final DateTime timestamp;

  WeatherForecast({
    required this.daily,
    required this.timestamp,
  });
}

class WeatherService {
  final Dio _dio = Dio();

  WeatherService();

  Future<WeatherData?> getCurrentWeather(String city) async {
    // Use Open-Meteo (free, no API key needed)
    try {
      // First, geocode the city
      final geoResponse = await _dio.get(
        'https://geocoding-api.open-meteo.com/v1/search',
        queryParameters: {
          'name': city,
          'count': 5,
          'language': 'en',
        },
      );

      print('Geocoding response: ${geoResponse.data}');

      if (geoResponse.statusCode != 200) {
        print('Geocoding failed with status: ${geoResponse.statusCode}');
        return null;
      }

      final data = geoResponse.data;
      if (data == null || data['results'] == null) {
        print('No results found for city: $city');
        return null;
      }

      final results = data['results'] as List;
      if (results.isEmpty) {
        print('Empty results for city: $city');
        return null;
      }

      // Use first result
      final firstResult = results[0];
      final lat = firstResult['latitude'];
      final lon = firstResult['longitude'];
      final resolvedCity = firstResult['name'] ?? city;
      final country = firstResult['country'] ?? '';

      print('Resolved city: $resolvedCity, Country: $country, Lat: $lat, Lon: $lon');

      // Get current weather
      final weatherResponse = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
          'timezone': 'auto',
        },
      );

      print('Weather response: ${weatherResponse.data}');

      if (weatherResponse.statusCode == 200) {
        final weatherData = WeatherData.fromOpenMeteo(weatherResponse.data, '$resolvedCity, $country');
        return weatherData;
      }
      return null;
    } catch (e, stackTrace) {
      print('Error fetching weather: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<WeatherData?> getCurrentWeatherByCoords(
    double latitude,
    double longitude,
  ) async {
    try {
      final weatherResponse = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
          'timezone': 'auto',
        },
      );

      if (weatherResponse.statusCode == 200) {
        return WeatherData.fromOpenMeteo(weatherResponse.data, 'Current Location');
      }
      return null;
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }

  Future<WeatherForecast?> getForecast(String city) async {
    try {
      // Geocode city
      final geoResponse = await _dio.get(
        'https://geocoding-api.open-meteo.com/v1/search',
        queryParameters: {
          'name': city,
          'count': 1,
          'language': 'en',
        },
      );

      if (geoResponse.statusCode != 200 || geoResponse.data['results'] == null) {
        return null;
      }

      final results = geoResponse.data['results'] as List;
      if (results.isEmpty) return null;

      final lat = results[0]['latitude'];
      final lon = results[0]['longitude'];

      // Get forecast
      final weatherResponse = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'daily': 'temperature_2m_max,temperature_2m_min,weather_code',
          'timezone': 'auto',
          'forecast_days': 5,
        },
      );

      if (weatherResponse.statusCode == 200) {
        final daily = weatherResponse.data['daily'];
        final times = daily['time'] as List;
        final maxTemps = daily['temperature_2m_max'] as List;
        final minTemps = daily['temperature_2m_min'] as List;
        final codes = daily['weather_code'] as List;

        final forecastList = <WeatherData>[];
        for (var i = 0; i < times.length; i++) {
          final code = codes[i] as int;
          forecastList.add(WeatherData(
            city: city,
            temperature: (maxTemps[i] + minTemps[i]) / 2,
            feelsLike: minTemps[i].toDouble(),
            humidity: 50,
            description: WeatherData._weatherCodeToDescription(code),
            icon: WeatherData._weatherCodeToIcon(code),
            windSpeed: 0,
            visibility: 10000,
            timestamp: DateTime.parse(times[i]),
          ));
        }

        return WeatherForecast(
          daily: forecastList,
          timestamp: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Error fetching forecast: $e');
      return null;
    }
  }

  String getWeatherEmoji(String description) {
    final lowerDesc = description.toLowerCase();
    if (lowerDesc.contains('clear')) return '☀️';
    if (lowerDesc.contains('cloud')) return '☁️';
    if (lowerDesc.contains('rain')) return '🌧️';
    if (lowerDesc.contains('drizzle')) return '🌦️';
    if (lowerDesc.contains('thunder')) return '⛈️';
    if (lowerDesc.contains('snow')) return '❄️';
    if (lowerDesc.contains('mist') || lowerDesc.contains('fog')) return '🌫️';
    return '🌤️';
  }

  String getWeatherMessage(WeatherData weather) {
    final emoji = getWeatherEmoji(weather.description);
    return '$emoji ${weather.getTemperatureString()} in ${weather.city}\n'
        '${weather.description}\n'
        'Humidity: ${weather.humidity}%\n'
        'Wind: ${weather.windSpeed} m/s';
  }
}
