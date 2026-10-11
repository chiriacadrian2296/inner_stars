import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/area_hero_art.dart';
import '../utils/icon_for_slug.dart';
import '../utils/app_modals.dart';
import '../widgets/area_icon.dart';

typedef _Proposal = ({String slug, IconData icon, String note, bool art});

const _proposals = <LifeArea, List<_Proposal>>{
  LifeArea.physical: [
    (
      slug: 'shield',
      icon: Icons.shield,
      note: 'Protezione e forza: richiama il carattere araldico della spada.',
      art: true,
    ),
    (
      slug: 'sports_martial_arts',
      icon: Icons.sports_martial_arts,
      note: 'Corpo in movimento, disciplina e forza.',
      art: false,
    ),
    (
      slug: 'health_and_safety',
      icon: Icons.health_and_safety,
      note: 'Cura del corpo e salute, dentro uno scudo.',
      art: true,
    ),
    (
      slug: 'sports_gymnastics',
      icon: Icons.sports_gymnastics,
      note: 'Movimento e flessibilità; più sportiva che araldica.',
      art: false,
    ),
  ],
  LifeArea.psychological: [
    (
      slug: 'lightbulb_outline',
      icon: Icons.lightbulb_outline,
      note: 'Luce e chiarezza: vicina all’idea della lanterna nell’art.',
      art: true,
    ),
    (
      slug: 'psychology_alt',
      icon: Icons.psychology_alt,
      note: 'Mente e comprensione di sé, più esplicita della lanterna.',
      art: false,
    ),
    (
      slug: 'local_library',
      icon: Icons.local_library,
      note: 'Conoscenza e introspezione; richiama il libro alla base dell’art.',
      art: true,
    ),
    (
      slug: 'tips_and_updates',
      icon: Icons.tips_and_updates,
      note: 'Una luce con scintille: intuizione e consapevolezza.',
      art: true,
    ),
  ],
  LifeArea.professional: [
    (
      slug: 'military_tech',
      icon: Icons.military_tech,
      note: 'Medaglia con nastro: il richiamo più diretto al medaglione dell’art.',
      art: true,
    ),
    (
      slug: 'workspace_premium',
      icon: Icons.workspace_premium,
      note: 'Riconoscimento e competenza, con forma da medaglia.',
      art: true,
    ),
    (
      slug: 'work_outline',
      icon: Icons.work_outline,
      note: 'Lavoro riconoscibile subito, con un tratto più leggero.',
      art: false,
    ),
    (
      slug: 'track_changes',
      icon: Icons.track_changes,
      note: 'Obiettivi e direzione; richiama i cerchi concentrici dell’art.',
      art: true,
    ),
  ],
  LifeArea.financial: [
    (
      slug: 'emoji_events',
      icon: Icons.emoji_events,
      note: 'Coppa: è la sagoma più vicina all’art, ma può leggere come vittoria.',
      art: true,
    ),
    (
      slug: 'savings_outlined',
      icon: Icons.savings_outlined,
      note: 'Risparmio, immediato e familiare.',
      art: false,
    ),
    (
      slug: 'account_balance_outlined',
      icon: Icons.account_balance_outlined,
      note: 'Solidità e patrimonio; più istituzionale.',
      art: false,
    ),
    (
      slug: 'diamond',
      icon: Icons.diamond,
      note: 'Valore e ricchezza, coerente con il tono prezioso dell’art.',
      art: false,
    ),
  ],
  LifeArea.personal: [
    (
      slug: 'anchor',
      icon: Icons.anchor,
      note: 'Ancora: corrispondenza diretta con l’art, radici e stabilità.',
      art: true,
    ),
    (
      slug: 'person_outline',
      icon: Icons.person_outline,
      note: 'Identità personale, essenziale e leggibile.',
      art: false,
    ),
    (
      slug: 'fingerprint',
      icon: Icons.fingerprint,
      note: 'Unicità e identità: personale senza suggerire meditazione.',
      art: false,
    ),
    (
      slug: 'person_pin_circle',
      icon: Icons.person_pin_circle,
      note: 'La persona al centro, con l’idea di un proprio posto.',
      art: false,
    ),
  ],
  LifeArea.social: [
    (
      slug: 'diversity_1',
      icon: Icons.diversity_1,
      note: 'La tua proposta: persone e cuore, unisce comunità e affetto.',
      art: true,
    ),
    (
      slug: 'diversity_2',
      icon: Icons.diversity_2,
      note: 'Unione e gruppo: richiama la composizione circolare dell’art.',
      art: true,
    ),
    (
      slug: 'diversity_3',
      icon: Icons.diversity_3,
      note: 'Persone insieme, più vicina all’attuale groups.',
      art: false,
    ),
    (
      slug: 'connect_without_contact',
      icon: Icons.connect_without_contact,
      note: 'Connessione e scambio fra persone.',
      art: false,
    ),
  ],
  LifeArea.spiritual: [
    (
      slug: 'brightness_7',
      icon: Icons.brightness_7,
      note: 'Centro e raggi: richiama la struttura del mandala nell’art.',
      art: true,
    ),
    (
      slug: 'filter_vintage',
      icon: Icons.filter_vintage,
      note: 'Rosetta a petali: vicina al motivo floreale centrale dell’art.',
      art: true,
    ),
    (
      slug: 'self_improvement',
      icon: Icons.self_improvement,
      note: 'Meditazione e raccoglimento; oggi è l’icona di Personal.',
      art: false,
    ),
    (
      slug: 'auto_awesome',
      icon: Icons.auto_awesome,
      note: 'Luce e trascendenza, in continuità con le stelle.',
      art: false,
    ),
  ],
  LifeArea.philanthropic: [
    (
      slug: 'volunteer_activism_outlined',
      icon: Icons.volunteer_activism_outlined,
      note: 'Mano e cuore: dono e cura, vicina al cuore dell’art.',
      art: true,
    ),
    (
      slug: 'favorite_border',
      icon: Icons.favorite_border,
      note: 'Cuore essenziale: richiama la sagoma principale dell’art.',
      art: true,
    ),
    (
      slug: 'groups_3',
      icon: Icons.groups_3,
      note: 'Persone che si sostengono, con una lettura collettiva.',
      art: false,
    ),
    (
      slug: 'public',
      icon: Icons.public,
      note: 'Impatto sul mondo e bene comune.',
      art: false,
    ),
  ],
};

