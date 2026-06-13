import 'dart:io';

void main() {
  var file = File('lib/widgets/agent_network_painter.dart');
  var content = file.readAsStringSync()
    ..replaceAll(RegExp(r'const MaskFilter\.blur'), 'MaskFilter.blur');
  
  file.writeAsStringSync(content);
  print('Fixed MaskFilter issues');
}
