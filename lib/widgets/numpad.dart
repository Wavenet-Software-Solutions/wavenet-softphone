import 'package:flutter/material.dart';

class Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const Numpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonSize = size.width * 0.22; // scales for all screen sizes

    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Build the keypad grid
        for (var row in buttons)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) {
                return _buildButton(context, digit, buttonSize);
              }).toList(),
            ),
          ),
        const SizedBox(height: 12),
        // Backspace icon at bottom center

      ],
    );
  }

  Widget _buildButton(BuildContext context, String digit, double size) {
    return InkWell(
      onTap: () => onDigit(digit),
      borderRadius: BorderRadius.circular(size / 2),
      splashColor: Colors.tealAccent.withOpacity(0.2),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white30, width: 1),
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 26,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