const _extraProposals = <LifeArea, List<(String, IconData, String)>>{
  LifeArea.physical: [
    (
      'directions_walk',
      Icons.directions_walk,
      'Movimento quotidiano e abitudini attive.',
    ),
    ('sports', Icons.sports, 'Allenamento, attività e disciplina.'),
    (
      'monitor_heart',
      Icons.monitor_heart,
      'Salute, vitalità e ascolto del corpo.',
    ),
    ('fitness_center', Icons.fitness_center, 'Forza e allenamento.'),
    ('healing', Icons.healing, 'Recupero e cura del corpo.'),
    ('sports_kabaddi', Icons.sports_kabaddi, 'Energia fisica e movimento.'),
    ('directions_run', Icons.directions_run, 'Resistenza e attività aerobica.'),
    ('pool', Icons.pool, 'Movimento fluido e benessere fisico.'),
  ],
  LifeArea.psychological: [
    (
      'sentiment_satisfied_alt',
      Icons.sentiment_satisfied_alt,
      'Benessere emotivo e serenità.',
    ),
    ('mood', Icons.mood, 'Umore ed emozioni.'),
    ('balance', Icons.balance, 'Equilibrio interiore.'),
    ('healing', Icons.healing, 'Cura e recupero emotivo.'),
    (
      'model_training',
      Icons.model_training,
      'Evoluzione dei propri schemi mentali.',
    ),
    ('spa', Icons.spa, 'Calma e pace interiore.'),
    ('insights', Icons.insights, 'Comprensione di sé e nuove prospettive.'),
    (
      'sentiment_neutral',
      Icons.sentiment_neutral,
      'Osservare le emozioni con equilibrio.',
    ),
  ],
  LifeArea.professional: [
    ('school', Icons.school, 'Formazione e competenza.'),
    ('trending_up', Icons.trending_up, 'Crescita professionale.'),
    (
      'engineering',
      Icons.engineering,
      'Competenza applicata e lavoro concreto.',
    ),
    ('business_center', Icons.business_center, 'Carriera e responsabilità.'),
    ('badge', Icons.badge, 'Identità professionale.'),
    ('insights', Icons.insights, 'Strategia e risultati.'),
    ('architecture', Icons.architecture, 'Progettazione e precisione.'),
    ('account_tree', Icons.account_tree, 'Organizzazione e processi.'),
  ],
  LifeArea.financial: [
    ('payments', Icons.payments, 'Denaro e gestione delle risorse.'),
    ('wallet', Icons.wallet, 'Finanze personali.'),
    (
      'currency_exchange',
      Icons.currency_exchange,
      'Flussi e scambio di valore.',
    ),
    ('price_check', Icons.price_check, 'Scelte economiche consapevoli.'),
    ('request_quote', Icons.request_quote, 'Pianificazione e budget.'),
    ('show_chart', Icons.show_chart, 'Investimenti e crescita.'),
    ('paid', Icons.paid, 'Valore economico, espresso direttamente.'),
    ('lock_outline', Icons.lock_outline, 'Sicurezza e indipendenza economica.'),
  ],
  LifeArea.personal: [
    ('explore', Icons.explore, 'La propria direzione e la scoperta di sé.'),
    ('auto_stories', Icons.auto_stories, 'La propria storia e crescita.'),
    ('interests', Icons.interests, 'Passioni e interessi personali.'),
    ('face', Icons.face, 'Identità e individualità.'),
    ('emoji_objects', Icons.emoji_objects, 'Idee e potenziale personale.'),
    ('person', Icons.person, 'La persona al centro.'),
    ('home', Icons.home, 'Il proprio spazio e senso di appartenenza.'),
    ('track_changes', Icons.track_changes, 'Obiettivi e direzione personale.'),
  ],
  LifeArea.social: [
    ('handshake', Icons.handshake, 'Fiducia e reciprocità.'),
    ('forum', Icons.forum, 'Dialogo e scambio.'),
    ('people_alt', Icons.people_alt, 'Relazioni e vicinanza.'),
    ('group_work', Icons.group_work, 'Collaborazione e comunità.'),
    ('hub', Icons.hub, 'Rete di relazioni.'),
    (
      'sentiment_very_satisfied',
      Icons.sentiment_very_satisfied,
      'Gioia condivisa.',
    ),
    (
      'celebration',
      Icons.celebration,
      'Celebrare insieme e stare in compagnia.',
    ),
    ('favorite_border', Icons.favorite_border, 'Affetto e legami.'),
  ],
  LifeArea.spiritual: [
    ('flare', Icons.flare, 'Luce interiore e irradiazione.'),
    ('wb_sunny', Icons.wb_sunny, 'Luce e vitalità spirituale.'),
    ('wb_twilight', Icons.wb_twilight, 'Contemplazione e passaggio.'),
    ('nights_stay', Icons.nights_stay, 'Silenzio e raccoglimento.'),
    (
      'temple_buddhist',
      Icons.temple_buddhist,
      'Uno spazio per la pratica spirituale.',
    ),
    ('spa', Icons.spa, 'Pace, armonia e meditazione.'),
    ('church', Icons.church, 'Fede e pratica religiosa; lettura specifica.'),
    (
      'blur_on',
      Icons.blur_on,
      'Unità e connessione con qualcosa di più grande.',
    ),
  ],
  LifeArea.philanthropic: [
    ('eco', Icons.eco, 'Cura del pianeta.'),
    ('support', Icons.support, 'Sostegno e aiuto concreto.'),
    (
      'support_agent',
      Icons.support_agent,
      'Ascolto e disponibilità verso gli altri.',
    ),
    ('card_giftcard', Icons.card_giftcard, 'Dono e generosità.'),
    (
      'handshake_outlined',
      Icons.handshake_outlined,
      'Solidarietà e impegno reciproco.',
    ),
    (
      'health_and_safety',
      Icons.health_and_safety,
      'Proteggere e prendersi cura.',
    ),
    ('language', Icons.language, 'Responsabilità verso la comunità globale.'),
    ('diversity_2', Icons.diversity_2, 'Unione e sostegno collettivo.'),
  ],
};

