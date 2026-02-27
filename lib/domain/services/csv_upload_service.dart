import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutUploadTestService {
  /// Uploads ALL workouts from the CSV to Firestore.
  /// Uses deterministic doc IDs — safe to call multiple times without duplicates.
  static Future<void> uploadAllWorkouts() async {
    try {
      final csvString = await rootBundle.loadString('assets/zyra_workouts.csv');
      print("✅ CSV loaded successfully");

      final lines = LineSplitter.split(csvString).toList();
      print("📋 Total rows (including header): ${lines.length}");

      // Skip header row
      final dataLines =
          lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
      print("🏋️ Workouts to upload: ${dataLines.length}");

      final col = FirebaseFirestore.instance.collection('zyra_workouts');

      // Firestore batch — max 500 ops per batch
      var batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;
      int totalUploaded = 0;

      for (int i = 0; i < dataLines.length; i++) {
        final row = _parseCsvRow(dataLines[i]);

        // CSV columns: level,phase,day,exerciseName,sets,Duration,youtubeLink,muscleGroup,intensity,completed
        if (row.length < 9) {
          print("⚠️ Skipping malformed row $i: ${dataLines[i]}");
          continue;
        }

        final level = row[0].trim();
        final phase = row[1].trim();
        final day = int.tryParse(row[2].trim()) ?? 1;
        final exerciseName = row[3].trim();
        final sets = row[4].trim();
        final duration = row[5].trim();
        final youtubeLink = row[6].trim();
        final muscleGroup = row[7].trim();
        final intensity = row[8].trim();

        // Deterministic doc ID — prevents duplicates on re-upload
        final docId =
            '${level}_${phase}_day${day}_$exerciseName'
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

        final docRef = col.doc(docId);
        batch.set(docRef, {
          'level': level,
          'phase': phase,
          'day': day,
          'exerciseName': exerciseName,
          'sets': sets,
          'Duration': duration,
          'youtubeLink': youtubeLink,
          'muscleGroup': muscleGroup,
          'intensity': intensity,
        });

        batchCount++;
        totalUploaded++;

        // Commit every 499 to stay under the 500-op Firestore limit
        if (batchCount == 499) {
          await batch.commit();
          print("📦 Committed batch — $totalUploaded rows uploaded so far...");
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      // Commit any remaining ops
      if (batchCount > 0) {
        await batch.commit();
      }

      print("🎉 Done! $totalUploaded workouts uploaded to Firestore.");
    } catch (e, stack) {
      print("❌ Upload error: $e");
      print(stack);
    }
  }

  /// Parses a single CSV row, correctly handling quoted fields that contain commas.
  static List<String> _parseCsvRow(String row) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString()); // add the last field
    return result;
  }
}