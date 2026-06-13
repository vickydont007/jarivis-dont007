import 'tool.dart';
import '../services/weather_service.dart';

class WeatherCurrentTool extends Tool {
  final WeatherService _service = WeatherService();

  WeatherCurrentTool()
      : super(
          name: 'weather_current',
          description: 'Get current weather for a city. Free, no API key needed.',
          parameters: [
            const ToolParameter(
              name: 'city',
              description: 'City name (e.g., "London", "New York", "Delhi")',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final city = params['city'] as String;

    try {
      final weather = await _service.getCurrentWeather(city);
      if (weather != null) {
        final message = _service.getWeatherMessage(weather);
        return ToolResult.success(message, metadata: weather.toMap());
      }
      return ToolResult.error('Could not fetch weather for: $city');
    } catch (e) {
      return ToolResult.error('Weather fetch failed: $e');
    }
  }
}

class WeatherForecastTool extends Tool {
  final WeatherService _service = WeatherService();

  WeatherForecastTool()
      : super(
          name: 'weather_forecast',
          description: 'Get 5-day weather forecast for a city. Free, no API key needed.',
          parameters: [
            const ToolParameter(
              name: 'city',
              description: 'City name',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final city = params['city'] as String;

    try {
      final forecast = await _service.getForecast(city);
      if (forecast != null) {
        final buf = StringBuffer('5-day forecast for $city:\n\n');
        for (final day in forecast.daily) {
          final emoji = _service.getWeatherEmoji(day.description);
          buf.writeln('$emoji ${day.timestamp.day}/${day.timestamp.month}: ${day.getTemperatureString()} - ${day.description}');
        }
        return ToolResult.success(buf.toString());
      }
      return ToolResult.error('Could not fetch forecast for: $city');
    } catch (e) {
      return ToolResult.error('Forecast fetch failed: $e');
    }
  }
}

List<Tool> getAllWeatherTools() {
  return [WeatherCurrentTool(), WeatherForecastTool()];
}
