import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/services/diet_service.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen>
    with SingleTickerProviderStateMixin {
  // ── STATE ─────────────────────────────────────────────────────────────────
  bool isLoading = true;
  String phase = 'Follicular';
  int cycleDay = 1;
  String dietType = 'Vegetarian';
  List<String> symptoms = [];
  int wellnessScore = 60;
  Map<String, dynamic> todayMeal = {};
  List<String> symptomTips = [];
  int _selectedMeal = 0; // 0=breakfast 1=lunch 2=dinner

  // Image URLs per meal slot
  String? _breakfastImageUrl;
  String? _lunchImageUrl;
  String? _dinnerImageUrl;
  bool _imageLoading = false;

  late AnimationController _tabController;
  late Animation<double> _fadeAnim;

  // ── INIT ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _tabController, curve: Curves.easeIn);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── LOAD ALL DATA ─────────────────────────────────────────────────────────
  Future<void> _loadData({bool isRefresh = false}) async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user profile
      final profile = await DietService.fetchUserProfile();
      dietType = DietService.mapDietType(profile['dietPreference'] as String?);

      // Read phase and cycleDay directly from Firestore
      cycleDay = (profile['cycleDay'] as num?)?.toInt() ?? 1;
      final rawPhase = profile['currentPhase'] as String? ?? '';
      phase = rawPhase.replaceAll(' Phase', '').trim();
      if (phase.isEmpty) phase = DietService.getPhase(cycleDay);

      // Load today wellness
      final w = await DietService.fetchTodayWellness();
      final moodScore = (w['mood'] as num?)?.toInt() ?? 3;
      final water = (w['water'] as num?)?.toInt() ?? 0;
      final sleep = (w['sleep'] as num?)?.toDouble() ?? 7.0;
      symptoms = List<String>.from(w['symptoms'] ?? []);

      wellnessScore = DietService.calcWellnessScore(
        sleep: sleep,
        water: water,
        moodScore: moodScore,
        symptoms: symptoms,
      );

      // Load CSV meals
      final allMeals = await DietService.loadMeals();

      // Get or create today's meal seed
      int? seed = await DietService.loadTodayMealSeed();
      if (isRefresh || seed == null) {
        seed = DateTime.now().millisecondsSinceEpoch % 100000;
        await DietService.saveTodayMealSeed(seed);
      }

      // Pick meal using seed
      todayMeal = DietService.filterMeal(
        allMeals: allMeals,
        phase: phase,
        dietType: dietType,
        wellnessScore: wellnessScore,
        forceSeed: seed,
      );

      symptomTips = DietService.getSymptomTips(symptoms);
      _fetchImages();
    } catch (e) {
      debugPrint('Diet load error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
      _tabController.forward(from: 0);
    }
  }

  // ── FETCH IMAGES FOR ALL 3 MEALS ─────────────────────────────────────────
  Future<void> _fetchImages() async {
    setState(() => _imageLoading = true);
    final bName = todayMeal['Breakfast'] ?? '';

    // ADD THIS to see what's happening
    final testUrl = await DietService.fetchMealImageUrl(bName);
    debugPrint('🖼️ Image URL result: $testUrl'); // check terminal

    final lName = todayMeal['Lunch'] ?? '';
    final dName = todayMeal['Dinner'] ?? '';

    // Fetch all in parallel
    final results = await Future.wait([
      DietService.fetchMealImageUrl(bName),
      DietService.fetchMealImageUrl(lName),
      DietService.fetchMealImageUrl(dName),
    ]);

    if (mounted) {
      setState(() {
        _breakfastImageUrl = results[0];
        _lunchImageUrl = results[1];
        _dinnerImageUrl = results[2];
        _imageLoading = false;
      });
    }
  }

  //  HELPERS
  Color _phaseColor(String ph) {
    switch (ph) {
      case 'Menstrual':
        return const Color(0xFFE57373);
      case 'Follicular':
        return const Color(0xFF81C784);
      case 'Ovulation':
        return const Color(0xFFFFD54F);
      case 'Luteal':
        return const Color(0xFF9575CD);
      default:
        return const Color(0xFF95B289);
    }
  }

  String _phaseEmoji(String ph) {
    switch (ph) {
      case 'Menstrual':
        return '🌸';
      case 'Follicular':
        return '🌱';
      case 'Ovulation':
        return '🌟';
      case 'Luteal':
        return '🍂';
      default:
        return '💚';
    }
  }

  String _wellnessLabel() {
    if (wellnessScore >= 75) return '💪 Excellent';
    if (wellnessScore >= 55) return '✅ Good';
    if (wellnessScore >= 35) return '⚠️ Moderate';
    return '🔴 Low — Iron-rich meals suggested';
  }

  Color _wellnessColor() {
    if (wellnessScore >= 75) return const Color(0xFF4CAF50);
    if (wellnessScore >= 55) return const Color(0xFF8BC34A);
    if (wellnessScore >= 35) return const Color(0xFFFF9800);
    return const Color(0xFFE57373);
  }

  String? _currentImageUrl() {
    switch (_selectedMeal) {
      case 0:
        return _breakfastImageUrl;
      case 1:
        return _lunchImageUrl;
      case 2:
        return _dinnerImageUrl;
      default:
        return null;
    }
  }

  Map<String, String> _currentMealData() {
    switch (_selectedMeal) {
      case 0:
        return {
          'name': todayMeal['Breakfast'] ?? '',
          'ingredients': todayMeal['BreakfastIngredients'] ?? '',
          'calories': todayMeal['BreakfastCalories'] ?? '0',
          'fat': todayMeal['BreakfastFat_g'] ?? '0',
          'protein': todayMeal['BreakfastProtein_g'] ?? '0',
          'carbs': todayMeal['BreakfastCarbs_g'] ?? '0',
          'preparation': todayMeal['BreakfastPreparation'] ?? '',
          'prepTime': todayMeal['BreakfastPrepTime_min'] ?? '15',
        };
      case 1:
        return {
          'name': todayMeal['Lunch'] ?? '',
          'ingredients': todayMeal['LunchIngredients'] ?? '',
          'calories': todayMeal['LunchCalories'] ?? '0',
          'fat': todayMeal['LunchFat_g'] ?? '0',
          'protein': todayMeal['LunchProtein_g'] ?? '0',
          'carbs': todayMeal['LunchCarbs_g'] ?? '0',
          'preparation': todayMeal['LunchPreparation'] ?? '',
          'prepTime': todayMeal['LunchPrepTime_min'] ?? '30',
        };
      case 2:
        return {
          'name': todayMeal['Dinner'] ?? '',
          'ingredients': todayMeal['DinnerIngredients'] ?? '',
          'calories': todayMeal['DinnerCalories'] ?? '0',
          'fat': todayMeal['DinnerFat_g'] ?? '0',
          'protein': todayMeal['DinnerProtein_g'] ?? '0',
          'carbs': todayMeal['DinnerCarbs_g'] ?? '0',
          'preparation': todayMeal['DinnerPreparation'] ?? '',
          'prepTime': todayMeal['DinnerPrepTime_min'] ?? '25',
        };
      default:
        return {};
    }
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
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        _appBar(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                _phaseWellnessCard(),
                                const SizedBox(height: 18),
                                _mealToggle(),
                                const SizedBox(height: 14),
                                _mealImageCard(),
                                const SizedBox(height: 16),
                                _mealDetailCard(),
                                if (symptomTips.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _symptomTipsCard(),
                                ],
                                const SizedBox(height: 16),
                                _pcodReminders(),
                                const SizedBox(height: 16),
                                _macrosCard(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
            "Today's Diet",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _loadData(isRefresh: true), // ← only this line changes
            child: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF95B289),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  // ── PHASE + WELLNESS CARD ─────────────────────────────────────────────────
  Widget _phaseWellnessCard() {
    final pColor = _phaseColor(phase);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(_phaseEmoji(phase), style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$phase Phase · Day $cycleDay',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: pColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${todayMeal['DietName'] ?? ''} · $dietType',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // Total calories badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${todayMeal['TotalCalories'] ?? 0} cal',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF3A4336),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Wellness score bar
          Row(
            children: [
              const Text(
                'Wellness  ',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: wellnessScore / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.4),
                    valueColor: AlwaysStoppedAnimation(_wellnessColor()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _wellnessLabel(),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _wellnessColor(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MEAL TOGGLE TABS ──────────────────────────────────────────────────────
  Widget _mealToggle() {
    final labels = ['🌅 Breakfast', '☀️ Lunch', '🌙 Dinner'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final selected = _selectedMeal == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedMeal = i);
                _tabController.forward(from: 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF95B289)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── FOOD IMAGE CARD ───────────────────────────────────────────────────────
  Widget _mealImageCard() {
    final imageUrl = _currentImageUrl();
    final meal = _currentMealData();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Image
          SizedBox(
            height: 210,
            width: double.infinity,
            child: imageUrl != null && !_imageLoading
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _imagePlaceholder(),
                    errorWidget: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),
          // Meal name + prep time overlay
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    meal['name'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Prep time badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF95B289),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${meal['prepTime']} min',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Calories top-right
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${meal['calories']} cal',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Center(
        child: Icon(Icons.restaurant, color: Color(0xFF95B289), size: 56),
      ),
    );
  }

  // ── MEAL DETAIL CARD (ingredients + steps) ────────────────────────────────
  Widget _mealDetailCard() {
    final meal = _currentMealData();

    // Parse ingredients into a clean list
    final rawIngredients = meal['ingredients'] ?? '';
    final ingredients = rawIngredients
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Parse preparation into numbered steps
    final rawPrep = meal['preparation'] ?? ''; // ← this line was missing
    final steps = rawPrep
        .split(' | ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Identify iron-rich ingredients
    bool hasIron(String s) => s.contains('(iron)');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF95B289).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Per-meal macros row ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniMacro(
                'Protein',
                meal['protein'] ?? '0',
                const Color(0xFF81C784),
              ),
              _miniMacro(
                'Carbs',
                meal['carbs'] ?? '0',
                const Color(0xFFFFB74D),
              ),
              _miniMacro('Fat', meal['fat'] ?? '0', const Color(0xFFE57373)),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE0E0E0)),

          // ── Ingredients ─────────────────────────────────────────────────
          const Text(
            '🧺 Ingredients',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF5D6D57),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredients.map((ing) {
              final iron = hasIron(ing);
              final label = ing.replaceAll('(iron)', '').trim();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: iron
                      ? const Color(0xFFFFE0B2)
                      : const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: iron
                        ? const Color(0xFFFF8C00).withOpacity(0.4)
                        : const Color(0xFF95B289).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iron) ...[
                      const Text('🔴', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: iron
                            ? const Color(0xFFE65100)
                            : const Color(0xFF3A4336),
                        fontWeight: iron ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          if (wellnessScore < 50) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0B2).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🔴 = Iron-rich ingredient (prioritised for your wellness score)',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: Color(0xFFBF360C),
                ),
              ),
            ),
          ],

          const Divider(height: 24, color: Color(0xFFE0E0E0)),

          // ── Preparation steps ────────────────────────────────────────────
          const Text(
            '👩‍🍳 How to Prepare',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF5D6D57),
            ),
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF95B289),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMacro(String label, String grams, Color color) {
    return Column(
      children: [
        Text(
          '${grams}g',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ── SYMPTOM TIPS ──────────────────────────────────────────────────────────
  Widget _symptomTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE0E0).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE57373).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💊 Based on your symptoms today',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF3A4336),
            ),
          ),
          const SizedBox(height: 10),
          ...symptomTips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                tip,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PCOD REMINDERS ────────────────────────────────────────────────────────
  Widget _pcodReminders() {
    final reminders = [
      '🚫 Avoid refined sugar and white bread',
      '🍵 Spearmint tea helps manage androgen levels',
      '🌿 Cinnamon improves insulin sensitivity',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF95B289).withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF95B289).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🌸 PCOD Reminders',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF3A4336),
            ),
          ),
          const SizedBox(height: 10),
          ...reminders.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                r,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DAILY MACROS SUMMARY ──────────────────────────────────────────────────
  Widget _macrosCard() {
    final fat = int.tryParse(todayMeal['TotalFat_g'] ?? '0') ?? 0;
    final protein = int.tryParse(todayMeal['TotalProtein_g'] ?? '0') ?? 0;
    final carbs = int.tryParse(todayMeal['TotalCarbs_g'] ?? '0') ?? 0;
    final total = (fat + protein + carbs).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF95B289).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Macros',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF3A4336),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total prep time today: ${todayMeal['TotalPrepTime_min'] ?? 0} min',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _macroBar('Protein', protein, const Color(0xFF81C784), total),
              _macroBar('Carbs', carbs, const Color(0xFFFFD54F), total),
              _macroBar('Fat', fat, const Color(0xFFE57373), total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroBar(String label, int grams, Color color, double total) {
    final pct = total > 0 ? (grams / total * 100).round() : 0;
    return Expanded(
      child: Column(
        children: [
          Text(
            '${grams}g',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: color),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? grams / total : 0,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
