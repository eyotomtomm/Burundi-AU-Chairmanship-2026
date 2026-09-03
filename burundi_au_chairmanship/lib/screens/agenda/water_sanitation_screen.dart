import 'package:flutter/material.dart';
import 'agenda_detail_screen.dart';

class WaterSanitationScreen extends StatelessWidget {
  const WaterSanitationScreen({super.key});

  @override
  Widget build(BuildContext context) => const AgendaDetailScreen(
        slug: 'water-sanitation',
        icon: Icons.water_drop_rounded,
        fallbackTitle: 'Water & Sanitation',
        fallbackTitleFr: 'Eau et Assainissement',
        labels: AgendaLabels(
          overview: 'Overview',
          objectives: 'Key objectives',
          impacts: 'Impact areas',
          initiatives: 'Current initiatives',
          objectivesStat: 'Objectives',
          impactsStat: 'Focus areas',
        ),
        labelsFr: AgendaLabels(
          overview: 'Aperçu',
          objectives: 'Objectifs clés',
          impacts: "Domaines d'impact",
          initiatives: 'Initiatives en cours',
          objectivesStat: 'Objectifs',
          impactsStat: 'Domaines',
        ),
      );
}
