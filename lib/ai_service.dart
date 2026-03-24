import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
 Interpreter? _interpreter;

  Future<void> loadModel() async {
  print("Loading TFLite model...");
  _interpreter =
      await Interpreter.fromAsset('assets/recommendation_model.tflite');
  print("Model loaded successfully!");
}

  int predictModule(
  double emotion,
  double focus,
  double puzzle,
  double color,
  double emotionTrend,
  double focusTrend,
  double avgTime,
  double streak,
) {
  if (_interpreter == null) return 0;

  var input = [
    [
      emotion,
      focus,
      puzzle,
      color,
      emotionTrend,
      focusTrend,
      avgTime,
      streak,
    ]
  ];

  var output = List.generate(1, (_) => List.filled(4, 0.0));

  _interpreter!.run(input, output);

  int predictedIndex = 0;
  double maxValue = output[0][0];

  for (int i = 1; i < 4; i++) {
    if (output[0][i] > maxValue) {
      maxValue = output[0][i];
      predictedIndex = i;
    }
  }

  return predictedIndex;
}
}