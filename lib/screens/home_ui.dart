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
  List<String> searchedCities = [];
  final WeatherFactory _wf = WeatherFactory(OPENWEATHER_API_KEY);
  Weather? _weather;
  List<Weather>? _forecast;

  List<Weather> getNextTwoDaysForecast() {
    if (_forecast == null || _forecast!.isEmpty) return [];

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final dayAfterTomorrow = now.add(const Duration(days: 2));

    // Filter the forecast list for dates matching tomorrow and day after
    final nextTwoDays = _forecast!.where((w) {
      final wDate = w.date;
      return wDate != null &&
          (wDate.day == tomorrow.day || wDate.day == dayAfterTomorrow.day) &&
          wDate.month == tomorrow.month; // Ensures same month
    }).toList();

    // Optional: group by day and return one item per day
    final Map<int, Weather> groupedByDay = {};
    for (final weather in nextTwoDays) {
      groupedByDay[weather.date!.day] ??= weather;
    }

    return groupedByDay.values.take(2).toList(); // Ensures only 2 days are returned
  }



  Future<void> saveCityToHistory(String city) async {
    final prefs = await SharedPreferences.getInstance();

    // Make comparison case-insensitive
    bool alreadyExists = searchedCities.any((c) => c.toLowerCase() == city.toLowerCase());

    if (!alreadyExists) {
      searchedCities.add(city);
      await prefs.setStringList('searchedCities', searchedCities);
      setState(() {});
    }
  }


  Future<void> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    searchedCities = prefs.getStringList('searchedCities') ?? [];
  }

  @override
  void initState() {
    super.initState();
    loadSearchHistory().then((_) {
      if (searchedCities.isNotEmpty) {
        fetchWeather(searchedCities.last);
        print(searchedCities);
      } else {
        fetchWeather("Mumbai");
      }
    });
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




  @override
  Widget build(BuildContext context) {
    final nextTwoDays = getNextTwoDaysForecast();
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF6A11CB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.location_on_outlined, color: Colors.white),
        title: Text(_weather?.areaName ?? "Loading...", style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final selectedCity = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
              if (selectedCity != null && selectedCity is String) {
                fetchWeather(selectedCity);
                saveCityToHistory(selectedCity);
              }
            },
          ),
        ],
      ),
      body: _weather == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6A11CB),
                    Color(0xFF2575FC),
                  ],
                ),
              ),
            child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: _dateTimeInfo(),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "${_weather?.temperature?.celsius?.toStringAsFixed(0) ?? '--'}°C",
                        style: const TextStyle(
                          fontSize: 60,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _weather?.weatherDescription ?? "",
                        style: const TextStyle(color: Colors.white70, fontSize: 20),
                      ),
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
                      border: Border.all(
                        width: 2,
                          color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoBox("${DateFormat("HH:mm").format(DateTime.now())}", "Feels like\n${_weather?.tempFeelsLike?.celsius?.toStringAsFixed(0)}°C", Icons.thermostat),
                        Text("|",style: TextStyle(fontSize: 40,color: Colors.white),),
                        _infoBox("${_weather?.windSpeed?.toStringAsFixed(1)} m/s", "Wind speed", Icons.air),
                        Text("|",style: TextStyle(fontSize: 40,color: Colors.white),),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, -5), // shadow upwards
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 5,
                          width: 50,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const Text(
                        "Hourly Forecast",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _hourItem("05:00 AM", "☀️", "${_weather?.tempMax?.celsius?.toStringAsFixed(0)}°"),
                              _hourItem("06:00 AM", "🌤️", "${_weather?.temperature?.celsius?.toStringAsFixed(0)}°"),
                              _hourItem("07:00 AM", "🌧️", "${_weather?.tempMin?.celsius?.toStringAsFixed(0)}°"),
                              _hourItem("08:00 AM", "🌧️", "${_weather?.tempFeelsLike?.celsius?.toStringAsFixed(0)}°"),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text("Tomorrow", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: nextTwoDays.map((w) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 15),
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
                                      Text(" 🌧️ ${DateFormat('EEEE').format(w.date!)}", style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text("       ${w.weatherDescription ?? 'No data'}")
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
                    ],
                  ),
                ),
              ),
            )
                        ],
            ),
      ),
    );
  }

  Widget _infoBox(String title, String subtitle, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
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
  Widget _verticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _hourItem(String time, String emoji, String temp) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 10),
          Text(
            time,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            temp,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _dateTimeInfo() {
    final now = _weather?.date;
    if (now == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [


        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              DateFormat("EEEE").format(now),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20),
            ),
            Text(
              "  ${DateFormat("dd/MM/y").format(now)}",
              style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          DateFormat("h:mm a").format(now),
          style: const TextStyle(fontSize: 30, color: Colors.white),
        ),
      ],
    );
  }
}
