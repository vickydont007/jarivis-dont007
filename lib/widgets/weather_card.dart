import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();

  String _city = 'Delhi';
  double? _temperature;
  String _description = 'Loading...';
  int? _humidity;
  double? _windSpeed;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final weather = await _weatherService.getCurrentWeather(_city);
      if (weather != null && mounted) {
        setState(() {
          _temperature = weather.temperature;
          _description = weather.description;
          _humidity = weather.humidity;
          _windSpeed = weather.windSpeed;
          _city = weather.city;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'City "$_city" not found. Try: Delhi, Mumbai, New York';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to fetch weather.';
        });
      }
    }
  }

  String _getWeatherEmoji() {
    final desc = _description.toLowerCase();
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour > 19;

    if (desc.contains('clear')) return isNight ? '\u{1F319}' : '\u{2600}\u{FE0F}';
    if (desc.contains('cloud')) return '\u{2601}\u{FE0F}';
    if (desc.contains('rain')) return '\u{1F327}\u{FE0F}';
    if (desc.contains('snow')) return '\u{2744}\u{FE0F}';
    if (desc.contains('thunder')) return '\u{26C8}\u{FE0F}';
    if (desc.contains('mist') || desc.contains('fog')) return '\u{1F32B}\u{FE0F}';
    return isNight ? '\u{1F319}' : '\u{1F324}\u{FE0F}';
  }

  List<Color> _getWeatherGradient() {
    final desc = _description.toLowerCase();
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour > 19;

    if (isNight) {
      return [const Color(0xFF0D1117), const Color(0xFF1A1A3A)];
    }
    if (desc.contains('clear')) {
      return [const Color(0xFF0D1117), const Color(0xFF1A3A4A)];
    }
    if (desc.contains('rain') || desc.contains('thunder')) {
      return [const Color(0xFF0D1117), const Color(0xFF1A2A3A)];
    }
    if (desc.contains('cloud')) {
      return [const Color(0xFF0D1117), const Color(0xFF2D333B)];
    }
    return [const Color(0xFF0D1117), const Color(0xFF1A3A4A)];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getWeatherGradient(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.cloud, color: Color(0xFF00BCD4), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Weather',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00BCD4),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF8B949E), size: 18),
                  onPressed: _fetchWeather,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (_error != null)
            _buildError()
          else ...[
            // Main weather display
            Center(
              child: Column(
                children: [
                  Text(
                    _getWeatherEmoji(),
                    style: const TextStyle(fontSize: 56),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _temperature != null ? '${_temperature!.toStringAsFixed(1)}\u00B0C' : '--',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _description.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _city,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Detail chips
            Row(
              children: [
                Expanded(
                  child: _buildChip(
                    Icons.water_drop_outlined,
                    'Humidity',
                    _humidity != null ? '$_humidity%' : '--',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChip(
                    Icons.air,
                    'Wind',
                    _windSpeed != null ? '${_windSpeed!.toStringAsFixed(1)} km/h' : '--',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search city...',
                      hintStyle: const TextStyle(color: Color(0xFF6E7681), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6E7681), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        setState(() => _city = value);
                        _fetchWeather();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    onPressed: () {
                      if (_cityController.text.isNotEmpty) {
                        setState(() => _city = _cityController.text);
                        _fetchWeather();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00BCD4), size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF6E7681), fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}
