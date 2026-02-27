// import 'dart:math';
// import 'package:flutter/services.dart';
// import 'package:csv/csv.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// class DietService {
//   static List<Map<String, dynamic>>? _cachedMeals;

//   // ── LOAD MEALS — Firebase first, CSV fallback ─────────────────────────────
//   static Future<List<Map<String, dynamic>>> loadMeals() async {
//     if (_cachedMeals != null) return _cachedMeals!;

//     // 1. Try Firebase
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('foods').limit(1).get();

//       if (snapshot.docs.isNotEmpty) {
//         final allDocs = await FirebaseFirestore.instance
//             .collection('foods').get();
//         final meals = _groupFirebaseMeals(allDocs.docs);
//         _cachedMeals = meals;
//         print('Firebase: loaded ${meals.length} meal plans');
//         return meals;
//       }
//     } catch (e) {
//       print('Firebase load error: $e — falling back to CSV');
//     }

//     // 2. Fall back to CSV
//     return _loadFromCsv();
//   }

//   static List<Map<String, dynamic>> _groupFirebaseMeals(
//       List<QueryDocumentSnapshot> docs) {
//     final Map<String, Map<String, dynamic>> groups = {};

//     for (final doc in docs) {
//       final d = doc.data() as Map<String, dynamic>;
//       final key = '${d["phase"]}|${d["dietType"]}|${d["dietName"]}';

//       groups.putIfAbsent(key, () => {
//         'Phase':    d['phase'] ?? '',
//         'DietType': d['dietType'] ?? '',
//         'DietName': d['dietName'] ?? '',
//         'TotalCalories': '0',
//         'TotalFat_g': '0',
//         'TotalProtein_g': '0',
//         'TotalCarbs_g': '0',
//         'TotalPrepTime_min': '0',
//       });

//       final mt = d['mealType'] as String? ?? '';
//       groups[key]!['${mt}']               = d['name'] ?? '';
//       groups[key]!['${mt}Ingredients']    = d['ingredients'] ?? '';
//       groups[key]!['${mt}Calories']       = d['calories']?.toString() ?? '0';
//       groups[key]!['${mt}Fat_g']          = d['fat']?.toString() ?? '0';
//       groups[key]!['${mt}Protein_g']      = d['protein']?.toString() ?? '0';
//       groups[key]!['${mt}Carbs_g']        = d['carbs']?.toString() ?? '0';
//       groups[key]!['${mt}Preparation']    = d['preparation'] ?? '';
//       groups[key]!['${mt}PrepTime_min']   = d['prepTime']?.toString() ?? '15';
//       groups[key]!['${mt}ImageUrl']       = d['imageUrl'] ?? '';
//     }

//     // Compute totals
//     for (final m in groups.values) {
//       final totalCal = (int.tryParse(m['BreakfastCalories'] ?? '0') ?? 0) +
//           (int.tryParse(m['LunchCalories'] ?? '0') ?? 0) +
//           (int.tryParse(m['DinnerCalories'] ?? '0') ?? 0);
//       final totalFat = (double.tryParse(m['BreakfastFat_g'] ?? '0') ?? 0) +
//           (double.tryParse(m['LunchFat_g'] ?? '0') ?? 0) +
//           (double.tryParse(m['DinnerFat_g'] ?? '0') ?? 0);
//       final totalProt = (double.tryParse(m['BreakfastProtein_g'] ?? '0') ?? 0) +
//           (double.tryParse(m['LunchProtein_g'] ?? '0') ?? 0) +
//           (double.tryParse(m['DinnerProtein_g'] ?? '0') ?? 0);
//       final totalCarb = (double.tryParse(m['BreakfastCarbs_g'] ?? '0') ?? 0) +
//           (double.tryParse(m['LunchCarbs_g'] ?? '0') ?? 0) +
//           (double.tryParse(m['DinnerCarbs_g'] ?? '0') ?? 0);
//       final totalPrep = (int.tryParse(m['BreakfastPrepTime_min'] ?? '0') ?? 0) +
//           (int.tryParse(m['LunchPrepTime_min'] ?? '0') ?? 0) +
//           (int.tryParse(m['DinnerPrepTime_min'] ?? '0') ?? 0);
//       m['TotalCalories']    = totalCal.toString();
//       m['TotalFat_g']       = totalFat.toStringAsFixed(1);
//       m['TotalProtein_g']   = totalProt.toStringAsFixed(1);
//       m['TotalCarbs_g']     = totalCarb.toStringAsFixed(1);
//       m['TotalPrepTime_min']= totalPrep.toString();
//     }

