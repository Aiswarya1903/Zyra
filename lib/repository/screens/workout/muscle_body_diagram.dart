import 'package:flutter/material.dart';

/// Displays a pre-made muscle-group PNG image from assets/images/.
class MuscleBodyDiagram extends StatelessWidget {
  final String muscleGroup;
  final Color highlightColor;
  final double imageHeight;

  const MuscleBodyDiagram({
    super.key,
    required this.muscleGroup,
    this.highlightColor = const Color(0xFF95B289),
    this.imageHeight = 160,
  });

  static String _assetName(String raw) {
    // Normalise: lowercase + strip extra spaces
    final key = raw.trim().toLowerCase();

    const map = {
      'calves':      'calves',
      'calf':        'calves',
      'back':        'back',
      'upper back':  'back',
      'chest':       'chest',
      'lower back':  'lowerback',
      'lowerback':   'lowerback',
      'spine':       'spine',
      'legs':        'legs',
      'leg':         'legs',
      'thighs':      'legs',
      'abs':         'abs',
      'core':        'core',
      'glutes':      'glutes',
      'glute':       'glutes',
      'hips':        'hips',
      'hip':         'hips',
      'full body':   'fullbody',
      'fullbody':    'fullbody',
      'whole body':  'fullbody',
      'shoulders':   'shoulders',
      'shoulder':    'shoulders',
      'cardio':      'cardio',
      'flexibility': 'flexibility',
      'mobility':    'mobility',
      'relaxation':  'mobility',
      'stretching':  'flexibility',
    };

    final result = map[key];
    if (result == null) {
      // Log unmapped values so you can see exactly what string is coming in
      debugPrint('[MuscleBodyDiagram] ⚠️ Unmapped muscleGroup: "$raw" (normalised: "$key") → defaulting to fullbody');
    }
    return result ?? 'fullbody';
  }

  @override
  Widget build(BuildContext context) {
    final assetFile = _assetName(muscleGroup);
    final asset = 'assets/images/$assetFile.png';

    // Debug: print what asset is being used
    debugPrint('[MuscleBodyDiagram] muscleGroup="$muscleGroup" → asset="$asset"');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: imageHeight,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (_, error, __) {
              debugPrint('[MuscleBodyDiagram] ❌ Failed to load "$asset": $error');
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fitness_center, size: 48, color: highlightColor.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      muscleGroup,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: highlightColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: highlightColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: highlightColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: highlightColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                muscleGroup,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlightColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}