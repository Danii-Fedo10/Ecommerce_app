import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const kGreen = Color(0xFF078930);
const kYellow = Color(0xFFFCDD09);
const kRed = Color(0xFFDA121D);

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kGreen, secondary: kYellow, error: kRed),
      cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    );

final _fmt = NumberFormat('#,##0.##');
String etb(num v) => 'ETB ${_fmt.format(v)}';
