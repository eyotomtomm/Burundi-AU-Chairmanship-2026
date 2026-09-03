import 'package:flutter/material.dart';
import 'agenda_detail_screen.dart';

class PeaceSecurityScreen extends StatelessWidget {
  const PeaceSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) => const AgendaDetailScreen(
        slug: 'peace-security',
        icon: Icons.security_rounded,
        fallbackTitle: 'Peace & Security',
        fallbackTitleFr: 'Paix et Sécurité',
        labels: AgendaLabels(
          overview: 'Commitment to peace',
          objectives: 'Priority actions',
          impacts: 'Key initiatives',
          initiatives: 'Silencing the guns',
          objectivesStat: 'Actions',
          impactsStat: 'Initiatives',
        ),
        labelsFr: AgendaLabels(
          overview: 'Engagement pour la paix',
          objectives: 'Actions prioritaires',
          impacts: 'Initiatives clés',
          initiatives: 'Faire taire les armes',
          objectivesStat: 'Actions',
          impactsStat: 'Initiatives',
        ),
      );
}
