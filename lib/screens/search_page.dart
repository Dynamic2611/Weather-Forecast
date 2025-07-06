import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController searchController = TextEditingController();
  final String token = const Uuid().v4(); // Generate a fresh session token
  List<dynamic> listOfLocation = [];

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      _onChange();
    });
  }

  _onChange() {
    if (searchController.text.length >= 2) {
      placeSuggestion(searchController.text);
    } else {
      setState(() {
        listOfLocation = [];
      });
    }
  }

  void placeSuggestion(String input) async {
    const String apiKey = "AIzaSyD8r0v2sE3uKxcJwSJUAixz5l0hnl16Pb8";
    try {
      String baseUrl = "https://maps.googleapis.com/maps/api/place/autocomplete/json";
      String request = "$baseUrl?input=$input&key=$apiKey&sessiontoken=$token";
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          print(data);
        }
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "Search places...",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (searchController.text.isNotEmpty && listOfLocation.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: listOfLocation.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(listOfLocation[index]['description']),
                      onTap: () {
                        final cityName = listOfLocation[index]["structured_formatting"]["main_text"];
                        if (cityName != null && cityName is String) {
                          Navigator.pop(context, cityName); // pass only "Mumbai"
                        }
                        // You can return data or fetch lat/lon here
                        print("Selected: ${listOfLocation[index]['description']}");
                      },
                    );
                  },
                ),
              ),
            if (searchController.text.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 20),
                child: ElevatedButton(
                  onPressed: () {
                    // Add "get current location" logic here
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.my_location, color: Colors.green),
                      SizedBox(width: 10),
                      Text(
                        "My Location",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
