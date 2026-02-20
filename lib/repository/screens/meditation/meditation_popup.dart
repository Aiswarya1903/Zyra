import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class PopupMeditation extends StatefulWidget {
  final String? mood;
  final String duration;

  const PopupMeditation({
    super.key,
    required this.mood,
    required this.duration,
  });

  @override
  State<PopupMeditation> createState() => _PopupMeditationState();
}

class _PopupMeditationState extends State<PopupMeditation> {
  late int totalSeconds;
  int remainingSeconds = 0;
  Timer? timer;

  bool isRunning = false;
  bool isPaused = false;

  final AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    totalSeconds = _getSeconds(widget.duration);
    remainingSeconds = totalSeconds;
  }

  // -------- Dynamic Duration Fix --------
  int _getSeconds(String duration) {
    int minutes = int.parse(duration.split(" ")[0]);
    return minutes * 60;
  }

  // -------- Audio Path Mapping --------
  String _getAudioPath() {
    String moodValue = widget.mood ?? "stress";
    String minutes = widget.duration.split(" ")[0];
    String moodKey = moodValue.toLowerCase().replaceAll(" ", "");

    return 'audio/${moodKey}_${minutes}.mp3';
  }

  // -------- Start / Resume --------
  void startTimer() async {
    if (isRunning) return;

    if (isPaused) {
      await player.resume();
    } else {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(_getAudioPath()));
    }

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        finishSession();
      }
    });

    setState(() {
      isRunning = true;
      isPaused = false;
    });
  }

  // -------- Pause --------
  void pauseTimer() async {
    timer?.cancel();
    await player.pause();

    setState(() {
      isRunning = false;
      isPaused = true;
    });
  }

  // -------- Cancel / Reset --------
  void resetTimer() async {
    timer?.cancel();
    await player.stop();

    setState(() {
      remainingSeconds = totalSeconds;
      isRunning = false;
      isPaused = false;
    });
  }

  // -------- Auto Finish --------
  void finishSession() async {
    timer?.cancel();
    await player.stop();

    Navigator.pop(context);
  }

  // -------- Time Format --------
  String get timeText {
    int minutes = remainingSeconds ~/ 60;
    int seconds = remainingSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = remainingSeconds / totalSeconds;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xE8EDF4D3),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -------- Circular Timer --------
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Transform.rotate(
                    angle: -3.14 / 2,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 14,
                      backgroundColor: const Color(0xFFE0E0E0),
                      color: const Color(0xFF9CBE8D),
                    ),
                  ),
                ),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D6D57),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // -------- Mood + Duration --------
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF95B289)),
              ),
              child: Text(
                "${widget.mood ?? 'Mood'} • ${widget.duration}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D6D57),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            // -------- Buttons --------
            Row(
              children: [
                // Cancel
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      resetTimer();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA2C095),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),

                const SizedBox(width: 10),

                // Start / Stop
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (isRunning) {
                        pauseTimer();
                      } else {
                        startTimer();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CBD8F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(isRunning ? "Stop" : "Start"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
