import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodImageService {
  static const String _apiKey = 'df1bc53b673b41398101b85304b24dec';

  // Fetches image URL from Spoonacular for a given dish name
  // Returns null if nothing found or API fails
  static Future<String?> fetchImage(String foodName) async {
    try {
      final query = Uri.encodeComponent(foodName);
      final url = 'https://api.spoonacular.com/recipes/complexSearch'
          '?query=$query&number=1&apiKey=$_apiKey';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final image = results[0]['image'] as String?;
          return image;
        }
      }
    } catch (e) {
      print('Spoonacular error for "$foodName": $e');
    }
    return null;
  }
}