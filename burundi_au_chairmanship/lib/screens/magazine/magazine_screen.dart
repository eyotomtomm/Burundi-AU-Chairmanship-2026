import 'package:flutter/material.dart';
import '../home/tabs/magazine_tab.dart';

/// Quick-access magazine page — reuses the same MagazineTab widget
/// that is shown inside the home screen tabs.
class MagazineScreen extends StatelessWidget {
  const MagazineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MagazineTab(
      onBackToHome: () => Navigator.pop(context),
    );
  }
}
