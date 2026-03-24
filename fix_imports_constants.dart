import 'dart:io';

void main() {
  final dir = Directory('c:/socialsteps/socialsteps-master/lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (var file in files) {
    if (file.path.endsWith('constants.dart')) continue;
    
    var content = file.readAsStringSync();
    if (content.contains('AppConstants') && !content.contains('constants.dart')) {
      content = "import 'package:socialsteps/utils/constants.dart';\n" + content;
      file.writeAsStringSync(content);
      print('Fixed \${file.path}');
    }
  }
}
