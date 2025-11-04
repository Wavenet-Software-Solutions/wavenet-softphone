import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback

class Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool showLetters; // optional toggle for letters under numbers 💫

  const Numpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.showLetters = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonSize = size.width * 0.22; // scales for all screen sizes

    final Map<String, String> labels = {
      '1': '',
      '2': 'ABC',
      '3': 'DEF',
      '4': 'GHI',
      '5': 'JKL',
      '6': 'MNO',
      '7': 'PQRS',
      '8': 'TUV',
      '9': 'WXYZ',
      '*': '',
      '0': '+',
      '#': '',
    };

    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 🌸 Build the keypad grid
        for (var row in buttons)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) {
                return _buildButton(
                  context,
                  digit,
                  labels[digit] ?? '',
                  buttonSize,
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 16),


      ],
    );
  }

  Widget _buildButton(
      BuildContext context, String digit, String letters, double size) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
      },
      onTap: () {
        onDigit(digit);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white30, width: 1),
        ),
        alignment: Alignment.center,
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.tealAccent.withOpacity(0.2),
          highlightColor: Colors.tealAccent.withOpacity(0.05),
          onTap: () {
            HapticFeedback.selectionClick();
            onDigit(digit);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                digit,
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              if (showLetters && letters.isNotEmpty)
                Text(
                  letters,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 0.8,
                    decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
