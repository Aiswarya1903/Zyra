import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class RecommendationService {
  // ── CSV CACHE — reads once per session ────────────────────────────────────
  static List<Map<String, dynamic>>? _cachedWorkouts;

  // ── VALID COMBOS IN CSV ───────────────────────────────────────────────────
  static const Map<String, Map<String, List<String>>> _validCombos = {
    'Menstrual': {
      'Beginner': ['Low'],
      'Intermediate': ['Medium'],
      'Advanced': ['High'],
    },
    'Follicular': {
      'Beginner': ['Low', 'Medium'],
      'Intermediate': ['Medium'],
      'Advanced': ['High'],
    },
    'Ovulatory': {
      'Beginner': ['High'],
      'Intermediate': ['High'],
      'Advanced': ['High'],
    },
    'Luteal': {
      'Beginner': ['Low', 'Medium'],
      'Intermediate': ['Medium'],
      'Advanced': ['High'],
    },
  };

  // ── MUSCLE GROUPS SAFE/PREFERRED FOR EACH SYMPTOM ─────────────────────────
  static const Map<String, Map<String, List<String>>> _symptomMuscleRules = {
    'cramps': {
      'avoid': ['Core', 'Abs', 'Obliques'],
      'prefer': ['Mobility', 'Flexibility', 'Relaxation', 'Hips'],
    },
    'bloating': {
      'avoid': ['Core', 'Abs'],
      'prefer': ['Flexibility', 'Mobility', 'Relaxation', 'Cardio'],
    },
    'fatigue': {
      'avoid': ['Cardio', 'Full Body'],
      'prefer': ['Mobility', 'Flexibility', 'Relaxation', 'Spine'],
    },
    'headaches': {
      'avoid': ['Cardio', 'Full Body', 'Shoulders'],
      'prefer': ['Mobility', 'Relaxation', 'Flexibility'],
    },
    'mood swings': {
      'avoid': [],
      'prefer': ['Cardio', 'Full Body', 'Core'],
    },
    'back pain': {
      'avoid': ['Lower Back', 'Spine'],
      'prefer': ['Flexibility', 'Mobility', 'Hips', 'Glutes'],
    },
    'tender breasts': {
      'avoid': ['Chest', 'Shoulders'],
      'prefer': ['Legs', 'Glutes', 'Mobility'],
    },
    'spotting': {
      'avoid': ['Core', 'Abs'],
      'prefer': ['Mobility', 'Flexibility', 'Relaxation'],
    },
  };

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
      if (row.isEmpty || row.length != headers.length) continue;
      final Map<String, dynamic> workout = {};
      for (int j = 0; j < headers.length; j++) {
        workout[headers[j]] = row[j].toString().trim();
      }
      workouts.add(workout);
    }

    _cachedWorkouts = workouts;
    return workouts;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── MAIN FILTER FUNCTION — WITH ENHANCED SLEEP LOGIC ──────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  static List<Map<String, dynamic>> filterWorkouts({
    required List<Map<String, dynamic>> allWorkouts,
    required String phase,
    required String level,
    required String mood,
    List<String> symptoms = const [],
    double sleepHours = 7,
    int waterGlasses = 0,
  }) {
    // ── STEP 1: Normalize phase name ─────────────────────────────────────
    final csvPhase = _normPhase(phase);

    // ── STEP 2: Determine base intensity from mood + phase ───────────────
    final baseIntensity = _getIntensityFromMoodAndPhase(mood, csvPhase);

    // ── STEP 3: Adjust intensity based on symptoms AND SLEEP ─────────────
    final adjustedIntensity = _adjustIntensityForSymptoms(
      baseIntensity, symptoms, sleepHours, waterGlasses,
    );

    // ── STEP 4: Get ALL workouts for this phase + level ─────────────────
    List<Map<String, dynamic>> phaseWorkouts = allWorkouts.where((w) =>
      w['phase'] == csvPhase && w['level'] == level
    ).toList();

    if (phaseWorkouts.isEmpty) {
      phaseWorkouts = allWorkouts.where((w) => w['phase'] == csvPhase).toList();
    }

    if (phaseWorkouts.isEmpty) {
      phaseWorkouts = allWorkouts;
    }

    // ── STEP 5: Score each workout based on symptoms AND SLEEP ───────────
    final scored = _scoreWorkoutsBySymptoms(
      phaseWorkouts, symptoms, adjustedIntensity, sleepHours, waterGlasses,
    );

    // ── STEP 6: Select best 6 with variety ──────────────────────────────
    final selected = _selectBestVaried(scored, count: 6);

    return selected;
  }

  // ── HELPER: Calculate sleep quality score ─────────────────────────────────
  static int _getSleepQualityScore(double sleepHours) {
    if (sleepHours >= 8) return 3;      // Excellent sleep
    if (sleepHours >= 7) return 2;      // Good sleep
    if (sleepHours >= 6) return 1;      // Okay sleep
    if (sleepHours >= 5) return 0;      // Poor sleep
    return -1;                           // Very poor sleep (<5 hours)
  }

  // ── HELPER: Get sleep message for UI ──────────────────────────────────────
  static String getSleepMessage(double sleepHours) {
    if (sleepHours >= 8) return "You're well-rested! Ready for an energizing workout 💪";
    if (sleepHours >= 7) return "Good sleep! You have solid energy today ✨";
    if (sleepHours >= 6) return "Okay sleep. Listen to your body during workout 🌱";
    if (sleepHours >= 5) return "You slept less than ideal. Take it easy today 🌙";
    return "You barely slept. Today is a rest & recovery day 🧘";
  }

  // ── HELPER: Check if rest day is recommended ──────────────────────────────
  static bool isRestDayRecommended(double sleepHours, List<String> symptoms) {
    if (sleepHours < 4) return true;
    if (sleepHours < 5) {
      final severeSymptoms = ['cramps', 'fatigue', 'headaches', 'back pain'];
      final hasSevere = symptoms.any((s) =>
        severeSymptoms.contains(s.toLowerCase().trim())
      );
      return hasSevere;
    }
    return false;
  }

  // ── HELPER: Get intensity from mood + phase ───────────────────────────────
  static String _getIntensityFromMoodAndPhase(String mood, String phase) {
    const Map<String, int> moodEnergy = {
      'Sad': 0,
      'Anxious': 0,
      'Neutral': 1,
      'Calm': 1,
      'Happy': 2,
    };

    const Map<String, int> phaseEnergy = {
      'Menstrual': 0,
      'Luteal': 1,
      'Follicular': 2,
      'Ovulatory': 2,
    };

    final moodVal = moodEnergy[mood] ?? 1;
    final phaseVal = phaseEnergy[phase] ?? 1;
    final combined = moodVal < phaseVal ? moodVal : phaseVal;

    switch (combined) {
      case 0: return 'Low';
      case 1: return 'Medium';
      case 2: return 'High';
      default: return 'Medium';
    }
  }

  // ── HELPER: Adjust intensity based on symptoms AND SLEEP ──────────────────
  static String _adjustIntensityForSymptoms(
    String baseIntensity,
    List<String> symptoms,
    double sleepHours,
    int waterGlasses,
  ) {
    final activeSymptoms = symptoms.where((s) =>
      s.toLowerCase() != 'none' && s.isNotEmpty
    ).length;

    final severeSymptoms = ['cramps', 'fatigue', 'headaches', 'back pain'];
    final hasSevere = symptoms.any((s) =>
      severeSymptoms.contains(s.toLowerCase().trim())
    );

    const rank = {'Low': 0, 'Medium': 1, 'High': 2};
    final rankReverse = ['Low', 'Medium', 'High'];

    int currentRank = rank[baseIntensity] ?? 1;

    // ── SLEEP-BASED ADJUSTMENTS (AGGRESSIVE) ────────────────────────────
    if (sleepHours < 5) {
      // Very poor sleep (<5 hours) → Force LOW intensity
      currentRank = 0;
    } else if (sleepHours < 6) {
      // Poor sleep (5-6 hours) → Drop by 2 levels if possible
      currentRank = (currentRank - 2).clamp(0, 2);
    } else if (sleepHours < 7) {
      // Okay sleep (6-7 hours) → Drop by 1 level
      currentRank = (currentRank - 1).clamp(0, 2);
    }
    // Sleep 7+ hours → no sleep-based reduction

    // ── DEHYDRATION ADJUSTMENT ────────────────────────────────────────
    if (waterGlasses < 3) {
      currentRank = (currentRank - 1).clamp(0, 2);
    }

    // ── SYMPTOM-BASED ADJUSTMENTS ─────────────────────────────────────
    if (activeSymptoms >= 3) {
      currentRank = (currentRank - 1).clamp(0, 2);
    }

    if (hasSevere && currentRank > 1) {
      currentRank = 1; // Max Medium
    }

    final severeCount = symptoms.where((s) =>
      severeSymptoms.contains(s.toLowerCase().trim())
    ).length;

    if (severeCount >= 2) {
      currentRank = 0; // Force Low
    }

    return rankReverse[currentRank];
  }

  // ── HELPER: Score workouts based on symptoms AND SLEEP ────────────────────
  static List<_ScoredWorkout> _scoreWorkoutsBySymptoms(
    List<Map<String, dynamic>> workouts,
    List<String> symptoms,
    String targetIntensity,
    double sleepHours,
    int waterGlasses,
  ) {
    final activeSymptoms = symptoms.where((s) =>
      s.toLowerCase() != 'none' && s.isNotEmpty
    ).length;

    final int sleepQuality = _getSleepQualityScore(sleepHours);

    // Build avoid/prefer sets from symptoms
    final Set<String> avoidMuscles = {};
    final Set<String> preferMuscles = {};

    for (final symptom in symptoms) {
      final s = symptom.toLowerCase().trim();
      if (s == 'none' || s.isEmpty) continue;
      final rules = _symptomMuscleRules[s];
      if (rules != null) {
        avoidMuscles.addAll(rules['avoid'] ?? []);
        preferMuscles.addAll(rules['prefer'] ?? []);
      }
    }

    // ── SLEEP-BASED PREFERENCE (MUCH STRONGER NOW) ────────────────────
    if (sleepHours < 5) {
      // Very poor sleep → STRONGLY prefer only the gentlest exercises
      preferMuscles.clear();
      preferMuscles.addAll(['Mobility', 'Flexibility', 'Relaxation']);
      avoidMuscles.addAll(['Cardio', 'Full Body', 'Core', 'Legs', 'Back', 'Chest', 'Shoulders']);
    } else if (sleepHours < 6) {
      // Poor sleep → Strongly prefer gentle, avoid intense
      preferMuscles.addAll(['Mobility', 'Flexibility', 'Relaxation', 'Hips', 'Spine']);
      avoidMuscles.addAll(['Cardio', 'Full Body']);
    } else if (sleepHours < 7) {
      // Okay sleep → Slightly prefer gentle
      preferMuscles.addAll(['Mobility', 'Flexibility', 'Relaxation']);
    }

    // ── DEHYDRATION ADJUSTMENT ────────────────────────────────────────
    if (waterGlasses < 2) {
      preferMuscles.addAll(['Mobility', 'Flexibility', 'Relaxation']);
      avoidMuscles.addAll(['Cardio', 'Full Body']);
    }

    // Score each workout
    final List<_ScoredWorkout> scored = [];

    for (final workout in workouts) {
      final muscle = workout['muscleGroup']?.toString() ?? '';
      final intensity = workout['intensity']?.toString() ?? 'Medium';

      int score = 50; // Base score

      // ── INTENSITY MATCHING WITH SLEEP CONSIDERATION ─────────────────
      const rank = {'Low': 0, 'Medium': 1, 'High': 2};
      final targetRank = rank[targetIntensity] ?? 1;
      final workoutRank = rank[intensity] ?? 1;

      if (intensity == targetIntensity) {
        score += 30;
      } else {
        // When sleep is poor, gentler workouts get MUCH higher scores
        if (sleepHours < 6) {
          if (workoutRank < targetRank) {
            score += 40; // Much bigger bonus for gentler workouts
          } else if (workoutRank > targetRank) {
            score -= 30; // Bigger penalty for intense workouts
          }
        } else {
          // Normal scoring
          if (workoutRank < targetRank && activeSymptoms > 0) {
            score += 15;
          } else if (workoutRank > targetRank) {
            score -= 10;
          }
        }
      }

      // ── SYMPTOM MATCHING ──────────────────────────────────────────
      if (avoidMuscles.contains(muscle)) {
        score -= 80; // Even stronger avoidance
      }

      if (preferMuscles.contains(muscle)) {
        score += 60; // Even stronger preference
      }

      // ── SLEEP-BASED DIRECT SCORING ─────────────────────────────
      if (sleepHours < 5) {
        // Very poor sleep: Only mobility/flexibility/relaxation should have positive scores
        if (!['Mobility', 'Flexibility', 'Relaxation'].contains(muscle)) {
          score -= 100; // Make everything else very unlikely
        }
      }

      // ── SLEEP QUALITY BONUS ──────────────────────────────────────
      // Bonus for matching intensity to sleep quality
      if (sleepQuality <= 0 && intensity == 'Low') {
        score += 20; // Bonus for choosing Low intensity when sleep is poor
      }
      if (sleepQuality >= 3 && intensity == 'High') {
        score += 15; // Bonus for choosing High intensity when sleep is excellent
      }

      scored.add(_ScoredWorkout(workout, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  // ── HELPER: Select best varied workouts ───────────────────────────────────
  static List<Map<String, dynamic>> _selectBestVaried(
    List<_ScoredWorkout> scored, {
    required int count,
  }) {
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final rng = Random(int.tryParse(today) ?? 0);

    final selected = <Map<String, dynamic>>[];
    final usedMuscles = <String>{};

    // PASS 1: One from each muscle group (highest score first)
    for (final sw in scored) {
      if (selected.length >= count) break;
      final muscle = sw.workout['muscleGroup']?.toString() ?? '';
      if (!usedMuscles.contains(muscle)) {
        selected.add(sw.workout);
        usedMuscles.add(muscle);
      }
    }

    // PASS 2: Fill remaining with top scores
    if (selected.length < count) {
      final remaining = scored
          .where((sw) => !selected.contains(sw.workout))
          .toList();

      remaining.sort((a, b) => b.score.compareTo(a.score));

      for (final sw in remaining) {
        if (selected.length >= count) break;
        selected.add(sw.workout);
      }
    }

    selected.shuffle(rng);
    return selected;
  }

  // ── STEP 2: Resolve to a valid intensity that exists in CSV ──────────────
  static String _resolveIntensity(
    String phase,
    String level,
    String hintIntensity,
    int wellnessScore,
    List<String> symptoms,
  ) {
    final validForLevel = _validCombos[phase]?[level] ?? ['Low'];

    final heavySymptoms = symptoms.where((s) =>
      s.toLowerCase() != 'none' && s.isNotEmpty
    ).length;

    if (wellnessScore < 35 || heavySymptoms >= 3) {
      return validForLevel.first;
    }

    if (validForLevel.contains(hintIntensity)) return hintIntensity;

    if (phase == 'Ovulatory') return 'High';

    const rank = {'Low': 0, 'Medium': 1, 'High': 2};
    validForLevel.sort((a, b) =>
        (rank[a]! - (rank[hintIntensity] ?? 1)).abs()
            .compareTo((rank[b]! - (rank[hintIntensity] ?? 1)).abs()));
    return validForLevel.first;
  }

  // ── STEP 3: Get pool matching phase+level+intensity+day with fallbacks ────
  static List<Map<String, dynamic>> _poolForDay(
    List<Map<String, dynamic>> all,
    String phase,
    String level,
    String intensity,
    int cycleDay,
  ) {
    var pool = all.where((w) =>
      w['phase'] == phase &&
      w['level'] == level &&
      w['intensity'] == intensity &&
      w['day'] == cycleDay.toString()
    ).toList();

    if (pool.length >= 4) return pool;

    pool = all.where((w) =>
      w['phase'] == phase &&
      w['level'] == level &&
      w['intensity'] == intensity
    ).toList();

    if (pool.length >= 4) return pool;

    pool = all.where((w) =>
      w['phase'] == phase && w['level'] == level
    ).toList();

    if (pool.length >= 4) return pool;

    pool = all.where((w) => w['phase'] == phase).toList();

    if (pool.length >= 4) return pool;

    return all.where((w) => w['intensity'] == 'Low').toList();
  }

  // ── STEP 4: Score exercises based on symptoms + wellness ─────────────────
  static List<_ScoredExercise> _scoreExercises(
    List<Map<String, dynamic>> pool,
    List<String> symptoms,
    double sleepHours,
    int waterGlasses,
  ) {
    final Set<String> avoidMuscles = {};
    final Set<String> preferMuscles = {};

    for (final symptom in symptoms) {
      final s = symptom.toLowerCase().trim();
      if (s == 'none' || s.isEmpty) continue;
      final rules = _symptomMuscleRules[s];
      if (rules != null) {
        avoidMuscles.addAll(rules['avoid'] ?? []);
        preferMuscles.addAll(rules['prefer'] ?? []);
      }
    }

    bool needsGentle = sleepHours < 5 || waterGlasses < 2;
    if (needsGentle) {
      preferMuscles.addAll(['Mobility', 'Flexibility', 'Relaxation']);
      avoidMuscles.addAll(['Cardio', 'Full Body']);
    }

    return pool.map((exercise) {
      final muscle = exercise['muscleGroup']?.toString() ?? '';
      int score = 100;

      if (avoidMuscles.contains(muscle)) score -= 80;
      if (preferMuscles.contains(muscle)) score += 40;

      return _ScoredExercise(exercise, score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  // ── STEP 5: Pick exercises ensuring muscle group variety ──────────────────
  static List<Map<String, dynamic>> _selectWithVariety(
    List<_ScoredExercise> scored, {
    required int count,
  }) {
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final rng = Random(int.tryParse(today) ?? 0);

    final selected = <Map<String, dynamic>>[];
    final usedMuscles = <String>{};

    for (final se in scored) {
      if (selected.length >= count) break;
      final muscle = se.exercise['muscleGroup']?.toString() ?? '';
      if (!usedMuscles.contains(muscle)) {
        selected.add(se.exercise);
        usedMuscles.add(muscle);
      }
    }

    final remaining = scored
        .where((se) => !selected.contains(se.exercise))
        .toList();
    remaining.shuffle(rng);
    for (final se in remaining) {
      if (selected.length >= count) break;
      selected.add(se.exercise);
    }

    selected.shuffle(rng);
    return selected;
  }

  // ── NORMALISE PHASE NAME ──────────────────────────────────────────────────
  static String _normPhase(String phase) {
    switch (phase.replaceAll(' Phase', '').trim()) {
      case 'Menstrual': return 'Menstrual';
      case 'Follicular': return 'Follicular';
      case 'Ovulation':
      case 'Ovulatory': return 'Ovulatory';
      case 'Luteal': return 'Luteal';
      default: return 'Follicular';
    }
  }

  // ── CYCLE PHASE FROM DAY ──────────────────────────────────────────────────
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
    final heavy = symptoms.where((s) =>
      s.toLowerCase() != 'none' && s.isNotEmpty
    ).length;
    if (wellnessScore < 35 || heavy >= 3) return 'Beginner';
    if (wellnessScore < 65 || heavy >= 1) return 'Intermediate';
    return 'Advanced';
  }

  // ── INTENSITY FROM MOOD + PHASE (hint — not final) ────────────────────────
  static String getIntensity(String mood, String phase) {
    const moodRank = {
      'Happy': 2,
      'Calm': 1,
      'Neutral': 1,
      'Anxious': 0,
      'Sad': 0,
      'Angry': 1
    };
    const phaseMax = {
      'Menstrual': 0,
      'Follicular': 2,
      'Ovulatory': 2,
      'Luteal': 1
    };
    final m = moodRank[mood] ?? 1;
    final p = phaseMax[phase] ?? 1;
    return ['Low', 'Medium', 'High'][m < p ? m : p];
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
    return doc.exists ? (doc.data() ?? {}) : {};
  }

  // ── FETCH USER PROFILE ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.exists ? (doc.data() ?? {}) : {};
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
      'back pain': 'Anti-inflammatory foods like turmeric and ginger help.',
    };
    return symptoms
        .map((s) => tips[s.toLowerCase().trim()])
        .whereType<String>()
        .toList();
  }

  // ── STREAK MANAGEMENT ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'streak': 0, 'level': 'Beginner', 'changed': false};
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data() ?? {};
    final lastDate = data['lastWorkoutDate'] as String? ?? '';
    int streak = (data['workoutStreak'] as num?)?.toInt() ?? 0;
    String level = data['workoutLevel'] as String? ?? 'Beginner';

    if (lastDate == today) {
      return {'streak': streak, 'level': level, 'changed': false};
    }

    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    if (lastDate == yesterday) {
      streak += 1;
    } else if (lastDate.isEmpty) {
      streak = 1;
    } else {
      final lastDateTime = DateFormat('yyyy-MM-dd').parse(lastDate);
      final daysMissed = DateTime.now().difference(lastDateTime).inDays;

      if (daysMissed >= 14) {
        final oldLevel = level;
        level = _downgradeLevel(level);
        streak = 1;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'workoutStreak': streak,
          'lastWorkoutDate': today,
          'workoutLevel': level
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
        streak = 1;
      }
    }

    final oldLevel = level;
    if (streak >= 14) level = _upgradeLevel(level);
    final upgraded = level != oldLevel;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'workoutStreak': streak,
      'lastWorkoutDate': today,
      'workoutLevel': level
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

  static String _upgradeLevel(String c) {
    if (c == 'Beginner') return 'Intermediate';
    if (c == 'Intermediate') return 'Advanced';
    return 'Advanced';
  }

  static String _downgradeLevel(String c) {
    if (c == 'Advanced') return 'Intermediate';
    if (c == 'Intermediate') return 'Beginner';
    return 'Beginner';
  }
}

// ── Helper class for scoring exercises (old method) ─────────────────────────
class _ScoredExercise {
  final Map<String, dynamic> exercise;
  final int score;
  const _ScoredExercise(this.exercise, this.score);
}

// ── Helper class for scoring workouts (new method) ─────────────────────────
class _ScoredWorkout {
  final Map<String, dynamic> workout;
  final int score;
  const _ScoredWorkout(this.workout, this.score);
}