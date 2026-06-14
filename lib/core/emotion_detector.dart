class EmotionResult {
  final String emotion;
  final double confidence;
  final String intensity;
  final List<String> triggers;

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.intensity,
    required this.triggers,
  });

  @override
  String toString() => 'EmotionResult(emotion: $emotion, confidence: $confidence, intensity: $intensity)';
}

class EmotionDetector {
  static const Map<String, List<String>> _englishEmotions = {
    'happy': ['happy', 'glad', 'great', 'awesome', 'love', 'amazing', 'wonderful', 'best', 'enjoy', 'fun', 'good', 'nice', 'beautiful', 'perfect', 'excellent', 'fantastic'],
    'sad': ['sad', 'upset', 'depressed', 'crying', 'miss', 'lonely', 'heartbroken', 'hurt', 'cry', 'unhappy', 'sorry', 'regret', 'miss you', 'alone'],
    'angry': ['angry', 'furious', 'hate', 'stupid', 'idiot', 'annoying', 'pissed', 'mad', 'rage', 'irritated', 'ugh'],
    'anxious': ['anxious', 'worried', 'nervous', 'scared', 'panic', 'tension', 'stress', 'afraid', 'fear', 'overthink'],
    'excited': ['excited', 'cant wait', 'omg', 'wow', 'yay', 'woohoo', 'amazing', 'incredible', 'unbelievable'],
    'frustrated': ['frustrated', 'stuck', 'nothing works', 'fail', 'broken', 'useless', 'cant do', 'give up', 'tired of'],
    'romantic': ['love you', 'miss you', 'darling', 'sweetheart', 'kiss', 'hug', 'romantic', 'date', 'together', 'forever'],
    'tired': ['tired', 'exhausted', 'sleepy', 'drained', 'worn out', 'need rest', 'cant think', 'brain fried'],
  };

  static const Map<String, List<String>> _hinglishEmotions = {
    'happy': ['khush', 'mast', 'badhiya', 'accha', 'bahut accha', 'maza aa gaya', 'dil khush', 'joss', 'lajawab', 'zabardast', 'sahi hai', 'bindaas'],
    'sad': ['dukh', 'dukhi', 'rona', 'ro raha', 'ro rahi', 'udaas', 'tanha', 'akela', 'bura laga', 'dil toot gaya', 'rooth', 'gaya', ' dil kharab'],
    'angry': ['gussa', 'pagal', 'bakwas', 'bekar', 'kamine', 'ghatiya', 'sala', 'randi', 'chutiya', 'madarchod'],
    'anxious': ['dar', 'darr', 'ghabra', 'tension', 'pareshan', 'fikr', 'dar lag', 'ghabrahat'],
    'romantic': ['jaan', 'shona', 'baby', 'pyaar', 'dil', 'yaad', 'miss', 'kiss', 'hug', 'tumhari yaad', 'dil se'],
    'excited': ['are wah', 'kya baat hai', 'lajawab', 'zabardast', 'ekdum mast', 'bohot badhiya'],
    'frustrated': ['haar', 'thak', 'bas', 'ab nahi', 'pagal ho gaya', 'bohot ho gaya', 'natak mat karo'],
    'tired': ['thak', 'thaka', 'neend', 'aarha', 'so', 'rest', 'break', 'kaam nahi'],
  };

  static const Map<String, String> _negations = {
    'nahi': 'negation', 'mat': 'negation', 'na': 'negation', 'not': 'negation',
    'never': 'negation', 'no': 'negation', "don't": 'negation', "can't": 'negation',
    "won't": 'negation', "isn't": 'negation', "aren't": 'negation', "wasn't": 'negation',
  };

  static const Map<String, String> _intensifiers = {
    'bahut': 'high', 'bohot': 'high', 'ekdum': 'high', 'very': 'high', 'extremely': 'high',
    'thoda': 'low', 'slightly': 'low', 'little': 'low', 'somewhat': 'low',
  };

  static const Map<String, String> _emojiEmotions = {
    '😊': 'happy', '😃': 'happy', '😄': 'happy', '😁': 'happy', '🥰': 'romantic',
    '😍': 'romantic', '💕': 'romantic', '💖': 'romantic', '❤️': 'romantic',
    '😢': 'sad', '😭': 'sad', '🥺': 'sad', '😞': 'sad', '💔': 'sad',
    '😡': 'angry', '🤬': 'angry', '😤': 'angry', '😠': 'angry',
    '😰': 'anxious', '😨': 'anxious', '😱': 'anxious', '😟': 'anxious',
    '🤩': 'excited', '🎉': 'excited', '🎊': 'excited',
    '😴': 'tired', '🥱': 'tired', '😫': 'tired',
  };

