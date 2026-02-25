import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const WorkoutDetailScreen({super.key, required this.exercise});

  Future<void> _openYoutube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _intensityColor(String intensity) {
    switch (intensity.toLowerCase()) {
      case 'high': return const Color(0xFFE57373);
      case 'medium': return const Color(0xFFFFB74D);
      default: return const Color(0xFF95B289);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = exercise['exerciseName'] ?? '';
    final sets = exercise['sets']?.toString() ?? '3';
    final duration = exercise['Duration']?.toString() ?? '30';
    final muscle = exercise['muscleGroup'] ?? '';
    final intensity = exercise['intensity'] ?? 'Low';
    final youtube = exercise['youtubeLink'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFEDF4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDF4D3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5D6D57)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D6D57),
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── YouTube play button card ──────────────────────────────────
            GestureDetector(
              onTap: youtube.isNotEmpty ? () => _openYoutube(youtube) : null,
              child: Container(
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFF95B289).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF95B289), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF95B289),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF95B289).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Watch on YouTube",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5D6D57),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Tap to see how it's done",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats — 2×2 grid prevents overflow on all screen sizes ────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF95B289).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _stat("Sets", sets, Icons.repeat_rounded)),
                      _vDivider(),
                      Expanded(
                          child: _stat(
                              "Duration", "${duration}s", Icons.timer_outlined)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                      color: const Color(0xFF95B289).withOpacity(0.3),
                      height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _stat(
                              "Muscle", muscle, Icons.fitness_center_rounded)),
                      _vDivider(),
                      Expanded(
                          child: _statBadge(
                              "Intensity", intensity, _intensityColor(intensity))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tips 
            const Text(
              "Tips for today",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A4336),
              ),
            ),
            const SizedBox(height: 12),
            _tip("🌿", "Focus on your breathing throughout the movement"),
            _tip("🌿", "Move slowly and with control — no rushing"),
            _tip("🌿", "Stop if you feel sharp pain — listen to your body"),
            _tip("🌿", "Hydrate before and after the exercise"),
            _tip("🌿", "Rest 30–60 seconds between sets"),

            const SizedBox(height: 32),

            // ── Done button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF95B289),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Done ✓",
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A4336),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF95B289), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF3A4336),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
        height: 40,
        width: 1,
        color: const Color(0xFF95B289).withOpacity(0.3),
      );

  Widget _tip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
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
    );
  }
}