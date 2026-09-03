import 'package:flutter/material.dart';
import 'agenda_detail_screen.dart';

class AriseInitiativeScreen extends StatelessWidget {
  const AriseInitiativeScreen({super.key});

  @override
  Widget build(BuildContext context) => const AgendaDetailScreen(
        slug: 'arise-initiative',
        debateCategory: 'arise',
        icon: Icons.trending_up_rounded,
        fallbackTitle: 'A-RISE Initiative',
        fallbackTitleFr: 'Initiative A-RISE',
        labels: AgendaLabels(
          overview: 'About A-RISE',
          objectives: 'Strategic pillars',
          impacts: 'Focus areas',
          initiatives: 'Expected outcomes',
          objectivesStat: 'Pillars',
          impactsStat: 'Focus areas',
        ),
        labelsFr: AgendaLabels(
          overview: 'À propos de A-RISE',
          objectives: 'Piliers stratégiques',
          impacts: 'Domaines prioritaires',
          initiatives: 'Résultats attendus',
          objectivesStat: 'Piliers',
          impactsStat: 'Domaines',
        ),
      );
}