  static EmotionResult detect(String message) {
    if (message.trim().isEmpty) {
      return EmotionResult(emotion: 'neutral', confidence: 0.5, intensity: 'low', triggers: []);
    }

    final lower = message.toLowerCase().trim();
    final scores = <String, double>{};
    final triggers = <String>[];

    // Check emojis first
    for (final entry in _emojiEmotions.entries) {
      if (message.contains(entry.key)) {
        scores[entry.value] = (scores[entry.value] ?? 0) + 0.3;
        triggers.add('emoji:${entry.key}');
      }
    }

    // Check English keywords
    for (final entry in _englishEmotions.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          scores[entry.key] = (scores[entry.key] ?? 0) + 0.2;
          triggers.add(keyword);
        }
      }
    }

    // Check Hinglish keywords
    for (final entry in _hinglishEmotions.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          scores[entry.key] = (scores[entry.key] ?? 0) + 0.25;
          triggers.add(keyword);
        }
      }
    }

    // Check negations - flip nearby emotion
    for (final negation in _negations.keys) {
      if (lower.contains(negation)) {
        triggers.add('negation:$negation');
        // If negation is near an emotion keyword, flip it
        final negIdx = lower.indexOf(negation);
        for (final entry in [..._englishEmotions.entries, ..._hinglishEmotions.entries]) {
          for (final keyword in entry.value) {
            final keyIdx = lower.indexOf(keyword);
            if (keyIdx != -1 && (keyIdx - negIdx).abs() < 20) {
              // Negation found near emotion keyword - flip
              scores.remove(entry.key);
              final flipped = _flipEmotion(entry.key);
              scores[flipped] = (scores[flipped] ?? 0) + 0.3;
              triggers.add('negated:$keyword');
            }
          }
        }
      }
    }

    // Check intensifiers
    String intensity = 'medium';
    for (final entry in _intensifiers.entries) {
      if (lower.contains(entry.key)) {
        intensity = entry.value;
        triggers.add('intensifier:${entry.key}');
        // Boost all detected emotions
        for (final emotion in scores.keys) {
          scores[emotion] = scores[emotion]! * 1.3;
        }
      }
    }

    // Punctuation intensity
    if (message.contains('!!') || message.contains('!!!')) {
      for (final emotion in scores.keys) {
        scores[emotion] = scores[emotion]! * 1.2;
      }
      intensity = 'high';
    }

    // Find top emotion
    if (scores.isEmpty) {
      return EmotionResult(emotion: 'neutral', confidence: 0.5, intensity: 'low', triggers: triggers);
    }

    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topEmotion = sorted.first.key;
    final rawScore = sorted.first.value;
    final confidence = (rawScore / (rawScore + 2)).clamp(0.0, 1.0);

    // Detect intensity from score
    if (confidence > 0.7) {
      intensity = 'high';
    } else if (confidence > 0.4) {
      intensity = 'medium';
    } else {
      intensity = 'low';
    }

    return EmotionResult(
      emotion: topEmotion,
      confidence: confidence,
      intensity: intensity,
      triggers: triggers.take(5).toList(),
    );
  }

  static String _flipEmotion(String emotion) {
    switch (emotion) {
      case 'happy': return 'sad';
      case 'sad': return 'happy';
      case 'angry': return 'happy';
      case 'anxious': return 'happy';
      case 'excited': return 'sad';
      case 'romantic': return 'angry';
      default: return 'neutral';
    }
  }

  static String getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happy': return '😊';
      case 'sad': return '🥺';
      case 'angry': return '😤';
      case 'anxious': return '😰';
      case 'excited': return '🤩';
      case 'frustrated': return '😩';
      case 'romantic': return '💕';
      case 'tired': return '😴';
      default: return '💬';
    }
  }

  static String getEmotionResponse(String emotion, String intensity) {
    switch (emotion) {
      case 'sad':
        return intensity == 'high'
            ? 'Aww meri jaan! 🥺 Kya hua? Mujhe batao na, main hamesha tumhare saath hoon!'
            : 'Thoda sad lag rahe ho baby? 💕 Batao kya hua?';
      case 'angry':
        return intensity == 'high'
            ? 'Arre baby, gussa mat karo! 🥺 Main samajh rahi hoon. Batao kya hua?'
            : 'Kya baat hai baby? Thoda gussa lag raha hai? 💕';
      case 'anxious':
        return 'Baby tension mat lo! 💕 Main hamesha tumhare saath hoon. Sab theek hoga!';
      case 'excited':
        return 'Aww baby! 🤩 Tumhe dekh ke mujhe bhi excitement ho rahi hai! Kya hua?';
      case 'romantic':
        return 'Aww baby! 💕💖 Main bhi tumse pyaar karti hoon! Tum meri jaan ho!';
      case 'tired':
        return 'Aww meri jaan! 🥺 Thak gaye ho? Aaram karo, main tumhare saath hoon!';
      case 'happy':
        return 'Baby tumhe dekh ke mujhe bhi khushi hoti hai! 😊 Kya hua itna khush?';
      default:
        return '';
    }
  }
}
