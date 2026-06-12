import 'tool.dart';
import '../services/weather_service.dart';

class WeatherCurrentTool extends Tool {
  final WeatherService _service = WeatherService();

  WeatherCurrentTool()
      : super(
          name: 'weather_current',
          description: 'Get current weather for a city',
          parameters: [
            const ToolParameter(
              name: 'city',
              description: 'City name (e.g., "London", "New York")',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'api_key',
              description: 'OpenWeatherMap API key',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final city = params['city'] as String;
    final apiKey = params['api_key'] as String?;

    if (apiKey != null) {
      _service.setApiKey(apiKey);
    }

    try {
      final weather = await _service.getCurrentWeather(city);
      if (weather != null) {
        return ToolResult.success(weather.toMap());
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
          description: 'Get weather forecast for a city',
          parameters: [
            const ToolParameter(
              name: 'city',
              description: 'City name',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'api_key',
              description: 'OpenWeatherMap API key',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final city = params['city'] as String;
    final apiKey = params['api_key'] as String?;

    if (apiKey != null) {
      _service.setApiKey(apiKey);
    }

    try {
      final forecast = await _service.getForecast(city);
      if (forecast != null) {
        final data = forecast.daily.map((w) => w.toMap()).toList();
        return ToolResult.success(data);
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
