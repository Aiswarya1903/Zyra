import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Mode { countdown, exercise, setRest, roundRest, finished }
enum _ExType { timed, reps }

/// Circuit-style workout screen.
///
/// Flow example — Exercise A (2 sets), B (3 sets), C (2 sets):
///   Round 1: A → rest → B → rest → C → ROUND REST
///   Round 2: A → rest → B → rest → C → ROUND REST  (A & C now done)
///   Round 3: B only → FINISHED
///
/// Within each exercise slot there is a between-set rest (setRest).
/// Between exercises within a round there is also a setRest.
/// After every full round there is a roundRest.

class WorkoutActiveScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final String phase;

  const WorkoutActiveScreen({
    super.key,
    required this.exercises,
    required this.phase,
  });

  @override
  State<WorkoutActiveScreen> createState() => _WorkoutActiveScreenState();
}

class _WorkoutActiveScreenState extends State<WorkoutActiveScreen>
    with TickerProviderStateMixin {

  // ── CIRCUIT STATE ──────────────────────────────────────────────────────────
  late final List<int> _totalSets;   // totalSets[i] = sets for exercise i
  late final List<int> _doneSetsCt;  // doneSetsCt[i] = sets completed for exercise i

  int _currentRound = 1;             // 1-based round number
  List<int> _roundQueue = [];        // exercise indices still active this round
  int _queuePos = 0;                 // current position in _roundQueue

  // ── CURRENT SLOT ──────────────────────────────────────────────────────────
  _Mode _mode = _Mode.countdown;
  bool _isPaused = false;

  int _countdownValue = 3;

  // Timed
  int _secondsLeft = 30;
  int _totalSeconds = 30;

  // Reps
  _ExType _exType = _ExType.timed;
  int _repsLeft = 10;
  int _totalReps = 10;

  // Rest between exercises (within a round) — 15 s
  static const int _kSetRestSec   = 15;
  int _restLeft = 15;

  // Rest between rounds — 30 s
  static const int _kRoundRestSec = 30;
  int _roundRestLeft = 30;

  Timer? _timer;

  // Animations
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _cdCtrl;
  late Animation<double>   _cdScale;
  late Animation<double>   _cdFade;
  late AnimationController _repBounceCtrl;
  late Animation<double>   _repBounceAnim;

  // ── COLORS ────────────────────────────────────────────────────────────────
  Color get _phaseColor {
    switch (widget.phase) {
      case 'Menstrual':  return const Color(0xFFE57373);
      case 'Follicular': return const Color(0xFF95B289);
      case 'Ovulatory':  return const Color(0xFFE8A020);
      case 'Luteal':     return const Color(0xFF9575CD);
      default:           return const Color(0xFF95B289);
    }
  }

  static const Color _cardBg = Color(0xFF1A1A2E);

  // ── ACCESSORS ─────────────────────────────────────────────────────────────
  Map<String, dynamic> get _curEx =>
      widget.exercises[_roundQueue[_queuePos]];

  int get _curExIdx => _roundQueue[_queuePos];

  int get _totalRounds =>
      _totalSets.reduce((a, b) => a > b ? a : b);

  /// Sum of all set-slots (for the segmented progress bar)
  int get _totalSlots =>
      _totalSets.fold(0, (s, v) => s + v);

  /// Sets completed so far across all exercises
  int get _completedSlots =>
      _doneSetsCt.fold(0, (s, v) => s + v);

  String _muscleEmoji(String m) {
    const map = {
      'Mobility': '🧘', 'Flexibility': '🤸', 'Hips': '🦋',
      'Glutes': '🍑',   'Core': '⚡',        'Abs': '💪',
      'Legs': '🦵',     'Spine': '🌊',       'Relaxation': '🌙',
      'Lower Back': '🔄','Chest': '🎯',      'Back': '🏋️',
      'Calves': '⚙️',   'Cardio': '🏃',     'Shoulders': '🌟',
      'Full Body': '🔥',
    };
    return map[m] ?? '💚';
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _openYoutube(String name) async {
    final q = Uri.encodeComponent('$name exercise how to do tutorial');
    final uri = Uri.parse('https://www.youtube.com/results?search_query=$q');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── INIT ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _totalSets = widget.exercises
        .map((e) => (int.tryParse(e['sets']?.toString() ?? '') ?? 1).clamp(1, 99))
        .toList();
    _doneSetsCt = List.filled(widget.exercises.length, 0);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _cdCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _cdScale = Tween<double>(begin: 1.5, end: 0.7).animate(
        CurvedAnimation(parent: _cdCtrl, curve: Curves.easeOut));
    _cdFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _cdCtrl, curve: Curves.easeIn));

    _repBounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _repBounceAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _repBounceCtrl, curve: Curves.easeOut));

    _buildRoundQueue();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _cdCtrl.dispose();
    _repBounceCtrl.dispose();
    super.dispose();
  }

  // ── ROUND QUEUE ────────────────────────────────────────────────────────────
  /// Rebuilds the list of exercise indices that still have sets remaining.
  void _buildRoundQueue() {
    _roundQueue = [
      for (int i = 0; i < widget.exercises.length; i++)
        if (_doneSetsCt[i] < _totalSets[i]) i
    ];
    _queuePos = 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COUNTDOWN 3-2-1
  // ══════════════════════════════════════════════════════════════════════════
  void _startCountdown() {
    setState(() { _mode = _Mode.countdown; _countdownValue = 3; });
    _tickCountdown();
  }

  void _tickCountdown() {
    _cdCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
        _tickCountdown();
      } else {
        _beginExercise();
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXERCISE
  // ══════════════════════════════════════════════════════════════════════════
  void _beginExercise() {
    _timer?.cancel();
    _isPaused = false;
    final cur = _curEx;
    final repsVal = int.tryParse(cur['reps']?.toString() ?? '');

    if (repsVal != null && repsVal > 0) {
      _exType   = _ExType.reps;
      _repsLeft = repsVal;
      _totalReps = repsVal;
    } else {
      _exType      = _ExType.timed;
      _secondsLeft = int.tryParse(cur['Duration']?.toString() ?? '30') ?? 30;
      _totalSeconds = _secondsLeft;
      _runTimedExercise();
    }
    setState(() => _mode = _Mode.exercise);
  }

  void _runTimedExercise() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      if (_secondsLeft <= 0) { _timer?.cancel(); _onExerciseSlotDone(); return; }
      setState(() => _secondsLeft--);
    });
  }

  void _tapRep() async {
    if (_repsLeft <= 0 || _isPaused) return;
    await _repBounceCtrl.forward();
    await _repBounceCtrl.reverse();
    setState(() => _repsLeft--);
    if (_repsLeft <= 0) {
      await Future.delayed(const Duration(milliseconds: 300));
      _onExerciseSlotDone();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AFTER EACH EXERCISE SLOT
  // ══════════════════════════════════════════════════════════════════════════
  void _onExerciseSlotDone() {
    _timer?.cancel();

    // Mark one set as done for this exercise
    _doneSetsCt[_curExIdx]++;

    final bool moreInRound = _queuePos < _roundQueue.length - 1;

    if (moreInRound) {
      // ── More exercises left in this round → short rest then next exercise ──
      _queuePos++;
      _restLeft = _kSetRestSec;
      setState(() => _mode = _Mode.setRest);
      _runRestTimer(() => _startCountdown());
    } else {
      // ── End of round ──────────────────────────────────────────────────────
      // Rebuild queue (drops exercises that finished all sets)
      _buildRoundQueue();

      if (_roundQueue.isEmpty) {
        // Every exercise has exhausted every set → DONE
        setState(() => _mode = _Mode.finished);
      } else {
        // More rounds remain → round rest
        _currentRound++;
        _roundRestLeft = _kRoundRestSec;
        setState(() => _mode = _Mode.roundRest);
        _runRestTimer(() => _startCountdown());
      }
    }
  }

  // ── Generic rest timer (reused for both rest modes) ─────────────────────
  void _runRestTimer(VoidCallback onDone) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      final val = _mode == _Mode.roundRest ? _roundRestLeft : _restLeft;
      if (val <= 0) { _timer?.cancel(); onDone(); return; }
      setState(() {
        if (_mode == _Mode.roundRest) _roundRestLeft--; else _restLeft--;
      });
    });
  }

  void _skipRest() {
    _timer?.cancel();
    _startCountdown();
  }

  void _addTime(int s) => setState(() {
    if (_mode == _Mode.roundRest) _roundRestLeft += s; else _restLeft += s;
  });

  // ── Pause / nav ──────────────────────────────────────────────────────────
  void _togglePause() => setState(() => _isPaused = !_isPaused);

  void _prevSlot() {
    _timer?.cancel();
    if (_queuePos > 0) setState(() => _queuePos--);
    _startCountdown();
  }

  void _nextSlot() {
    _timer?.cancel();
    _onExerciseSlotDone();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case _Mode.countdown:   return _countdownScreen();
      case _Mode.exercise:    return _exerciseScreen();
      case _Mode.setRest:     return _restScreen(isRoundRest: false);
      case _Mode.roundRest:   return _restScreen(isRoundRest: true);
      case _Mode.finished:    return _finishedScreen();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN 1 — COUNTDOWN
  // ══════════════════════════════════════════════════════════════════════════
  Widget _countdownScreen() {
    final cur  = _curEx;
    final name   = cur['exerciseName']?.toString() ?? '';
    final muscle = cur['muscleGroup']?.toString() ?? '';
    final exIdx  = _curExIdx;
    final setNum = _doneSetsCt[exIdx] + 1;
    final totSet = _totalSets[exIdx];
    final repsVal = int.tryParse(cur['reps']?.toString() ?? '');
    final preview = (repsVal != null && repsVal > 0)
        ? '$repsVal reps' : '${cur['Duration'] ?? 30}s';

    return Scaffold(
      body: Container(
        color: _phaseColor,
        child: SafeArea(
          child: Column(children: [
            _progressBar(),
            const Spacer(),
            _label('GET READY'),
            const SizedBox(height: 8),
            _badge('Round $_currentRound  ·  Set $setNum / $totSet'),
            const SizedBox(height: 14),
            _exName(name),
            const SizedBox(height: 4),
            _sub('$preview  ·  $muscle'),
            const SizedBox(height: 14),
            Text(_muscleEmoji(muscle), style: const TextStyle(fontSize: 60)),
            const Spacer(),
            AnimatedBuilder(
              animation: _cdCtrl,
              builder: (_, __) => Opacity(
                opacity: _cdFade.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: _cdScale.value,
                  child: Text('$_countdownValue',
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 190,
                        fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
                ),
              ),
            ),
            const Spacer(flex: 2),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN 2 — EXERCISE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _exerciseScreen() {
    final cur    = _curEx;
    final name   = cur['exerciseName']?.toString() ?? '';
    final muscle = cur['muscleGroup']?.toString() ?? '';
    final exIdx  = _curExIdx;
    final setNum = _doneSetsCt[exIdx] + 1;
    final totSet = _totalSets[exIdx];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _isPaused ? _phaseColor.withOpacity(0.8) : _phaseColor,
        child: SafeArea(
          child: Column(children: [
            _progressBar(),
            const SizedBox(height: 10),
            _badge('Round $_currentRound  ·  Set $setNum / $totSet'),
            const SizedBox(height: 8),

            // Pulsing emoji
            Expanded(
              child: Center(
                child: ScaleTransition(
                  scale: _isPaused ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
                  child: Text(_muscleEmoji(muscle),
                      style: const TextStyle(fontSize: 100)),
                ),
              ),
            ),

            if (_isPaused) _label('PAUSED'),

            // ── TIMED ────────────────────────────────────────────────────
            if (_exType == _ExType.timed) ...[
              Text(_fmt(_secondsLeft),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 80,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
              const SizedBox(height: 10),
              SizedBox(
                width: 62, height: 62,
                child: CircularProgressIndicator(
                  value: _totalSeconds > 0 ? _secondsLeft / _totalSeconds : 0,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ]

            // ── REPS ─────────────────────────────────────────────────────
            else ...[
              GestureDetector(
                onTap: _tapRep,
                child: AnimatedBuilder(
                  animation: _repBounceCtrl,
                  builder: (_, child) =>
                      Transform.scale(scale: _repBounceAnim.value, child: child),
                  child: Container(
                    width: 148, height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$_repsLeft',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 60,
                              fontWeight: FontWeight.bold, color: Colors.white,
                              height: 1.0)),
                        Text('reps left',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 13,
                              color: Colors.white.withOpacity(0.7))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _label('TAP EACH REP'),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Wrap(
                  spacing: 7, runSpacing: 7,
                  alignment: WrapAlignment.center,
                  children: List.generate(_totalReps, (i) => Container(
                    width: 11, height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i >= _repsLeft
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                  )),
                ),
              ),
            ],

            const SizedBox(height: 16),
            _exName(name),
            const SizedBox(height: 3),
            _sub(muscle),
            const SizedBox(height: 22),
            _controls(),
            const SizedBox(height: 28),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN 3 — REST  (set rest OR round rest — same layout, different color)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _restScreen({required bool isRoundRest}) {
    // When this screen appears:
    //   setRest  → _queuePos already incremented → _curEx is the NEXT exercise
    //   roundRest→ _buildRoundQueue() ran      → _roundQueue[0] is first of next round
    final nextEx = isRoundRest
        ? (_roundQueue.isNotEmpty ? widget.exercises[_roundQueue[0]] : null)
        : (_queuePos < _roundQueue.length ? _curEx : null);

    final nextName   = nextEx?['exerciseName']?.toString() ?? '';
    final nextMuscle = nextEx?['muscleGroup']?.toString() ?? '';
    final nextReps   = int.tryParse(nextEx?['reps']?.toString() ?? '');
    final nextPreview = (nextReps != null && nextReps > 0)
        ? '$nextReps reps' : '${nextEx?['Duration'] ?? 30}s';

    // Set number of the NEXT slot for that exercise
    final nextExIdx = isRoundRest
        ? (_roundQueue.isNotEmpty ? _roundQueue[0] : -1)
        : (_queuePos < _roundQueue.length ? _curExIdx : -1);
    final nextSetNum  = nextExIdx >= 0 ? _doneSetsCt[nextExIdx] + 1 : 0;
    final nextTotSet  = nextExIdx >= 0 ? _totalSets[nextExIdx]      : 0;

    final timerVal  = isRoundRest ? _roundRestLeft : _restLeft;
    final addSecs   = isRoundRest ? 30 : 20;

    // Slightly darken the phase color for round rest so user feels the break
    final bg = isRoundRest
        ? Color.fromARGB(255,
            (_phaseColor.red   * 0.82).round(),
            (_phaseColor.green * 0.82).round(),
            (_phaseColor.blue  * 0.82).round())
        : _phaseColor;

    return Scaffold(
      body: Container(
        color: bg,
        child: SafeArea(
          child: Column(children: [
            _progressBar(),
            const SizedBox(height: 20),

            if (isRoundRest) ...[
              _badge('✅  Round ${_currentRound - 1} Complete!'),
              const SizedBox(height: 10),
              _label('ROUND REST'),
            ] else
              _label('REST'),

            const SizedBox(height: 8),
            Text(_fmt(timerVal),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 74,
                  fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pill('+${addSecs}s', filled: true,  onTap: () => _addTime(addSecs)),
                const SizedBox(width: 14),
                _pill('Skip',         filled: false, onTap: _skipRest),
              ],
            ),

            const SizedBox(height: 20),

            if (nextEx != null)
              Expanded(child: _nextCard(
                nextName, nextMuscle, nextPreview,
                'Set $nextSetNum / $nextTotSet  ·  Round $_currentRound',
              ))
            else
              const Spacer(),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN 4 — FINISHED
  // ══════════════════════════════════════════════════════════════════════════
  Widget _finishedScreen() {
    final totalSec = widget.exercises.fold<int>(0, (s, e) =>
        s + (int.tryParse(e['Duration']?.toString() ?? '30') ?? 30) *
            (int.tryParse(e['sets']?.toString()    ?? '1')  ?? 1));
    final totalMin  = (totalSec / 60).ceil();
    final totalReps = widget.exercises.fold<int>(0, (s, e) =>
        s + (int.tryParse(e['reps']?.toString() ?? '0') ?? 0) *
            (int.tryParse(e['sets']?.toString() ?? '1') ?? 1));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_phaseColor, _phaseColor.withOpacity(0.5)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Trophy card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(children: [
                      const Text('🏆', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 14),
                      const Text('Well Done!',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 34,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Workout Complete',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 16,
                            letterSpacing: 1.5,
                            color: Colors.white.withOpacity(0.7))),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statCircle('${widget.exercises.length}', 'Exercises', '🏋️'),
                          _statCircle('$_totalRounds', 'Rounds', '🔄'),
                          if (totalReps > 0)
                            _statCircle('$totalReps', 'Total Reps', '💪')
                          else
                            _statCircle('~$totalMin', 'Minutes', '⏱️'),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Text(_motivationalText(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15,
                        color: Colors.white.withOpacity(0.85), height: 1.55)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Back to Workout',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 16,
                            fontWeight: FontWeight.bold, color: _phaseColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  // Segmented progress bar — one segment per set-slot across all exercises
  Widget _progressBar() {
    final List<Widget> segs = [];
    for (int i = 0; i < widget.exercises.length; i++) {
      for (int s = 0; s < _totalSets[i]; s++) {
        final done    = s < _doneSetsCt[i];
        final current = !done &&
            _roundQueue.isNotEmpty &&
            _queuePos < _roundQueue.length &&
            i == _curExIdx &&
            (_mode == _Mode.exercise || _mode == _Mode.countdown) &&
            s == _doneSetsCt[i];
        segs.add(Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: done    ? Colors.white
                   : current ? Colors.white.withOpacity(0.65)
                             : Colors.white.withOpacity(0.25),
            ),
          ),
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () { _timer?.cancel(); Navigator.pop(context); },
          child: const Icon(Icons.close, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(child: Row(children: segs)),
        const SizedBox(width: 12),
        Text('R$_currentRound/$_totalRounds',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold,
              fontSize: 13, color: Colors.white.withOpacity(0.9))),
      ]),
    );
  }

  Widget _controls() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _ctrlBtn(Icons.skip_previous_rounded, _prevSlot,
          enabled: _queuePos > 0),
      const SizedBox(width: 20),
      GestureDetector(
        onTap: _togglePause,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(
            _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: Colors.white, size: 38),
        ),
      ),
      const SizedBox(width: 20),
      _ctrlBtn(Icons.skip_next_rounded, _nextSlot, enabled: true),
    ],
  );

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, {bool enabled = true}) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? Colors.white.withOpacity(0.15) : Colors.transparent,
          ),
          child: Icon(icon,
              color: enabled ? Colors.white : Colors.white30, size: 34),
        ),
      );

  Widget _nextCard(
      String name, String muscle, String preview, String subtitle) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              Text('NEXT UP',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.65), letterSpacing: 1)),
              const Spacer(),
              Text(preview,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(name.toUpperCase(),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 18,
                  fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Text('$subtitle  ·  $muscle',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 12,
                  color: Colors.white.withOpacity(0.6))),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _openYoutube(name),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: _cardBg, borderRadius: BorderRadius.circular(18)),
                child: Stack(children: [
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18))),
                      child: Column(children: [
                        Text('HOW TO DO',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 10,
                              letterSpacing: 2,
                              color: Colors.white.withOpacity(0.5))),
                        Text(name.toUpperCase(),
                          style: const TextStyle(fontFamily: 'Outfit',
                              fontSize: 14, fontWeight: FontWeight.bold,
                              color: Colors.white, letterSpacing: 1)),
                      ]),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 44),
                        Text(_muscleEmoji(muscle),
                            style: const TextStyle(fontSize: 54)),
                        const SizedBox(height: 12),
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(color: Colors.white60, width: 2),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 8),
                        Text('Tap to watch on YouTube',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 12,
                              color: Colors.white.withOpacity(0.5))),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000),
                        borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.white, size: 12),
                          SizedBox(width: 3),
                          Text('YouTube',
                            style: TextStyle(color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tiny helpers ──────────────────────────────────────────────────────────
  Widget _badge(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20)),
    child: Text(t,
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 12,
          color: Colors.white, fontWeight: FontWeight.w600)),
  );

  Widget _label(String t) => Text(t,
    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, letterSpacing: 3,
        color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w600));

  Widget _sub(String t) => Text(t,
    style: TextStyle(fontFamily: 'Outfit', fontSize: 14,
        color: Colors.white.withOpacity(0.65)));

  Widget _exName(String n) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Text(n.toUpperCase(),
      textAlign: TextAlign.center,
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 20,
          fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
  );

  Widget _pill(String label,
      {required bool filled, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
          decoration: BoxDecoration(
            color: filled ? Colors.white.withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: filled ? null : Border.all(color: Colors.white, width: 2)),
          child: Text(label,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16,
                fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );

  Widget _statCircle(String val, String label, String emoji) => Column(
    children: [
      Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            Text(val,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 17,
                  fontWeight: FontWeight.bold, color: Colors.white,
                  height: 1.1)),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(label,
        style: TextStyle(fontFamily: 'Outfit', fontSize: 11,
            color: Colors.white.withOpacity(0.8))),
    ],
  );

  String _motivationalText() {
    switch (widget.phase) {
      case 'Menstrual':  return 'You showed up for yourself today — that takes real strength. 🌸';
      case 'Follicular': return 'Your energy is building beautifully — great work riding that wave! 🌿';
      case 'Ovulatory':  return 'You were absolutely on fire today! Peak energy, peak performance! ⚡';
      case 'Luteal':     return 'Pushing through the luteal phase? That\'s real dedication. 💜';
      default:           return 'Every rep, every second counts — you earned this today! 🔥';
    }
  }
}