//     return groups.values.toList();
//   }

//   static Future<List<Map<String, dynamic>>> _loadFromCsv() async {
//     print('Loading meals from CSV...');
//     final rawCsv = await rootBundle
//         .loadString('assets/data/period_diet_plan_detailed.csv');
//     final List<List<dynamic>> rows = const CsvToListConverter(
//       eol: '\n', shouldParseNumbers: false,
//     ).convert(rawCsv.replaceAll('\r\n', '\n'));
//     if (rows.isEmpty) return [];
//     final headers = rows[0].map((h) => h.toString().trim()).toList();
//     final List<Map<String, dynamic>> meals = [];
//     for (int i = 1; i < rows.length; i++) {
//       final row = rows[i];
//       if (row.isEmpty || row.length != headers.length) continue;
//       final Map<String, dynamic> meal = {};
//       for (int j = 0; j < headers.length; j++) {
//         meal[headers[j]] = row[j].toString().trim();
//       }
//       // No images from CSV
//       meal['BreakfastImageUrl'] = '';
//       meal['LunchImageUrl']     = '';
//       meal['DinnerImageUrl']    = '';
//       meals.add(meal);
//     }
//     _cachedMeals = meals;
//     return meals;
//   }

//   // ── FILTER — same meal all day ────────────────────────────────────────────
//   static Map<String, dynamic> filterMeal({
//     required List<Map<String, dynamic>> allMeals,
//     required String phase,
//     required String dietType,
//     required int wellnessScore,
//   }) {
//     final csvPhase = _normPhase(phase);
//     final bool preferIron = wellnessScore < 50;

//     var pool = allMeals
//         .where((m) => m['Phase'] == csvPhase && m['DietType'] == dietType)
//         .toList();
//     if (pool.isEmpty) pool = allMeals.where((m) => m['Phase'] == csvPhase).toList();
//     if (pool.isEmpty) pool = List.from(allMeals);

//     if (preferIron) {
//       final iron = pool.where((m) =>
//           (m['BreakfastIngredients'] as String).contains('(iron)') ||
//           (m['LunchIngredients'] as String).contains('(iron)') ||
//           (m['DinnerIngredients'] as String).contains('(iron)')).toList();
//       if (iron.isNotEmpty) pool = iron;
//     }

//     final seed = DateFormat('yyyyMMdd').format(DateTime.now()).hashCode.abs();
//     pool.shuffle(Random(seed));
//     return pool.first;
//   }

//   // Returns image URL from Firebase if available, null otherwise
//   static String? getMealImage(Map<String, dynamic> meal, String mealType) {
//     final url = meal['${mealType}ImageUrl'] as String? ?? '';
//     return url.isNotEmpty ? url : null;
//   }

//   static String _normPhase(String phase) {
//     if (phase.contains('Menstrual')) return 'Menstrual';
//     if (phase.contains('Follicular')) return 'Follicular';
//     if (phase.contains('Ovulation')) return 'Ovulation';
//     if (phase.contains('Luteal')) return 'Luteal';
//     return phase;
//   }

//   static int calcWellnessScore({
//     required double sleep,
//     required int water,
//     required int moodScore,
//     required List<String> symptoms,
//   }) {
//     int score = 0;
//     if (sleep >= 7 && sleep <= 9) score += 30;
//     else if (sleep >= 6) score += 20;
//     else if (sleep >= 5) score += 10;
//     if (water >= 8) score += 25;
//     else if (water >= 6) score += 18;
//     else if (water >= 4) score += 10;
//     else score += 5;
//     const mp = {1: 5, 2: 8, 3: 15, 4: 22, 5: 25};
//     score += mp[moodScore] ?? 10;
//     final heavy = symptoms.where((s) => s.toLowerCase() != 'none').length;
//     if (heavy == 0) score += 20;
//     else if (heavy == 1) score += 14;
//     else if (heavy == 2) score += 8;
//     else score += 3;
//     return score.clamp(0, 100);
//   }

//   static List<String> getSymptomTips(List<String> symptoms) {
//     const tips = {
//       'bloating':       '🌿 Avoid carbonated drinks. Try fennel seeds after meals.',
//       'cramps':         '🍫 Magnesium helps — try dark chocolate or a banana.',
//       'fatigue':        '🥬 Add iron-rich foods like spinach and lentils today.',
//       'mood swings':    '🕐 Eat every 3–4 hours to keep blood sugar stable.',
//       'headaches':      '💧 Stay hydrated. Never skip meals today.',
//       'tender breasts': '🧂 Reduce salt & avoid caffeine today.',
//       'spotting':       '🥦 Increase Vitamin K — leafy greens and broccoli.',
//     };
//     return symptoms.map((s) => tips[s.toLowerCase()]).whereType<String>().toList();
//   }

