import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/services/recommendation_services.dart';
import 'package:zyra_final/repository/screens/home/workout_active_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool isLoading = true;
  int cycleDay = 1;
  String phase = 'Follicular';
  int wellnessScore = 60;
  String mood = 'Neutral';
  List<String> symptoms = [];
  double sleepHours = 7;
  int waterGlasses = 0;
  int streak = 0;
  String streakLevel = 'Beginner';
  String level = 'Beginner';
  String intensity = 'Medium';
  bool isRestDay = false;
  String phaseMessage = '';
  bool _levelChanged = false;
  String _levelChangeMessage = '';
  bool _levelUpgraded = false;
  List<Map<String, dynamic>> exercises = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final baseLevel = userData['baseWorkoutLevel'] as String? ?? 'Beginner';
      streak = (userData['workoutStreak'] as num?)?.toInt() ?? 0;
      streakLevel = userData['workoutLevel'] as String? ?? baseLevel;
      cycleDay = (userData['cycleDay'] as num?)?.toInt() ?? 14;
      final rawPhase =
          userData['currentPhase'] as String? ?? 'Follicular Phase';
      phase = rawPhase.replaceAll(' Phase', '').trim();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final wellnessDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyWellness')
          .doc(today)
          .get();
      final w = wellnessDoc.data() ?? {};

      final moodScore = (w['mood'] as num?)?.toInt() ?? 3;
      waterGlasses = (w['water'] as num?)?.toInt() ?? 0;
      sleepHours = (w['sleep'] as num?)?.toDouble() ?? 0.0;
      symptoms = List<String>.from(w['symptoms'] ?? []);
      mood = _moodFromScore(moodScore);

      wellnessScore = _calcWellnessScore(
        sleepHours,
        waterGlasses,
        moodScore,
        symptoms,
      );

      final streakResult = await RecommendationService.updateStreak();
      streak = streakResult['streak'] ?? streak;
      String updatedLevel = streakResult['level'] ?? streakLevel;
      streakLevel = _maxLevel(baseLevel, updatedLevel);
      _levelChanged = streakResult['changed'] ?? false;
      _levelChangeMessage = streakResult['message'] ?? '';
      _levelUpgraded = streakResult['upgraded'] ?? false;

      final wellnessLevel = _getWellnessLevel(wellnessScore, symptoms);
      level = _mergeLevel(streakLevel, wellnessLevel);
      intensity = _getIntensity(mood, phase);
      isRestDay =
          wellnessScore < 30 ||
          sleepHours < 4 ||
          RecommendationService.isRestDayRecommended(sleepHours, symptoms);

      if (!isRestDay) {
        final allWorkouts = await RecommendationService.loadWorkouts();
        exercises = RecommendationService.filterWorkouts(
          allWorkouts: allWorkouts,
          phase: phase,
          level: level,
          mood: mood,
          symptoms: symptoms,
          sleepHours: sleepHours,
          waterGlasses: waterGlasses,
        );
      }

      phaseMessage = _getPhaseMessage(phase, isRestDay);
    } catch (e) {
      debugPrint('Workout load error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        if (_levelChanged) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showLevelChangePopup(),
          );
        }
      }
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  String _maxLevel(String base, String current) {
    const rank = {'Beginner': 0, 'Intermediate': 1, 'Advanced': 2};
    final b = rank[base] ?? 0;
    final c = rank[current] ?? 0;
    return ['Beginner', 'Intermediate', 'Advanced'][c < b ? b : c];
  }

  String _getWellnessLevel(int score, List<String> syms) {
    final heavy = syms.where((s) => s.toLowerCase() != 'none').length;
    if (score < 35 || heavy >= 3) return 'Beginner';
    if (score < 65 || heavy >= 1) return 'Intermediate';
    return 'Advanced';
  }

  String _mergeLevel(String earned, String wellness) {
    const rank = {'Beginner': 0, 'Intermediate': 1, 'Advanced': 2};
    final e = rank[earned] ?? 0;
    final w = rank[wellness] ?? 0;
    return ['Beginner', 'Intermediate', 'Advanced'][e < w ? e : w];
  }

  String _getIntensity(String m, String p) {
    const mr = {
      'Happy': 2,
      'Calm': 1,
      'Neutral': 1,
      'Anxious': 0,
      'Sad': 0,
      'Angry': 1,
    };
    const pm = {'Menstrual': 0, 'Follicular': 2, 'Ovulatory': 2, 'Luteal': 1};
    final rank = [mr[m] ?? 1, pm[p] ?? 1].reduce((a, b) => a < b ? a : b);
    return ['Low', 'Medium', 'High'][rank];
  }

  String _moodFromScore(int s) {
    switch (s) {
      case 1:
        return 'Sad';
      case 2:
        return 'Anxious';
      case 4:
        return 'Calm';
      case 5:
        return 'Happy';
      default:
        return 'Neutral';
    }
  }

  int _calcWellnessScore(
    double sleep,
    int water,
    int moodS,
    List<String> syms,
  ) {
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
    score += mp[moodS] ?? 10;
    final heavy = syms.where((s) => s.toLowerCase() != 'none').length;
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

  String _getPhaseMessage(String ph, bool rest) {
    if (rest) return 'Rest and recover today 🌿 Your body needs it.';
    switch (ph) {
      case 'Menstrual':
        return 'Be gentle with yourself today 🌸';
      case 'Follicular':
        return 'Your energy is rising 🌱 Great time to move!';
      case 'Ovulatory':
        return 'Peak energy! 🔥 Make the most of it.';
      case 'Luteal':
        return 'Steady movement helps with PMS 🍃';
      default:
        return 'Move with intention today 💚';
    }
  }

  Color _intensityColor(String it) {
    switch (it.toLowerCase()) {
      case 'high':
        return const Color(0xFFE57373);
      case 'medium':
        return const Color(0xFFFFB74D);
      default:
        return const Color(0xFF95B289);
    }
  }

  Color _phaseColor(String ph) {
    switch (ph) {
      case 'Menstrual':
        return const Color(0xFFE57373);
      case 'Follicular':
        return const Color(0xFF81C784);
      case 'Ovulatory':
        return const Color(0xFFFFD54F);
      case 'Luteal':
        return const Color(0xFF9575CD);
      default:
        return const Color(0xFF95B289);
    }
  }

  String _muscleEmoji(String muscle) {
    const map = {
      'Mobility': '🧘',
      'Flexibility': '🤸',
      'Hips': '🦋',
      'Glutes': '🍑',
      'Core': '⚡',
      'Abs': '💪',
      'Legs': '🦵',
      'Spine': '🌊',
      'Relaxation': '🌙',
      'Lower Back': '🔄',
      'Chest': '🎯',
      'Back': '🏋️',
      'Calves': '⚙️',
      'Cardio': '🏃',
      'Shoulders': '🌟',
      'Full Body': '🔥',
    };
    return map[muscle] ?? '💚';
  }

  Color _levelBadgeColor(String lv) {
    switch (lv) {
      case 'Advanced':
        return const Color(0xFFE57373);
      case 'Intermediate':
        return const Color(0xFFFFB74D);
      default:
        return const Color(0xFF95B289);
    }
  }

  String _levelEmoji(String lv) {
    switch (lv) {
      case 'Advanced':
        return '🏆';
      case 'Intermediate':
        return '⭐';
      default:
        return '🌱';
    }
  }

  // ── EXERCISE DETAIL POPUP ─────────────────────────────────────────────────
  void _showExerciseDetail(Map<String, dynamic> exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExerciseDetailSheet(exercise: exercise),
    );
  }

  // ── LEVEL CHANGE POPUP ────────────────────────────────────────────────────
  void _showLevelChangePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF4D3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _levelUpgraded ? '🏆' : '💪',
                style: const TextStyle(fontSize: 52),
              ),
              const SizedBox(height: 12),
              Text(
                _levelUpgraded ? 'Level Up!' : 'Welcome Back!',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A4336),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _levelChangeMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF95B289).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '🔥 $streak day streak',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF5D6D57),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF95B289),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Let's Go! 💪",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF95B289)),
                  )
                : Column(
                    children: [
                      _appBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _streakBanner(),
                              const SizedBox(height: 12),
                              _phaseCard(),
                              const SizedBox(height: 20),
                              if (isRestDay) _restDayCard(),
                              if (!isRestDay) ...[
                                // ── START WORKOUT BUTTON ─────────────────
                                _startWorkoutButton(),
                                const SizedBox(height: 20),
                                _sectionTitle(
                                  "Today's Workout  •  ${exercises.length} exercises",
                                ),
                                const SizedBox(height: 12),
                                ...exercises.map((e) => _exerciseCard(e)),
                              ],
                              const SizedBox(height: 20),
                              _wellnessTip(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── APP BAR ───────────────────────────────────────────────────────────────
  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF5D6D57),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "Today's Workout",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadData,
            child: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF95B289),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ── START WORKOUT BUTTON ──────────────────────────────────────────────────
  Widget _startWorkoutButton() {
    final totalDuration = exercises.fold<int>(
      0,
      (sum, e) => sum + (int.tryParse(e['Duration']?.toString() ?? '30') ?? 30),
    );
    final totalMin = (totalDuration / 60).ceil();

    return GestureDetector(
      onTap: () {
        if (exercises.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                WorkoutActiveScreen(exercises: exercises, phase: phase),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF95B289), Color(0xFF5D8A6F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF95B289).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text(
              '▶',
              style: TextStyle(fontSize: 32, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start Workout',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${exercises.length} exercises  ·  ~$totalMin min',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                level,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STREAK BANNER ─────────────────────────────────────────────────────────
  Widget _streakBanner() {
    final streakProgress = (streak % 14) / 14;
    final nextLevel = streakLevel == 'Advanced'
        ? 'Max Level!'
        : streakLevel == 'Intermediate'
        ? 'Advanced in ${14 - (streak % 14)} days'
        : 'Intermediate in ${14 - (streak % 14)} days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF95B289).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3A4336),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'day streak',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _levelBadgeColor(streakLevel).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _levelBadgeColor(streakLevel).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _levelEmoji(streakLevel),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      streakLevel,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _levelBadgeColor(streakLevel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: streakLevel == 'Advanced' ? 1.0 : streakProgress,
              backgroundColor: const Color(0xFF95B289).withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(_levelBadgeColor(streakLevel)),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${streak % 14}/14 days',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
              Text(
                nextLevel,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _levelBadgeColor(streakLevel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── PHASE CARD ────────────────────────────────────────────────────────────
  Widget _phaseCard() {
    final pColor = _phaseColor(phase);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: pColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$phase Phase · Day $cycleDay',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: pColor,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _intensityColor(intensity).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$intensity Intensity',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _intensityColor(intensity),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            phaseMessage,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF3A4336),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (level != streakLevel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                '⚠️ Showing $level exercises today — your body needs rest. Your earned level is still $streakLevel.',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: Colors.orange,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _badge('Wellness', '$wellnessScore/100'),
              const SizedBox(width: 8),
              _badge('Sleep', '${sleepHours.toStringAsFixed(1)}h'),
              const SizedBox(width: 8),
              _badge('Mood', mood),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF3A4336),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Outfit',
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF3A4336),
      ),
    );
  }

  // ── EXERCISE CARD — tapping opens detail popup ────────────────────────────
  Widget _exerciseCard(Map<String, dynamic> exercise) {
    final name = exercise['exerciseName']?.toString() ?? '';
    final sets = exercise['sets']?.toString() ?? '3';
    final duration = exercise['Duration']?.toString() ?? '30';
    final muscle = exercise['muscleGroup']?.toString() ?? '';
    final exIntensity = exercise['intensity']?.toString() ?? 'Low';
    final index = exercises.indexOf(exercise) + 1;

    return GestureDetector(
      onTap: () => _showExerciseDetail(exercise),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF95B289).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Index circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF95B289).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF5D6D57),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Muscle emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF95B289).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _muscleEmoji(muscle),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF3A4336),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$sets sets · ${duration}s · $muscle',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _intensityColor(exIntensity).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                exIntensity,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _intensityColor(exIntensity),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF95B289),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── REST DAY CARD ─────────────────────────────────────────────────────────
  Widget _restDayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF95B289).withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF95B289).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Rest Day',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            RecommendationService.getSleepMessage(sleepHours),
            textAlign: TextAlign.center,

            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Try: Deep breathing, gentle stretching, or a 20 min walk 🌿',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF5D6D57),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── WELLNESS TIP ──────────────────────────────────────────────────────────
  Widget _wellnessTip() {
    const tips = {
      'Menstrual':
          'Iron-rich foods like spinach and lentils help restore energy lost during your period.',
      'Follicular':
          'This is a great time to try new workouts — your body adapts faster in this phase.',
      'Ovulatory':
          'You\'re at peak strength — push a little harder today if it feels right.',
      'Luteal':
          'Magnesium-rich foods help reduce PMS symptoms during this phase.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF95B289).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF95B289).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tips[phase] ?? 'Listen to your body and move with intention.',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: Color(0xFF3A4336),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── EXERCISE DETAIL BOTTOM SHEET ──────────────────────────────────────────────
class _ExerciseDetailSheet extends StatefulWidget {
  final Map<String, dynamic> exercise;
  const _ExerciseDetailSheet({required this.exercise});

  @override
  State<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<_ExerciseDetailSheet> {
  int _tab = 0; // 0 = Animation, 1 = Video

  String _muscleEmoji(String muscle) {
    const map = {
      'Mobility': '🧘',
      'Flexibility': '🤸',
      'Hips': '🦋',
      'Glutes': '🍑',
      'Core': '⚡',
      'Abs': '💪',
      'Legs': '🦵',
      'Spine': '🌊',
      'Relaxation': '🌙',
      'Lower Back': '🔄',
      'Chest': '🎯',
      'Back': '🏋️',
      'Calves': '⚙️',
      'Cardio': '🏃',
      'Shoulders': '🌟',
      'Full Body': '🔥',
    };
    return map[muscle] ?? '💚';
  }

  // Use the real YouTube link from CSV, fall back to search if missing
  String _youtubeUrl(String name) {
    final link = widget.exercise['youtubeLink']?.toString().trim() ?? '';
    if (link.isNotEmpty) return link;
    final query = Uri.encodeComponent('$name exercise how to do');
    return 'https://www.youtube.com/results?search_query=$query';
  }

  Future<void> _openYoutube(String name) async {
    final uri = Uri.parse(_youtubeUrl(name));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final name = e['exerciseName']?.toString() ?? '';
    final duration = e['Duration']?.toString() ?? '30';
    final muscle = e['muscleGroup']?.toString() ?? '';
    final description = e['description']?.toString() ?? '';
    final tips = e['tips']?.toString() ?? '';
    final emoji = _muscleEmoji(muscle);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── TAB BAR ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _tabButton('Animation', 0),
                const SizedBox(width: 24),
                _tabButton('Video', 1),
              ],
            ),
          ),

          // ── TAB CONTENT ───────────────────────────────────────────────────
          if (_tab == 0) _animationTab(emoji, muscle),
          if (_tab == 1) _videoTab(name),

          // ── EXERCISE INFO ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$duration s',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
                if (tips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    tips,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: Colors.black45,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── CLOSE BUTTON ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF95B289),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.black : Colors.black38,
            ),
          ),
          const SizedBox(height: 4),
          if (selected)
            Container(
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF95B289),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  // Animation tab — large emoji display with muscle info
  Widget _animationTab(String emoji, String muscle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 8),
          Text(
            muscle,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D6D57),
            ),
          ),
        ],
      ),
    );
  }

  // Video tab — YouTube thumbnail with open button
  Widget _videoTab(String name) {
    return GestureDetector(
      onTap: () => _openYoutube(name),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dark background
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: const Color(0xFF1A1A2E),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '▶',
                        style: TextStyle(fontSize: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'HOW TO DO',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // YouTube badge
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tap to open hint
            Positioned(
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap to open YouTube',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
