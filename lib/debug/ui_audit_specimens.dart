import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../widgets/app_field.dart';
import '../widgets/app_toggle_chip.dart';
import '../widgets/pill_action_button.dart';
import 'ui_audit_catalog.dart';

/// Kept separate from the audit prose so completeness is testable: every
/// catalogue id must have a visual comparison here, and no stale comparison
/// may survive after its audit entry is removed.
const supportedUiAuditSpecimenIds = <String>{
  'type-page-title-local',
  'type-section-title-local',
  'type-scale-candidate',
  'action-material-buttons',
  'action-save-pill',
  'action-pill-utility-danger',
  'action-cancel-meanings',
  'action-semantic-candidate',
  'field-shared',
  'field-raw-text-fields',
  'selection-toggle-chip',
  'selection-local-chips',
  'surface-panel-card',
  'surface-card-families',
  'overlay-alert-dialogs',
  'overlay-custom-dialogs',
  'overlay-bottom-sheets',
  'navigation-icon-buttons',
  'navigation-sky-controls',
  'feedback-errors',
  'feedback-loading',
  'spacing-page-insets',
  'spacing-radius-scale',
  'color-gold-state-language',
  'color-raw-values',
  'icons-size-and-container',
  'motion-entrances',
  'modal-shell-candidate',
  'surface-semantic-candidate',
};

class UiAuditSpecimens extends StatefulWidget {
  const UiAuditSpecimens({super.key, required this.item});
  final UiAuditItem item;

  @override
  State<UiAuditSpecimens> createState() => _UiAuditSpecimensState();
}

