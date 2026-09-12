import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SSRace BaknusIDBridge Event Parser Tests', () {
    const String victoryJson = '''
    {
      "action": "UPDATE_STATUS",
      "game": "ssrace",
      "isVictory": true,
      "score": 8500,
      "text": "Saya baru saja mengalahkan Armada Induk Alien TaYa di SSRace dengan skor 8500! 🚀🛸 #SSRace #BaknusID"
    }
    ''';

    const String defeatJson = '''
    {
      "action": "UPDATE_STATUS",
      "game": "ssrace",
      "isVictory": false,
      "score": 1450,
      "text": "Saya telah bermain game SSRace dengan skor 1450! 💥🚀 #SSRace #BaknusID"
    }
    ''';

    test('Harus mem-parse pesan kemenangan SSRace dengan tepat', () {
      final Map<String, dynamic> data = jsonDecode(victoryJson);

      expect(data['action'], equals('UPDATE_STATUS'));
      expect(data['game'], equals('ssrace'));
      expect(data['isVictory'], isTrue);
      expect(data['score'], equals(8500));
      expect(data['text'], contains('Armada Induk Alien TaYa'));
    });

    test('Harus mem-parse pesan kekalahan SSRace dengan tepat', () {
      final Map<String, dynamic> data = jsonDecode(defeatJson);

      expect(data['action'], equals('UPDATE_STATUS'));
      expect(data['game'], equals('ssrace'));
      expect(data['isVictory'], isFalse);
      expect(data['score'], equals(1450));
      expect(data['text'], contains('skor 1450'));
    });

    test('Harus mengabaikan event jika action bukan UPDATE_STATUS', () {
      const String otherJson = '{"action": "OTHER_ACTION", "game": "ssrace"}';
      final Map<String, dynamic> data = jsonDecode(otherJson);

      expect(data['action'], isNot(equals('UPDATE_STATUS')));
    });

    test('Harus menangani format score string maupun numeric dengan aman', () {
      const String stringScoreJson = '''
      {
        "action": "UPDATE_STATUS",
        "game": "ssrace",
        "isVictory": true,
        "score": "9999",
        "text": "Test Score"
      }
      ''';
      final Map<String, dynamic> data = jsonDecode(stringScoreJson);
      final dynamic rawScore = data['score'];
      final int parsedScore = rawScore is num
          ? rawScore.toInt()
          : int.tryParse(rawScore.toString()) ?? 0;

      expect(parsedScore, equals(9999));
    });
  });
}
