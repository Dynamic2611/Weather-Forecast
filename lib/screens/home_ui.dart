import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/weather.dart';
import 'package:weather_app/screens/search_page.dart';
import '../consts.dart';

class HomeUi extends StatefulWidget {
  const HomeUi({super.key});

  @override
  State<HomeUi> createState() => _HomeUiState();
}

class _HomeUiState extends State<HomeUi> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> searchedCities = ['Mumbai']; // default fallback
  int _currentCityIndex = 0;
  final WeatherFactory _wf = WeatherFactory(OPENWEATHER_API_KEY);
  Weather? _weather;
  Timer? _weatherTimer;
  List<Weather>? _forecast;


  String _getWeatherEmoji(String description) {
    description = description.toLowerCase();
    if (description.contains("cloud")) return "☁️";
    if (description.contains("sun")) return "☀️";
    if (description.contains("clear")) return "🌤️";
    if (description.contains("rain")) return "🌧️";
    if (description.contains("thunder")) return "⛈️";
    if (description.contains("snow")) return "❄️";
    return "🌈";
  }


  List<Weather> getNextHoursForecast({int count = 4}) {
    if (_forecast == null || _forecast!.isEmpty) return [];
    final now = DateTime.now();
    return _forecast!
        .where((w) => w.date != null && w.date!.isAfter(now))
        .take(count)
        .toList();
  }

  List<Weather> getNextTwoDaysForecast() {
    if (_forecast == null || _forecast!.isEmpty) return [];
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final dayAfterTomorrow = now.add(const Duration(days: 2));
    final nextTwoDays = _forecast!.where((w) {
      final wDate = w.date;
      return wDate != null &&
          (wDate.day == tomorrow.day || wDate.day == dayAfterTomorrow.day) &&
          wDate.month == tomorrow.month;
    }).toList();

    final Map<int, Weather> groupedByDay = {};
    for (final weather in nextTwoDays) {
      groupedByDay[weather.date!.day] ??= weather;
    }
    return groupedByDay.values.take(2).toList();
  }

  Future<void> saveCityToHistory(String city) async {
    final prefs = await SharedPreferences.getInstance();
    bool alreadyExists = searchedCities.any((c) => c.toLowerCase() == city.toLowerCase());

    if (!alreadyExists) {
      searchedCities.add(city);
      await prefs.setStringList('searchedCities', searchedCities);
      setState(() {});
    }
  }

  Future<void> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    searchedCities = prefs.getStringList('searchedCities') ?? ['Mumbai'];
  }

  @override
  void initState() {
    super.initState();
    loadSearchHistory().then((_) {
      if (searchedCities.isNotEmpty) {
        fetchWeather(searchedCities[_currentCityIndex]);
        print(searchedCities);
      } else {
        fetchWeather("Mumbai");
      }

      // Auto-refresh every 10 minutes
      _weatherTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
        if (searchedCities.isNotEmpty) {
          fetchWeather(searchedCities[_currentCityIndex]);
        }
      });
    });
  }


  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  void fetchWeather(String city) async {
    try {
      Weather w = await _wf.currentWeatherByCityName(city);
      List<Weather> forecast = await _wf.fiveDayForecastByCityName(city);
      setState(() {
        _weather = w;
        _forecast = forecast;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get weather for $city")),
      );
    }
  }

  void _handleSwipe(DragEndDetails details) {
    const swipeVelocityThreshold = 1000;
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! > swipeVelocityThreshold) {
        // Swipe right
        if (_currentCityIndex > 0) {
          _currentCityIndex--;
          fetchWeather(searchedCities[_currentCityIndex]);
        }
      } else if (details.primaryVelocity! < -swipeVelocityThreshold) {
        // Swipe left
        if (_currentCityIndex < searchedCities.length - 1) {
          _currentCityIndex++;
          fetchWeather(searchedCities[_currentCityIndex]);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextTwoDays = getNextTwoDaysForecast();
    final nextHours = getNextHoursForecast();
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF6A11CB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.location_on_outlined, color: Colors.white),
        title: Text(
          _weather?.areaName ?? "Loading...",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final selectedCity = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
              if (selectedCity != null && selectedCity is String) {
                _currentCityIndex = searchedCities.length;
                fetchWeather(selectedCity);
                saveCityToHistory(selectedCity);
              }
            },
          ),
        ],
      ),
      body: _weather == null
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
        onHorizontalDragEnd: _handleSwipe,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _dateTimeInfo(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          "${_weather?.temperature?.celsius?.toStringAsFixed(0) ?? '--'}°C",
                          style: const TextStyle(fontSize: 60, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(_weather?.weatherDescription ?? "", style: const TextStyle(color: Colors.white70, fontSize: 18)),
                      ],
                    ),
                    if (_weather?.weatherIcon != null)
                      Image.network(
                        "http://openweathermap.org/img/wn/${_weather!.weatherIcon}@4x.png",
                        height: MediaQuery.of(context).size.height * 0.25,
                      ),
                  ],
                ),
              ),
              _cityDotsIndicator(),
              SizedBox(height: 20,),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(width: 2, color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoBox("${DateFormat("HH:mm").format(DateTime.now())}", "Feels like\n${_weather?.tempFeelsLike?.celsius?.toStringAsFixed(0)}°C", Icons.thermostat),
                          const Text("|", style: TextStyle(fontSize: 40, color: Colors.white)),
                          _infoBox("${_weather?.windSpeed?.toStringAsFixed(1)} m/s", "Wind speed", Icons.air),
                          const Text("|", style: TextStyle(fontSize: 40, color: Colors.white)),
                          _infoBox("${_weather?.humidity?.toStringAsFixed(0)}%", "Humidity", Icons.water_drop),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(

                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border.all(width: 2, color: Colors.black.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: SizedBox(
                            height: 5,
                            width: 50,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.all(Radius.circular(20))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text("Hourly Forecast", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: nextHours.length,
                            itemBuilder: (context, index) {
                              final hourData = nextHours[index];
                              final time = hourData.date != null
                                  ? DateFormat("hh:mm a").format(hourData.date!)
                                  : "--";
                              final temp = hourData.temperature?.celsius?.toStringAsFixed(0) ?? "--";
                              final emoji = _getWeatherEmoji(hourData.weatherDescription ?? "");

                              return _hourItem(time, emoji, "$temp°C");
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text("Tomorrow", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Column(
                              children: nextTwoDays.map((w) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(2, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            " ${_getWeatherEmoji(w.weatherDescription ?? " ")} ${DateFormat('EEEE').format(w.date!)}",
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          Text("       ${w.weatherDescription ?? 'No data'}"),
                                        ],
                                      ),
                                      Text(
                                        "🌡️ ${w.tempMax?.celsius?.toStringAsFixed(0)}° / ${w.tempMin?.celsius?.toStringAsFixed(0)}°",
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        )

                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String title, String subtitle, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _hourItem(String time, String emoji, String temp) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6, offset: const Offset(2, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 10),
          Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(temp, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _dateTimeInfo() {
    final now = _weather?.date;
    if (now == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat("EEEE").format(now), // e.g., Monday
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 16),
              ),
              Text(
                DateFormat("dd MMM, yyyy").format(now), // e.g., 05 Jul, 2025
                style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    fontSize: 14),
              ),
            ],
          ),
          Text(
            DateFormat("hh:mm a").format(now), // e.g., 10:34 AM
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
        ],
      ),
    );
  }


  Widget _cityDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(searchedCities.length, (index) {
        bool isSelected = index == _currentCityIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isSelected ? 12 : 8,
          height: isSelected ? 12 : 8,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white54,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }


}
