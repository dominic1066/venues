import 'dart:developer' as developer;

void main() {
  // Test different ways of printing to see which one causes spacing issues
  
  print('=== Testing different print methods ===');
  
  // Method 1: Regular print
  print('Line 1 - regular print');
  print('Line 2 - regular print');
  print('Line 3 - regular print');
  
  print('');
  
  // Method 2: debugPrint (Flutter)
  try {
    // This might not work in pure Dart
    // debugPrint('Line 1 - debugPrint');
    // debugPrint('Line 2 - debugPrint');
  } catch (e) {
    print('debugPrint not available in this context');
  }
  
  // Method 3: developer.log
  developer.log('Line 1 - developer.log');
  developer.log('Line 2 - developer.log');
  developer.log('Line 3 - developer.log');
  
  print('');
  
  // Method 4: stdout.writeln
  // stdout.writeln('Line 1 - stdout.writeln');
  // stdout.writeln('Line 2 - stdout.writeln');
  
  print('=== Test complete ===');
}