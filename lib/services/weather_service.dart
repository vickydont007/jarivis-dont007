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
  String? _apiKey;

  WeatherService({String? apiKey}) : _apiKey = apiKey;

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  Future<WeatherData?> getCurrentWeather(String city) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not set. Please set OpenWeatherMap API key in settings.');
    }

    try {
      final response = await _dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {
          'q': city,
          'appid': _apiKey,
          'units': 'metric',
        },
      );

      if (response.statusCode == 200) {
        return WeatherData.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }

  Future<WeatherData?> getCurrentWeatherByCoords(
    double latitude,
    double longitude,
  ) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not set');
    }

    try {
      final response = await _dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'appid': _apiKey,
          'units': 'metric',
        },
      );

      if (response.statusCode == 200) {
        return WeatherData.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }

  Future<WeatherForecast?> getForecast(String city) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not set');
    }

    try {
      final response = await _dio.get(
        'https://api.openweathermap.org/data/2.5/forecast',
        queryParameters: {
          'q': city,
          'appid': _apiKey,
          'units': 'metric',
          'cnt': 8, // 5 days / 3-hour intervals
        },
      );

      if (response.statusCode == 200) {
        final List<WeatherData> daily = [];
        for (final item in response.data['list']) {
          daily.add(WeatherData.fromJson(item));
        }
        return WeatherForecast(
          daily: daily,
          timestamp: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Error fetching forecast: $e');
      return null;
    }
  }

  // Get weather description emoji
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

  // Get weather message
  String getWeatherMessage(WeatherData weather) {
    final emoji = getWeatherEmoji(weather.description);
    return '$emoji ${weather.getTemperatureString()} in ${weather.city}\n'
        '${weather.description}\n'
        'Humidity: ${weather.humidity}%\n'
        'Wind: ${weather.windSpeed} m/s';
  }
}