class _UiAuditSpecimensState extends State<UiAuditSpecimens>
    with SingleTickerProviderStateMixin {
  bool _selected = false;
  bool _loading = false;
  late final TextEditingController _emptyController;
  late final TextEditingController _filledController;
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _emptyController = TextEditingController();
    _filledController = TextEditingController(text: 'Valore compilato');
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    );
  }

  @override
  void dispose() {
    _emptyController.dispose();
    _filledController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ComparisonStrip(
      key: ValueKey('specimens-${widget.item.id}'),
      variants: _variants(context, widget.item.id),
    );
  }

  List<_Variant> _variants(BuildContext context, String id) {
    final colors = context.colors;
    switch (id) {
      case 'type-page-title-local':
        return [
          _v(
            'A',
            'Display immersivo',
            'area_detail_screen.dart',
            _text('Titolo pagina', 32, FontWeight.w800),
          ),
          _v(
            'B',
            'Titolo compatto',
            'quick_settings_screen.dart',
            _text('Titolo pagina', 20, FontWeight.w700, spacing: 1.4),
          ),
          _v(
            'C',
            'Titolo editor',
            'constellation_editor_screen.dart',
            _text('Titolo pagina', 18, FontWeight.w600),
          ),
        ];
      case 'type-section-title-local':
        return [
          _v(
            'A',
            'Sezione display',
            'area_section_header.dart',
            _text('La sezione', 30, FontWeight.w800),
          ),
          _v(
            'B',
            'Sezione standard',
            'settings_screen.dart',
            _text('La sezione', 20, FontWeight.w600),
          ),
          _v(
            'C',
            'Label compatta',
            'kind_filter_sheet.dart',
            _text(
              'LA SEZIONE',
              13,
              FontWeight.w600,
              spacing: 1.2,
              color: colors.muted,
            ),
          ),
        ];
      case 'type-scale-candidate':
        return [
          _v(
            'A',
            'Scala essenziale',
            'candidato',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text('Pagina', 30, FontWeight.w800),
                _text('Sezione', 20, FontWeight.w700),
                _text('Corpo', 15, FontWeight.w400),
                _text('Etichetta', 13, FontWeight.w600, color: colors.muted),
              ],
            ),
          ),
          _v(
            'B',
            'Display + utilità',
            'candidato raccomandato',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text('Display', 34, FontWeight.w800, font: kFontStarTitle),
                _text('Titolo utilità', 20, FontWeight.w700),
                _text('Corpo e dettagli', 14, FontWeight.w400),
                _text(
                  'MICRO LABEL',
                  11,
                  FontWeight.w700,
                  spacing: 1.2,
                  color: colors.gold,
                ),
              ],
            ),
          ),
        ];
      case 'action-material-buttons':
        return [
          _v(
            'A',
            'Elevated',
            'app_theme.dart',
            ElevatedButton(
              onPressed: () => _pulse(),
              child: const Text('AZIONE'),
            ),
          ),
          _v(
            'B',
            'Outlined',
            'app_theme.dart',
            OutlinedButton(
              onPressed: () => _pulse(),
              child: const Text('AZIONE'),
            ),
          ),
          _v(
            'C',
            'Text',
            'app_theme.dart',
            TextButton(onPressed: () => _pulse(), child: const Text('AZIONE')),
          ),
          _v(
            'D',
            'Disabled',
            'app_theme.dart',
            const ElevatedButton(onPressed: null, child: Text('AZIONE')),
          ),
        ];
      case 'action-save-pill':
        return [
          _v(
            'A',
            'Pronto / lit',
            'SaveActionButton',
            SaveActionButton(label: 'Salva', lit: true, onPressed: _pulse),
          ),
          _v(
            'B',
            'Non pronto',
            'SaveActionButton',
            SaveActionButton(label: 'Salva', lit: false, onPressed: _pulse),
          ),
          _v(
            'C',
            'Material primario',
            'confronto',
            ElevatedButton.icon(
              onPressed: _pulse,
              icon: const Icon(Icons.check),
              label: const Text('SALVA'),
            ),
          ),
        ];
      case 'action-pill-utility-danger':
        return [
          _v(
            'A',
            'Utilità',
            'PillActionButton',
            PillActionButton(icon: Icons.undo, label: 'Annulla', onTap: _pulse),
          ),
          _v(
            'B',
            'Distruttivo',
            'PillActionButton',
            PillActionButton(
              icon: Icons.delete_outline,
              label: 'Elimina',
              danger: true,
              onTap: _pulse,
            ),
          ),
          _v(
            'C',
            'Disabilitato',
            'PillActionButton',
            const PillActionButton(
              icon: Icons.redo,
              label: 'Ripeti',
              onTap: null,
            ),
          ),
        ];
      case 'action-cancel-meanings':
        return [
          _v(
            'A',
            'Cancel muted',
            'dialog e form',
            TextButton(
              onPressed: _pulse,
              child: Text('ANNULLA', style: TextStyle(color: colors.muted)),
            ),
          ),
          _v(
            'B',
            'Cancel gold',
            'editor locali',
            TextButton(onPressed: _pulse, child: const Text('ANNULLA')),
          ),
          _v(
            'C',
            'Discard danger',
            'conferme distruttive',
            TextButton(
              onPressed: _pulse,
              child: Text('SCARTA', style: TextStyle(color: colors.danger)),
            ),
          ),
          _v(
            'D',
            'Close icon',
            'overlay',
            IconButton(
              onPressed: _pulse,
              icon: const Icon(Icons.close),
              tooltip: 'Chiudi',
            ),
          ),
        ];
      case 'action-semantic-candidate':
        return [
          _v(
            'A',
            'Primaria',
            'candidato',
            SaveActionButton(label: 'Conferma', onPressed: _pulse),
          ),
          _v(
            'B',
            'Secondaria',
            'candidato',
            OutlinedButton(onPressed: _pulse, child: const Text('MODIFICA')),
          ),
          _v(
            'C',
            'Discreta',
            'candidato',
            TextButton(onPressed: _pulse, child: const Text('CHIUDI')),
          ),
          _v(
            'D',
            'Distruttiva',
            'candidato',
            PillActionButton(
              icon: Icons.delete_outline,
              label: 'Elimina',
              danger: true,
              onTap: _pulse,
            ),
          ),
        ];
      case 'field-shared':
        return [
          _v(
            'A',
            'Vuoto',
            'AppTextField',
            SizedBox(
              width: 210,
              child: AppTextField(
                controller: _emptyController,
                hintText: 'Inserisci un valore',
              ),
            ),
          ),
          _v(
            'B',
            'Compilato',
            'AppTextField',
            SizedBox(
              width: 210,
              child: AppTextField(controller: _filledController),
            ),
          ),
          _v(
            'C',
            'Picker',
            'AppPickerField',
            SizedBox(
              width: 210,
              child: AppPickerField(
                hint: 'Scegli',
                icon: Icons.auto_awesome,
                text: _selected ? 'Selezionato' : null,
                onTap: _toggle,
              ),
            ),
          ),
        ];
      case 'field-raw-text-fields':
        return [
          _v(
            'A',
            'Tema Material',
            'moodboard_screen.dart',
            SizedBox(
              width: 210,
              child: TextField(
                decoration: const InputDecoration(hintText: 'Citazione'),
              ),
            ),
          ),
          _v(
            'B',
            'Dialog compatto',
            'constellation_editor_screen.dart',
            SizedBox(
              width: 210,
              child: TextField(
                controller: _filledController,
                decoration: const InputDecoration(hintText: 'Nome'),
              ),
            ),
          ),
          _v(
            'C',
            'Con label esterna',
            'vision_editor_screen.dart',
            SizedBox(
              width: 210,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VISIONE',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const TextField(
                    maxLines: 2,
                    decoration: InputDecoration(hintText: 'Scrivi qui…'),
                  ),
                ],
              ),
            ),
          ),
        ];
      case 'selection-toggle-chip':
        return [
          _v(
            'A',
            'Off',
            'AppToggleChip',
            AppToggleChip(
              label: 'Tutte',
              value: false,
              onChanged: (_) => _toggle(),
            ),
          ),
          _v(
            'B',
            'On',
            'AppToggleChip',
            AppToggleChip(
              label: 'Tutte',
              value: true,
              onChanged: (_) => _toggle(),
            ),
          ),
          _v(
            'C',
            'Interattivo',
            'AppToggleChip',
            AppToggleChip(
              label: 'Prova',
              value: _selected,
              onChanged: (_) => _toggle(),
            ),
          ),
        ];
      case 'selection-local-chips':
        return [
          _v(
            'A',
            'Filtro testo',
            'area_filter_sheet.dart',
            _selectableChip('Salute', _selected, _toggle),
          ),
          _v(
            'B',
            'Filtro con icona',
            'kind_filter_sheet.dart',
            _selectableChip(
              'Stella',
              !_selected,
              _toggle,
              icon: Icons.star_outline,
            ),
          ),
          _v(
            'C',
            'Frequenza',
            'star_form_screen.dart',
            ChoiceChip(
              label: const Text('SETTIMANALE'),
              selected: _selected,
              onSelected: (_) => _toggle(),
            ),
          ),
        ];
      case 'surface-panel-card':
        return [
          _v(
            'A',
            'Panel neutro',
            'panelDecoration',
            _surface('Neutro', panelDecoration(colors)),
          ),
          _v(
            'B',
            'Selezionabile',
            'selectableDecoration',
            _surface(
              'Disponibile',
              selectableDecoration(colors, selected: false),
            ),
          ),
          _v(
            'C',
            'Selezionato',
            'selectableDecoration',
            _surface(
              'Selezionato',
              selectableDecoration(colors, selected: true),
            ),
          ),
        ];
      case 'surface-card-families':
        return [
          _v(
            'A',
            'Stella accesa',
            'lit_star_card.dart',
            _domainCard(Icons.star, 'Vittoria', colors.gold, glow: true),
          ),
          _v(
            'B',
            'Stella spenta',
            'unlit_star_card.dart',
            _domainCard(Icons.star_border, 'Obiettivo', colors.muted),
          ),
          _v(
            'C',
            'Pulsar',
            'pulsar_card.dart',
            _domainCard(Icons.bolt, 'Abitudine', colors.text),
          ),
          _v(
            'D',
            'Risultato ricerca',
            'search_result_card.dart',
            _domainCard(Icons.search, 'Risultato', colors.gold),
          ),
        ];
      case 'overlay-alert-dialogs':
        return [
          _v(
            'A',
            'Informativo',
            'AlertDialog',
            _miniDialog('Informazione', 'Capito', colors.gold),
          ),
          _v(
            'B',
            'Conferma',
            'AlertDialog',
            _miniDialog('Confermi?', 'Conferma', colors.gold, secondary: true),
          ),
          _v(
            'C',
            'Distruttivo',
            'AlertDialog',
            _miniDialog(
              'Eliminare?',
              'Elimina',
              colors.danger,
              secondary: true,
            ),
          ),
          _v(
            'D',
            'Bloccante',
            'form validation',
            _miniDialog('Manca qualcosa', 'Torna al form', colors.gold),
          ),
        ];
      case 'overlay-custom-dialogs':
        return [
          _v(
            'A',
            'Successo',
            'creation_success_dialog.dart',
            _customModal(
              Icons.auto_awesome,
              'Creazione riuscita',
              verticalActions: true,
            ),
          ),
          _v(
            'B',
            'Scelta media',
            'star_form_screen.dart',
            _customModal(Icons.photo_library_outlined, 'Scegli una fonte'),
          ),
          _v(
            'C',
            'Menu scelta',
            'sky_menu_drawer.dart',
            _customModal(Icons.hub_outlined, 'Accendi il cielo'),
          ),
        ];
      case 'overlay-bottom-sheets':
        return [
          _v(
            'A',
            'Filtro',
            'area_filter_sheet.dart',
            _miniSheet('Filtra aree', search: false),
          ),
          _v(
            'B',
            'Ricerca',
            'project_picker.dart',
            _miniSheet('Scegli progetto', search: true),
          ),
          _v(
            'C',
            'Ordinamento',
            'sort_filter_sheet.dart',
            _miniSheet('Ordina risultati', search: false, footer: true),
          ),
        ];
      case 'navigation-icon-buttons':
        return [
          _v(
            'A',
            'Back trasparente',
            'pagine',
            IconButton(
              onPressed: _pulse,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Indietro',
            ),
          ),
          _v(
            'B',
            'Back circolare',
            'star_reader_screen.dart',
            _roundIcon(Icons.arrow_back, colors.nightPanel, colors.gold),
          ),
          _v(
            'C',
            'Close overlay',
            'area_image_screen.dart',
            _roundIcon(Icons.close, Colors.black54, Colors.white),
          ),
          _v(
            'D',
            'Direzione',
            'sound_lab_screen.dart',
            _roundIcon(Icons.chevron_right, colors.nightPanel, colors.text),
          ),
        ];
      case 'navigation-sky-controls':
        return [
          _v(
            'A',
            'Gold su cielo',
            'skyControlDecoration',
            _decoratedIcon(
              Icons.zoom_in,
              skyControlDecoration(colors, circle: true),
              colors.gold,
            ),
          ),
          _v(
            'B',
            'White on navy',
            'quick menu',
            _decoratedIcon(
              Icons.search,
              BoxDecoration(
                color: colors.nightPanel,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              Colors.white,
            ),
          ),
          _v(
            'C',
            'Menu principale',
            'sky_screen.dart',
            _decoratedIcon(
              Icons.auto_awesome,
              BoxDecoration(
                color: colors.nightPanel,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              Colors.white,
              size: 64,
            ),
          ),
        ];
      case 'feedback-errors':
        return [
          _v(
            'A',
            'Inline',
            'app_lock_screen.dart',
            Row(
              children: [
                Icon(Icons.error_outline, color: colors.danger, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Valore non valido',
                    style: TextStyle(color: colors.danger, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          _v(
            'B',
            'Dialog esplicativo',
            'star_form_screen.dart',
            _miniDialog('Non puoi salvare', 'Correggi', colors.gold),
          ),
          _v(
            'C',
            'Errore globale',
            'main.dart',
            Container(
              color: colors.night,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Impossibile avviare l’app',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ];
      case 'feedback-loading':
        return [
          _v(
            'A',
            'Avvio vuoto',
            'main.dart',
            Container(height: 72, color: colors.night),
          ),
          _v(
            'B',
            'Progress inline',
            'schermate dati',
            const Center(child: CircularProgressIndicator()),
          ),
          _v(
            'C',
            'Azione in corso',
            'candidato',
            ElevatedButton.icon(
              onPressed: null,
              icon: const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: const Text('SALVATAGGIO…'),
            ),
          ),
        ];
      case 'spacing-page-insets':
        return [
          _v('A', '20 dp', 'form/editor', _insetDiagram(20, colors)),
          _v('B', '24 dp', 'griglie/card', _insetDiagram(24, colors)),
          _v('C', '28 dp', 'pagine immersive', _insetDiagram(28, colors)),
        ];
      case 'spacing-radius-scale':
        return [
          _v('A', 'Field · 12', 'kRadiusField', _radiusBox(12, colors)),
          _v('B', 'Card · 16', 'kRadiusCard', _radiusBox(16, colors)),
          _v('C', 'Pill', 'kRadiusPill', _radiusBox(999, colors)),
          _v('D', 'Locale · 28', 'carousel/media', _radiusBox(28, colors)),
        ];
      case 'color-gold-state-language':
        return [
          _v(
            'A',
            'Inattivo',
            'night + border',
            _stateSwatch(
              'Disponibile',
              colors.nightPanel,
              colors.nightBorder,
              colors.muted,
            ),
          ),
          _v(
            'B',
            'Selezionato',
            'gold ring',
            _stateSwatch(
              'Selezionato',
              colors.nightPanel,
              colors.gold,
              colors.gold,
            ),
          ),
          _v(
            'C',
            'Primario attivo',
            'gold fill + glow',
            _stateSwatch(
              'Attivo',
              colors.gold,
              colors.gold,
              colors.onGold,
              glow: true,
            ),
          ),
          _v(
            'D',
            'Distruttivo',
            'danger',
            _stateSwatch(
              'Pericolo',
              colors.dangerBackground,
              colors.danger,
              colors.danger,
            ),
          ),
        ];
      case 'color-raw-values':
        return [
          _v('A', 'Palette UI', 'context.colors', _palette(colors)),
          _v(
            'B',
            'Bianco raw',
            'overlay/SVG',
            _colorSample(Colors.white, 'Colors.white'),
          ),
          _v(
            'C',
            'Nero raw',
            'media overlay',
            _colorSample(Colors.black54, 'Colors.black54'),
          ),
          _v(
            'D',
            'ARGB locale',
            'artwork/shader',
            _colorSample(const Color(0xFF1D2A49), '0xFF1D2A49'),
          ),
        ];
      case 'icons-size-and-container':
        return [
          _v('A', 'Glyph 16', 'label/chip', const Icon(Icons.star, size: 16)),
          _v('B', 'Glyph 20', 'button', const Icon(Icons.star, size: 20)),
          _v(
            'C',
            'Glyph 24',
            'Material default',
            const Icon(Icons.star, size: 24),
          ),
          _v(
            'D',
            '48 dp target',
            'candidato',
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                onPressed: _pulse,
                icon: const Icon(Icons.star, size: 20),
              ),
            ),
          ),
        ];
      case 'motion-entrances':
        final animation = CurvedAnimation(
          parent: _motionController,
          curve: Curves.easeOutCubic,
        );
        return [
          _v(
            'A',
            'Fade + slide',
            'staggered_entrance.dart',
            FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .25),
                  end: Offset.zero,
                ).animate(animation),
                child: _motionSample(colors, 'Ingresso'),
              ),
            ),
          ),
          _v(
            'B',
            'Scale',
            'quick menu',
            ScaleTransition(
              scale: Tween(begin: .85, end: 1.0).animate(animation),
              child: _motionSample(colors, 'Espansione'),
            ),
          ),
          _v(
            'C',
            'Replay',
            'sandbox',
            OutlinedButton.icon(
              onPressed: _replayMotion,
              icon: const Icon(Icons.replay),
              label: const Text('RIPRODUCI'),
            ),
          ),
        ];
      case 'modal-shell-candidate':
        return [
          _v(
            'A',
            'Dialog shell',
            'candidato',
            _miniDialog('Titolo', 'Azione', colors.gold, secondary: true),
          ),
          _v(
            'B',
            'Sheet shell',
            'candidato',
            _miniSheet('Titolo sheet', search: true, footer: true),
          ),
          _v(
            'C',
            'Corpo speciale',
            'eccezione controllata',
            _customModal(
              Icons.image_outlined,
              'Contenuto immersivo',
              verticalActions: true,
            ),
          ),
        ];
      case 'surface-semantic-candidate':
        return [
          _v(
            'A',
            'Neutral',
            'candidato',
            _surface('Contenuto', panelDecoration(colors)),
          ),
          _v(
            'B',
            'Selectable',
            'candidato',
            _surface(
              'Disponibile',
              selectableDecoration(colors, selected: false),
            ),
          ),
          _v(
            'C',
            'Selected',
            'candidato',
            _surface(
              'Selezionato',
              selectableDecoration(colors, selected: true),
            ),
          ),
          _v(
            'D',
            'Disabled',
            'candidato',
            Opacity(
              opacity: .45,
              child: _surface('Disabilitato', panelDecoration(colors)),
            ),
          ),
        ];
    }
    throw StateError('Missing visual comparison for $id');
  }

  _Variant _v(String code, String name, String origin, Widget child) =>
      _Variant(code: code, name: name, origin: origin, child: child);

  Widget _text(
    String text,
    double size,
    FontWeight weight, {
    double? spacing,
    Color? color,
    String? font,
  }) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color,
      fontFamily: font,
    ),
  );

  void _toggle() => setState(() => _selected = !_selected);
  void _pulse() => setState(() => _loading = !_loading);
  void _replayMotion() => _motionController.forward(from: 0);
}

