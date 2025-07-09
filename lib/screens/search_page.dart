import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController searchController = TextEditingController();
  final String token = const Uuid().v4();
  List<dynamic> listOfLocation = [];
  List<String> searchedCities = [];

  @override
  void initState() {
    super.initState();
    loadSearchHistory();
    searchController.addListener(_onChange);
  }

  Future<void> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      searchedCities = prefs.getStringList('searchedCities') ?? [];
    });
  }

  Future<void> deleteCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    searchedCities.remove(city);
    await prefs.setStringList('searchedCities', searchedCities);
    setState(() {});
  }

  void _onChange() {
    if (searchController.text.length >= 2) {
      placeSuggestion(searchController.text);
    } else {
      setState(() {
        listOfLocation = [];
      });
    }
  }

  void placeSuggestion(String input) async {
    const String apiKey = "GOOGLE_API_KEY"; // Replace with your actual Google API key
    try {
      String baseUrl = "https://maps.googleapis.com/maps/api/place/autocomplete/json";
      String request = "$baseUrl?input=$input&key=$apiKey&sessiontoken=$token";
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          listOfLocation = data['predictions'];
        });
      } else {
        throw Exception("Failed to load suggestions");
      }
    } catch (e) {
      print("Suggestion error: ${e.toString()}");
    }
  }

  Future<void> getCurrentLocationWeather() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition();
      Navigator.pop(context, {'lat': pos.latitude, 'lon': pos.longitude});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Search City"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "Search places...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              // ElevatedButton.icon(
              //   onPressed: getCurrentLocationWeather,
              //   icon: const Icon(Icons.my_location, color: Colors.white),
              //   label: const Text("Use My Location"),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.green,
              //     foregroundColor: Colors.white,
              //   ),
              // ),
              // const SizedBox(height: 10),
              if (searchedCities.isNotEmpty)
                Expanded(
                  child: ListView(
                    children: [
                      const Text("Recently Searched:", style: TextStyle(fontWeight: FontWeight.bold)),
                      ...searchedCities.map((city) => ListTile(
                        leading: const Icon(Icons.location_city),
                        title: Text(city),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteCity(city),
                        ),
                        onTap: () => Navigator.pop(context, city),
                      )),
                      const Divider(),
                    ],
                  ),
                ),
              if (searchController.text.isNotEmpty && listOfLocation.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: listOfLocation.length,
                    itemBuilder: (context, index) {
                      final location = listOfLocation[index];
                      final cityName = location["structured_formatting"]["main_text"];
                      return ListTile(
                        title: Text(location['description']),
                        onTap: () => Navigator.pop(context, cityName),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