//   static Future<Map<String, dynamic>> fetchTodayWellness() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return {};
//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     final doc = await FirebaseFirestore.instance
//         .collection('users').doc(user.uid)
//         .collection('dailyWellness').doc(today).get();
//     return doc.data() ?? {};
//   }

//   static Future<Map<String, dynamic>> fetchUserProfile() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return {};
//     final doc = await FirebaseFirestore.instance
//         .collection('users').doc(user.uid).get();
//     return doc.data() ?? {};
//   }

//   static String mapDietType(String? pref) {
//     if (pref == 'NonVeg') return 'Non-Veg';
//     return 'Vegetarian';
//   }

//   static String getPhase(int cycleDay) {
//     if (cycleDay <= 5) return 'Menstrual';
//     if (cycleDay <= 13) return 'Follicular';
//     if (cycleDay <= 16) return 'Ovulation';
//     return 'Luteal';
//   }

//   static int calcCycleDay(List<DateTime> dates) {
//     if (dates.isEmpty) return 14;
//     dates.sort();
//     final day = DateTime.now().difference(dates.last).inDays + 1;
//     return ((day - 1) % 28) + 1;
//   }
// }

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class DietService {
  // ── CSV CACHE — loads once per session ────────────────────────────────────
  static List<Map<String, dynamic>>? _cachedMeals;

  // ── LOAD MEALS FROM CSV ───────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> loadMeals() async {
    if (_cachedMeals != null) return _cachedMeals!;

    final rawCsv = await rootBundle.loadString(
      'assets/data/period_diet_plan.csv',
    );

    final List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(rawCsv.replaceAll('\r\n', '\n'));

    if (rows.isEmpty) return [];

    final headers = rows[0].map((h) => h.toString().trim()).toList();

    final List<Map<String, dynamic>> meals = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length != headers.length) continue;
      final Map<String, dynamic> meal = {};
      for (int j = 0; j < headers.length; j++) {
        meal[headers[j]] = row[j].toString().trim();
      }
      meals.add(meal);
    }

    _cachedMeals = meals;
    return meals;
  }

  // ── FILTER MEALS ──────────────────────────────────────────────────────────
  static Map<String, dynamic> filterMeal({
    required List<Map<String, dynamic>> allMeals,
    required String phase,
    required String dietType,
    required int wellnessScore,
    int? forceSeed,
  }) {
    final csvPhase = _normPhase(phase);
    bool preferIron = wellnessScore < 50;

    var pool = allMeals
        .where((m) => m['Phase'] == csvPhase && m['DietType'] == dietType)
        .toList();

    if (pool.isEmpty) {
      pool = allMeals.where((m) => m['Phase'] == csvPhase).toList();
    }
    if (pool.isEmpty) pool = List.from(allMeals);

    if (preferIron) {
      final ironMeals = pool
          .where(
            (m) =>
                (m['BreakfastIngredients'] as String).contains('(iron)') ||
                (m['LunchIngredients'] as String).contains('(iron)') ||
                (m['DinnerIngredients'] as String).contains('(iron)'),
          )
          .toList();
      if (ironMeals.isNotEmpty) pool = ironMeals;
    }

    final seed =
        forceSeed ?? int.parse(DateFormat('yyyyMMdd').format(DateTime.now()));
    pool.shuffle(Random(seed));
    return pool.first;
  }

  static Future<int?> loadTodayMealSeed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .get();
    return (doc.data()?['mealSeed'] as num?)?.toInt();
  }

  static Future<void> saveTodayMealSeed(int seed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .set({'mealSeed': seed}, SetOptions(merge: true));
  }

  static String _normPhase(String phase) {
    if (phase.contains('Menstrual')) return 'Menstrual';
    if (phase.contains('Follicular')) return 'Follicular';
    if (phase.contains('Ovulation')) return 'Ovulation';
    if (phase.contains('Luteal')) return 'Luteal';
    return phase;
  }

  // ── WELLNESS SCORE CALCULATOR ─────────────────────────────────────────────
  static int calcWellnessScore({
    required double sleep,
    required int water,
    required int moodScore,
    required List<String> symptoms,
  }) {
    int score = 0;
    if (sleep >= 7 && sleep <= 9)
      score += 30;
    else if (sleep >= 6)
      score += 20;
    else if (sleep >= 5)
      score += 10;
    if (water >= 8)
      score += 25;
    else if (water >= 6)
      score += 18;
    else if (water >= 4)
      score += 10;
    else
      score += 5;
    const mp = {1: 5, 2: 8, 3: 15, 4: 22, 5: 25};
    score += mp[moodScore] ?? 10;
    final heavy = symptoms.where((s) => s.toLowerCase() != 'none').length;
    if (heavy == 0)
      score += 20;
    else if (heavy == 1)
      score += 14;
    else if (heavy == 2)
      score += 8;
    else
      score += 3;
    return score.clamp(0, 100);
  }

  // ── SYMPTOM TIPS ──────────────────────────────────────────────────────────
  static List<String> getSymptomTips(List<String> symptoms) {
    const tips = {
      'bloating': '🌿 Avoid carbonated drinks. Try fennel seeds after meals.',
      'cramps': '🍫 Magnesium helps — try dark chocolate or a banana.',
      'fatigue': '🥬 Add iron-rich foods like spinach and lentils today.',
      'mood swings': '🕐 Eat every 3–4 hours to keep blood sugar stable.',
      'headaches': '💧 Stay hydrated. Never skip meals today.',
      'tender breasts': '🧂 Reduce salt & avoid caffeine today.',
      'spotting': '🥦 Increase Vitamin K — leafy greens and broccoli.',
    };
    return symptoms
        .map((s) => tips[s.toLowerCase()])
        .whereType<String>()
        .toList();
  }

  // ── FETCH TODAY'S WELLNESS FROM FIRESTORE ─────────────────────────────────
  static Future<Map<String, dynamic>> fetchTodayWellness() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .get();
    return doc.data() ?? {};
  }

  // ── FETCH USER PROFILE ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data() ?? {};
  }

  // ── MAP DIET PREFERENCE ───────────────────────────────────────────────────
  static String mapDietType(String? pref) {
    if (pref == 'NonVeg') return 'Non-Veg';
    return 'Vegetarian';
  }

  // ── CYCLE PHASE FROM DAY ──────────────────────────────────────────────────
  static String getPhase(int cycleDay) {
    if (cycleDay <= 5) return 'Menstrual';
    if (cycleDay <= 13) return 'Follicular';
    if (cycleDay <= 16) return 'Ovulation';
    return 'Luteal';
  }

  // ── CYCLE DAY FROM PERIOD DATES ───────────────────────────────────────────
  static int calcCycleDay(List<DateTime> dates) {
    if (dates.isEmpty) return 14;
    dates.sort();
    final day = DateTime.now().difference(dates.last).inDays + 1;
    return ((day - 1) % 28) + 1;
  }

  // ── FETCH IMAGE URL FROM UNSPLASH API ─────────────────────────────────────
  // Tries Unsplash first. If it fails (401 = email not confirmed, or any
  // network error), falls back to a curated static food image from picsum
  // so the UI always shows SOMETHING beautiful.
  static Future<String?> fetchMealImageUrl(String dishName) async {
    // ── 1. Try Unsplash ───────────────────────────────────────────────────
    try {
      const accessKey = 'aDIf1SSeSsBRlj58lhCYs1zwS8v_qKsyTN2ZaiyNgkE';
      final query = Uri.encodeComponent('$dishName Indian food');
      final uri = Uri.parse(
        'https://api.unsplash.com/photos/random'
        '?query=$query&orientation=landscape&client_id=$accessKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      debugPrint('🖼️ Unsplash status for "$dishName": ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final url =
            (data['urls'] as Map<String, dynamic>)['regular'] as String?;
        debugPrint('✅ Unsplash URL: $url');
        return url;
      }

      debugPrint(
        '⚠️ Unsplash failed (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Unsplash exception: $e');
    }

    // ── 2. Fallback: Curated food images from Foodish API (free, no key) ──
    // Returns a random Indian food dish image every time — no auth needed.
    try {
      final uri = Uri.parse('https://foodish-api.com/api/');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final url = data['image'] as String?;
        debugPrint('🍛 Foodish fallback URL: $url');
        return url;
      }
    } catch (e) {
      debugPrint('❌ Foodish fallback exception: $e');
    }

    // ── 3. Last resort: beautiful food photo from Picsum (always works) ───
    // Uses a seed based on dish name so same dish always gets same image
    final seed = dishName.hashCode.abs() % 1000;
    final fallbackUrl = 'https://picsum.photos/seed/$seed/600/400';
    debugPrint('🎲 Picsum last-resort: $fallbackUrl');
    return fallbackUrl;
  }
}