class _Variant {
  const _Variant({
    required this.code,
    required this.name,
    required this.origin,
    required this.child,
  });
  final String code;
  final String name;
  final String origin;
  final Widget child;
}

class _ComparisonStrip extends StatelessWidget {
  const _ComparisonStrip({super.key, required this.variants});
  final List<_Variant> variants;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < variants.length; i++) ...[
            _VariantCard(variant: variants[i]),
            if (i != variants.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.variant});
  final _Variant variant;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 276,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.night,
        border: Border.all(color: colors.nightBorder, width: kBorderWidth),
        borderRadius: BorderRadius.circular(kRadiusField),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.gold,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  variant.code,
                  style: TextStyle(
                    color: colors.onGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  variant.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            variant.origin,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted, fontSize: 10),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 78),
            child: Center(child: variant.child),
          ),
        ],
      ),
    );
  }
}

Widget _selectableChip(
  String label,
  bool selected,
  VoidCallback onTap, {
  IconData? icon,
}) {
  return Builder(
    builder: (context) {
      final colors = context.colors;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: selectableDecoration(
            colors,
            selected: selected,
            radius: kRadiusPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.gold : colors.muted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? colors.gold : colors.text,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _surface(String label, BoxDecoration decoration) => Container(
  height: 72,
  width: 180,
  alignment: Alignment.center,
  decoration: decoration,
  child: Text(label),
);

Widget _domainCard(
  IconData icon,
  String title,
  Color accent, {
  bool glow = false,
}) => Builder(
  builder: (context) => Container(
    width: 190,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.colors.nightPanel,
      border: Border.all(color: accent, width: kBorderWidth),
      borderRadius: BorderRadius.circular(kRadiusCard),
      boxShadow: glow
          ? goldGlow(context.colors, strength: .65, size: 36)
          : null,
    ),
    child: Row(
      children: [
        Icon(icon, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Metadati · azioni',
                style: TextStyle(color: context.colors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _miniDialog(
  String title,
  String action,
  Color actionColor, {
  bool secondary = false,
}) => Builder(
  builder: (context) => Container(
    width: 196,
    padding: const EdgeInsets.all(14),
    decoration: panelDecoration(context.colors),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Testo del messaggio.',
          style: TextStyle(color: context.colors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 6,
          children: [
            if (secondary)
              Text(
                'ANNULLA',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              action.toUpperCase(),
              style: TextStyle(
                color: actionColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);

Widget _customModal(
  IconData icon,
  String title, {
  bool verticalActions = false,
}) => Builder(
  builder: (context) => Container(
    width: 196,
    padding: const EdgeInsets.all(16),
    decoration: panelDecoration(context.colors),
    child: Column(
      children: [
        Icon(icon, color: context.colors.gold, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (verticalActions) ...[
          const SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: null, child: Text('CONDIVIDI')),
          ),
          const SizedBox(height: 6),
          const Text('CHIUDI', style: TextStyle(fontSize: 10)),
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Icon(Icons.photo_camera_outlined),
              Icon(Icons.photo_library_outlined),
            ],
          ),
      ],
    ),
  ),
);

Widget _miniSheet(String title, {required bool search, bool footer = false}) =>
    Builder(
      builder: (context) => Container(
        width: 205,
        decoration: BoxDecoration(
          color: context.colors.nightPanel,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kRadiusCard),
          ),
          border: Border.all(color: context.colors.nightBorder),
        ),
        child: Column(
          children: [
            const SizedBox(height: 7),
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: context.colors.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (search) ...[
                    const SizedBox(height: 8),
                    const SizedBox(
                      height: 38,
                      child: TextField(
                        decoration: InputDecoration(hintText: 'Cerca'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    height: 28,
                    decoration: selectableDecoration(
                      context.colors,
                      selected: false,
                    ),
                  ),
                  if (footer) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('APPLICA'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

Widget _roundIcon(IconData icon, Color background, Color foreground) =>
    Material(
      color: background,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, color: foreground),
      ),
    );

Widget _decoratedIcon(
  IconData icon,
  BoxDecoration decoration,
  Color color, {
  double size = 48,
}) => Container(
  width: size,
  height: size,
  decoration: decoration,
  child: Icon(icon, color: color, size: size * .45),
);

Widget _insetDiagram(double inset, AppColors colors) => Container(
  width: 190,
  height: 78,
  color: colors.gold.withValues(alpha: .12),
  padding: EdgeInsets.all(inset),
  child: Container(
    color: colors.nightPanel,
    alignment: Alignment.center,
    child: Text(
      '${inset.round()} dp',
      style: TextStyle(color: colors.gold, fontSize: 11),
    ),
  ),
);

Widget _radiusBox(double radius, AppColors colors) => Container(
  width: 130,
  height: 68,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: colors.nightPanel,
    border: Border.all(color: colors.gold),
    borderRadius: BorderRadius.circular(radius),
  ),
  child: Text(radius == 999 ? 'PILL' : 'R ${radius.round()}'),
);

Widget _stateSwatch(
  String label,
  Color fill,
  Color border,
  Color foreground, {
  bool glow = false,
}) => Builder(
  builder: (context) => Container(
    width: 150,
    height: 64,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      border: Border.all(color: border, width: kBorderWidth),
      borderRadius: BorderRadius.circular(kRadiusField),
      boxShadow: glow ? goldGlow(context.colors, size: 40) : null,
    ),
    child: Text(
      label,
      style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
    ),
  ),
);

Widget _palette(AppColors colors) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final color in [
      colors.night,
      colors.nightPanel,
      colors.nightBorder,
      colors.gold,
      colors.text,
      colors.danger,
    ])
      Container(width: 25, height: 56, color: color),
  ],
);

Widget _colorSample(Color color, String label) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(
      width: 70,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
    ),
    const SizedBox(height: 5),
    Text(label, style: const TextStyle(fontSize: 9)),
  ],
);

Widget _motionSample(AppColors colors, String label) => Container(
  width: 140,
  height: 58,
  alignment: Alignment.center,
  decoration: selectableDecoration(colors, selected: true),
  child: Text(
    label,
    style: TextStyle(color: colors.gold, fontWeight: FontWeight.w700),
  ),
);
