import 'package:flutter/services.dart';

class TRPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Get only digits from new value
    final digitsOnNew = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // 2. Limit to 10 digits
    final limitedDigits = digitsOnNew.length > 10 
        ? digitsOnNew.substring(0, 10) 
        : digitsOnNew;

    // 3. Format: 5XX XXX XX XX
    final buffer = StringBuffer();
    for (int i = 0; i < limitedDigits.length; i++) {
      // Add formatting spaces
      if (i == 3 || i == 6 || i == 8) {
        buffer.write(' ');
      }
      buffer.write(limitedDigits[i]);
    }

    final formattedText = buffer.toString();

    // 4. Calculate new cursor position
    // This is a naive implementation; for complex editing (middle), it might bounce.
    // Ideally we track the cursor relative to digits.
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
