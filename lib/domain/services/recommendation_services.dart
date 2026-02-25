import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

class RecommendationService {
  // ── CSV CACHE — only reads file once per app session ──────────────────────
  static List<Map<String, dynamic>>? _cachedWorkouts;

  // ── LOAD WORKOUTS FROM CSV ─────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> loadWorkouts() async {
    if (_cachedWorkouts != null) return _cachedWorkouts!;

    final rawCsv = await rootBundle.loadString('assets/data/zyra_workouts.csv');

    final List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(rawCsv.replaceAll('\r\n', '\n'));

    if (rows.isEmpty) return [];

    final headers = rows[0].map((h) => h.toString().trim()).toList();

    final List<Map<String, dynamic>> workouts = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      if (row.length != headers.length) continue;

      final Map<String, dynamic> workout = {};
      for (int j = 0; j < headers.length; j++) {
        workout[headers[j]] = row[j].toString().trim();
      }
      workouts.add(workout);
    }

    _cachedWorkouts = workouts;
    return workouts;
  }

  // ── FILTER WORKOUTS FROM CSV ───────────────────────────────────────────────
  static List<Map<String, dynamic>> filterWorkouts({
    required List<Map<String, dynamic>> allWorkouts,
    required String phase,
    required String level,
    required String intensity,
    required int dayOfCycle,
  }) {
    // CSV uses 'Ovulatory' not 'Ovulation'
    final csvPhase = phase == 'Ovulation' ? 'Ovulatory' : phase;
    final dayInPhase = ((dayOfCycle - 1) % 7) + 1;

    // Try exact match: phase + level + intensity + day
    var filtered = allWorkouts.where((w) =>
        w['phase'] == csvPhase &&
        w['level'] == level &&
        w['intensity'] == intensity &&
        w['day'] == dayInPhase.toString()).toList();

    // Relax day
    if (filtered.isEmpty) {
      filtered = allWorkouts.where((w) =>
          w['phase'] == csvPhase &&
          w['level'] == level &&
          w['intensity'] == intensity).toList();
    }

    // Relax intensity
    if (filtered.isEmpty) {
      filtered = allWorkouts.where((w) =>
          w['phase'] == csvPhase &&
          w['level'] == level).toList();
    }

    // Relax level
    if (filtered.isEmpty) {
      filtered = allWorkouts.where((w) =>
          w['phase'] == csvPhase).toList();
    }

    // Last resort
    if (filtered.isEmpty) {
      filtered = allWorkouts
          .where((w) => w['intensity'] == 'Low')
          .toList();
    }

    filtered.shuffle(); // variety every day
    return filtered.take(6).toList();
  }

  // ── CYCLE PHASE CALCULATOR ────────────────────────────────────────────────
  static String getPhase(int cycleDay) {
    if (cycleDay <= 5) return 'Menstrual';
    if (cycleDay <= 13) return 'Follicular';
    if (cycleDay <= 16) return 'Ovulatory';
    return 'Luteal';
  }

  // ── DIET TYPE MAPPER ──────────────────────────────────────────────────────
  static String mapDietType(String? pref) {
    if (pref == 'NonVeg') return 'Non-Veg';
    return 'Vegetarian';
  }

  // ── FITNESS LEVEL FROM WELLNESS SCORE + SYMPTOMS ─────────────────────────
  static String getFitnessLevel(int wellnessScore, List<String> symptoms) {
    final heavy = symptoms.where((s) => s.toLowerCase() != 'none').length;
    if (wellnessScore < 35 || heavy >= 3) return 'Beginner';
    if (wellnessScore < 65 || heavy >= 1) return 'Intermediate';
    return 'Advanced';
  }

  // ── INTENSITY FROM MOOD + PHASE ───────────────────────────────────────────
  static String getIntensity(String mood, String phase) {
    const moodRank = {
      'Happy': 2, 'Calm': 1, 'Neutral': 1,
      'Anxious': 0, 'Sad': 0, 'Angry': 1
    };
    const phaseMax = {
      'Menstrual': 0, 'Follicular': 2,
      'Ovulatory': 2, 'Luteal': 1
    };
    final m = moodRank[mood] ?? 1;
    final p = phaseMax[phase] ?? 1;
    final rank = m < p ? m : p;
    return ['Low', 'Medium', 'High'][rank];
  }

  // ── FETCH TODAY'S WELLNESS DATA ───────────────────────────────────────────
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
    if (!doc.exists) return {};
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
    if (!doc.exists) return {};
    return doc.data() ?? {};
  }

  // ── MOOD SCORE → STRING ───────────────────────────────────────────────────
  static String moodScoreToString(int score) {
    switch (score) {
      case 1: return 'Sad';
      case 2: return 'Anxious';
      case 3: return 'Neutral';
      case 4: return 'Calm';
      case 5: return 'Happy';
      default: return 'Neutral';
    }
  }

  // ── SYMPTOM TIPS FOR DIET ─────────────────────────────────────────────────
  static List<String> getSymptomTips(List<String> symptoms) {
    const tips = {
      'bloating': 'Avoid carbonated drinks. Try fennel seeds after meals.',
      'cramps': 'Increase magnesium — dark chocolate or banana helps.',
      'fatigue': 'Add iron-rich foods like spinach and lentils.',
      'mood swings': 'Eat every 3–4 hours to keep blood sugar stable.',
      'headaches': 'Stay hydrated. Never skip meals today.',
      'tender breasts': 'Reduce salt intake. Avoid caffeine today.',
      'spotting': 'Increase Vitamin K — leafy greens and broccoli.',
    };
    return symptoms
        .map((s) => tips[s.toLowerCase()])
        .whereType<String>()
        .toList();
  }
  // ── STREAK MANAGEMENT ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'streak': 0, 'level': 'Beginner', 'changed': false};

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data() ?? {};
    final lastDate = data['lastWorkoutDate'] as String? ?? '';
    int streak = (data['workoutStreak'] as num?)?.toInt() ?? 0;
    String level = data['workoutLevel'] as String? ?? 'Beginner';

    // Already logged today — return current state unchanged
    if (lastDate == today) {
      return {'streak': streak, 'level': level, 'changed': false};
    }

    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    if (lastDate == yesterday) {
      // Came yesterday — streak continues
      streak += 1;
    } else if (lastDate.isEmpty) {
      // First time ever
      streak = 1;
    } else {
      // Missed more than 1 day — check how many
      final lastDateTime = DateFormat('yyyy-MM-dd').parse(lastDate);
      final daysMissed = DateTime.now().difference(lastDateTime).inDays;

      if (daysMissed >= 14) {
        // Missed 2+ weeks — downgrade one level
        final oldLevel = level;
        level = _downgradeLevel(level);
        streak = 1;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'workoutStreak': streak,
          'lastWorkoutDate': today,
          'workoutLevel': level,
        });

        return {
          'streak': streak,
          'level': level,
          'changed': level != oldLevel,
          'upgraded': false,
          'downgraded': true,
          'message': level != oldLevel
              ? 'Welcome back! You have been moved to $level. Keep going 💪'
              : 'Welcome back! Keep your streak going 🔥',
        };
      } else {
        // Missed less than 2 weeks — reset streak, keep level
        streak = 1;
      }
    }

    // Check for upgrade after streak reaches 14
    final oldLevel = level;
    if (streak >= 14) {
      level = _upgradeLevel(level);
    }
    final upgraded = level != oldLevel;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'workoutStreak': streak,
      'lastWorkoutDate': today,
      'workoutLevel': level,
    });

    return {
      'streak': streak,
      'level': level,
      'changed': upgraded,
      'upgraded': upgraded,
      'downgraded': false,
      'message': upgraded
          ? '🎉 You have been upgraded to $level! $streak days strong!'
          : '',
    };
  }

  static String _upgradeLevel(String current) {
    if (current == 'Beginner') return 'Intermediate';
    if (current == 'Intermediate') return 'Advanced';
    return 'Advanced';
  }

  static String _downgradeLevel(String current) {
    if (current == 'Advanced') return 'Intermediate';
    if (current == 'Intermediate') return 'Beginner';
    return 'Beginner';
  }

}
  