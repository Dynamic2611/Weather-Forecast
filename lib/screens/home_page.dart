import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/weather.dart';
import 'package:weather_app/consts.dart';
import 'package:weather_app/screens/search_page.dart'; // Make sure this file contains your API key as OPENWEATHER_API_KEY

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> searchedCities = [];
  final WeatherFactory _wf = WeatherFactory(OPENWEATHER_API_KEY);



  Weather? _weather;

  Future<void> saveCityToHistory(String city) async {
    final prefs = await SharedPreferences.getInstance();
    if (!searchedCities.contains(city)) {
      searchedCities.add(city);
      await prefs.setStringList('searchedCities', searchedCities);
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
        fetchWeather(searchedCities.last); // Load last searched city
      } else {
        fetchWeather("Uttar Pradesh");
      }
    });
  }

  void fetchWeather([String city = "Uttar Pradesh"]) async {
    try {
      print("Fetching weather for $city...");
      Weather w = await _wf.currentWeatherByCityName(city);
      setState(() {
        _weather = w;
      });
      print("Weather fetched: $_weather");
    } catch (e) {
      print("Error fetching weather: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get weather for $city")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    if (_weather == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          //_searchBar(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
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
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).height*0.02,
          ),
          _locationHeader(),
          SizedBox(
            height: MediaQuery.sizeOf(context).height*0.08,
          ),
          _dateTimeInfo(),
          SizedBox(
            height: MediaQuery.sizeOf(context).height*0.05,
          ),
          _weatherIcon(),
          SizedBox(
            height: MediaQuery.sizeOf(context).height*0.02,
          ),
          _currentTemp(),
          SizedBox(
            height: MediaQuery.sizeOf(context).height*0.02,
          ),
          _extraInfo()
        ],
      ),
    );
  }

  Widget _locationHeader(){
    return Text(_weather?.areaName ?? "",
    style: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500
    ),);
  }

  Widget _dateTimeInfo(){
    DateTime now= _weather!.date!;
    return Column(
      children: [
        Text(
          DateFormat("h:mm a").format(now),
          style: TextStyle(
            fontSize: 35,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              DateFormat("EEEE").format(now),
              style: TextStyle(
                fontWeight: FontWeight.w700
              ),
            ),
            Text(
              "  ${DateFormat("dd.mm.y").format(now)}",
              style: TextStyle(
                  fontWeight: FontWeight.w400
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _weatherIcon(){
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left:120,right: 120),
          child: Container(
            height: MediaQuery.sizeOf(context).height*0.20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: Colors.grey[400],
              image: DecorationImage(image: NetworkImage(
                "http://openweathermap.org/img/wn/${_weather?.weatherIcon}@4x.png"
              ))
            ),
          ),
        ),
        Text(_weather?.weatherDescription ?? " ",
        style: TextStyle(
          color: Colors.black,
          fontSize: 20
        ),),
      ],
    );
  }

  Widget _currentTemp(){
    return Text("${_weather?.temperature?.celsius?.toStringAsFixed(0)}° C",
    style: TextStyle(
      color: Colors.black,
      fontSize: 90,
      fontWeight: FontWeight.w500
    ),);
  }

  Widget _extraInfo(){
    return Container(
      height: MediaQuery.sizeOf(context).width*0.25,
      width: MediaQuery.sizeOf(context).width*0.90,

      decoration: BoxDecoration(color: Colors.deepPurpleAccent,
        borderRadius: BorderRadius.circular(20)
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text("Max: ${_weather?.tempMax?.celsius?.toStringAsFixed(0)}° C",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15
              ),),
              Text("Min: ${_weather?.tempMin?.celsius?.toStringAsFixed(0)}° C",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15
                ),)
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text("Wind: ${_weather?.windSpeed?.toStringAsFixed(0)}m/s",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15
                ),),
              Text("Humidity: ${_weather?.humidity?.toStringAsFixed(0)}%",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15
                ),)
            ],
          ),

        ],
      ),
    );
  }
}