/// Compare area icon proposals with the active artwork in the Lab.
class AreaIconLabScreen extends StatefulWidget {
  const AreaIconLabScreen({super.key});

  @override
  State<AreaIconLabScreen> createState() => _AreaIconLabScreenState();
}

class _AreaIconLabScreenState extends State<AreaIconLabScreen> {
  final _chosen = <LifeArea, _Proposal>{};

  List<_Proposal> _choices(LifeArea area) => [
    (
      slug: 'art_${area.name}',
      icon: area.icon,
      note: 'Art attuale dell’area, in versione compatta.',
      art: true,
    ),
    (
      slug: area.iconSlug,
      icon: area.icon,
      note: 'Precedente icona Material dell’area.',
      art: false,
    ),
    ..._proposals[area]!,
    for (final (slug, icon, note) in _extraProposals[area]!)
      if (slug != area.iconSlug)
        (slug: slug, icon: icon, note: note, art: false),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.menuAreaIconLab)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850 ? 2 : 1;
              final rows = (LifeArea.values.length / columns).ceil();
              return Column(
                children: [
                  SizedBox(
                    height: 24,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Tocca per i dettagli · punto oro: richiamo all’art · bordo oro: scelta',
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                    ),
                  ),
                  for (var row = 0; row < rows; row++) ...[
                    if (row > 0) const SizedBox(height: 4),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var column = 0; column < columns; column++) ...[
                            if (column > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _areaPanel(
                                LifeArea.values[row * columns + column],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _areaPanel(LifeArea area) {
    final colors = context.colors;
    final choices = _choices(area);
    final selectedSlug = _chosen[area]?.slug ?? 'art_${area.name}';
    return Container(
      key: ValueKey('area-panel-${area.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.nightPanel,
        borderRadius: BorderRadius.circular(kRadiusField),
        border: Border.all(color: colors.nightBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomy = constraints.maxHeight >= 130;
          final headerHeight = roomy ? 36.0 : 18.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: headerHeight,
                child: Row(
                  children: [
                    Image.asset(
                      kAreaHeroArt[area]!.skyAsset,
                      width: headerHeight,
                      height: headerHeight,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        area.displayName(context.strings),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: roomy ? 15 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AreaIcon(area: area, size: roomy ? 20 : 14),
                    const SizedBox(width: 4),
                    Text(
                      'attuale',
                      style: TextStyle(color: colors.muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, grid) {
                    final columns = (grid.maxWidth / 38).floor().clamp(
                      1,
                      choices.length,
                    );
                    final rows = (choices.length / columns).ceil();
                    final cellHeight = (grid.maxHeight - (rows - 1) * 2) / rows;
                    final iconSize = (cellHeight - 4).clamp(12.0, 28.0);
                    final showNames = cellHeight >= 50;
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: cellHeight,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 3,
                      ),
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final proposal = choices[index];
                        final selected = proposal.slug == selectedSlug;
                        return Tooltip(
                          message: '${proposal.slug}\n${proposal.note}',
                          child: Semantics(
                            label:
                                '${area.displayName(context.strings)}: ${proposal.slug}',
                            selected: selected,
                            button: true,
                            child: InkWell(
                              key: ValueKey(
                                'area-icon-${area.name}-${proposal.slug}',
                              ),
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() {
                                  if (proposal.slug == 'art_${area.name}') {
                                    _chosen.remove(area);
                                  } else {
                                    _chosen[area] = proposal;
                                  }
                                });
                                _showDetails(area, proposal);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: selected
                                        ? colors.gold
                                        : colors.nightBorder,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (proposal.slug ==
                                              'art_${area.name}')
                                            AreaIcon(
                                              area: area,
                                              size: showNames ? 28 : iconSize,
                                              color: selected
                                                  ? colors.gold
                                                  : colors.muted,
                                            )
                                          else
                                            Icon(
                                              proposal.icon,
                                              size: showNames ? 28 : iconSize,
                                              color: selected
                                                  ? colors.gold
                                                  : colors.muted,
                                            ),
                                          if (showNames)
                                            Text(
                                              proposal.slug,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.muted,
                                                fontSize: 8,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (proposal.art)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: colors.gold,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDetails(LifeArea area, _Proposal proposal) async {
    final otherAreas = LifeArea.values.where(
      (other) => other != area && other.icon == proposal.icon,
    );
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.colors;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSheetTitle(area.displayName(context.strings)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Image.asset(
                        kAreaHeroArt[area]!.skyAsset,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          if (proposal.slug == 'art_${area.name}')
                            AreaIcon(area: area, size: 56)
                          else
                            Icon(proposal.icon, size: 56, color: colors.gold),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final size in [18.0, 24.0, 32.0])
                                if (proposal.slug == 'art_${area.name}')
                                  AreaIcon(area: area, size: size)
                                else
                                  Icon(
                                    proposal.icon,
                                    size: size,
                                    color: colors.text,
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(
                  proposal.slug,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  proposal.note,
                  style: TextStyle(color: colors.muted, height: 1.4),
                ),
                if (proposal.art)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Richiamo all’art',
                      style: TextStyle(color: colors.gold),
                    ),
                  ),
                if (availableIconSlugs.contains(proposal.slug))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Già nel catalogo delle icone costellazione',
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
                for (final other in otherAreas)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Già usata da ${other.displayName(context.strings)}',
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: AppButtonLabel(context.strings.closeAction),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
