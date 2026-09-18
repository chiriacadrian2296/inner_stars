import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// The 8 fixed areas of life a [Project] (and, through it, every [Star]) can
/// belong to. Fixed and closed — not user-extensible.
enum LifeArea {
  physical,
  psychological,
  professional,
  financial,
  personal,
  social,
  spiritual,
  philanthropic,
}

extension LifeAreaX on LifeArea {
  /// Localized name for this area. Takes [AppStrings] rather than reading
  /// it off a [BuildContext] itself, since an enum extension has no context
  /// of its own — call sites already have one via `context.strings`.
  String displayName(AppStrings s) {
    switch (this) {
      case LifeArea.physical:
        return s.areaPhysical;
      case LifeArea.psychological:
        return s.areaPsychological;
      case LifeArea.professional:
        return s.areaProfessional;
      case LifeArea.financial:
        return s.areaFinancial;
      case LifeArea.personal:
        return s.areaPersonal;
      case LifeArea.social:
        return s.areaSocial;
      case LifeArea.spiritual:
        return s.areaSpiritual;
      case LifeArea.philanthropic:
        return s.areaPhilanthropic;
    }
  }

  /// A short tagline for this area, shown on its Supernova detail screen.
  String description(AppStrings s) {
    switch (this) {
      case LifeArea.physical:
        return s.areaPhysicalDescription;
      case LifeArea.psychological:
        return s.areaPsychologicalDescription;
      case LifeArea.professional:
        return s.areaProfessionalDescription;
      case LifeArea.financial:
        return s.areaFinancialDescription;
      case LifeArea.personal:
        return s.areaPersonalDescription;
      case LifeArea.social:
        return s.areaSocialDescription;
      case LifeArea.spiritual:
        return s.areaSpiritualDescription;
      case LifeArea.philanthropic:
        return s.areaPhilanthropicDescription;
    }
  }

  /// An example vision for this area — shown, muted, in place of the
  /// user's own vision on its Supernova page until they write one (see
  /// `area_detail_screen.dart`), the same "Es./E.g." example-text
  /// convention the app's other hint strings already use, just displayed
  /// as the field's own empty-state content rather than a `TextField`
  /// hint. [AppStrings.areaVisionHint]'s own generic question is still
  /// what actually greets them once they tap in to write their own — this
  /// is only for the read-only view before that.
  String visionPlaceholder(AppStrings s) {
    switch (this) {
      case LifeArea.physical:
        return s.areaVisionPlaceholderPhysical;
      case LifeArea.psychological:
        return s.areaVisionPlaceholderPsychological;
      case LifeArea.professional:
        return s.areaVisionPlaceholderProfessional;
      case LifeArea.financial:
        return s.areaVisionPlaceholderFinancial;
      case LifeArea.personal:
        return s.areaVisionPlaceholderPersonal;
      case LifeArea.social:
        return s.areaVisionPlaceholderSocial;
      case LifeArea.spiritual:
        return s.areaVisionPlaceholderSpiritual;
      case LifeArea.philanthropic:
        return s.areaVisionPlaceholderPhilanthropic;
    }
  }

  /// The four prepared reflection prompts for this area, shown as an
  /// accordion on its Supernova page. Order is fixed and doubles as each
  /// question's id (see [ReflectionAnswer.questionId]) — never reorder this
  /// list, only ever append past index 3, or an existing answer will attach
  /// itself to the wrong prompt.
  List<String> reflectionQuestions(AppStrings s) {
    switch (this) {
      case LifeArea.physical:
        return s.reflectionQuestionsPhysical;
      case LifeArea.psychological:
        return s.reflectionQuestionsPsychological;
      case LifeArea.professional:
        return s.reflectionQuestionsProfessional;
      case LifeArea.financial:
        return s.reflectionQuestionsFinancial;
      case LifeArea.personal:
        return s.reflectionQuestionsPersonal;
      case LifeArea.social:
        return s.reflectionQuestionsSocial;
      case LifeArea.spiritual:
        return s.reflectionQuestionsSpiritual;
      case LifeArea.philanthropic:
        return s.reflectionQuestionsPhilanthropic;
    }
  }

  /// A generic icon representing the area itself — distinct from a
  /// project's own [Project.iconSlug]-based constellation icon, and
  /// deliberately never offered as a project icon choice (see [iconSlug])
  /// so the two never get visually confused. Used wherever an area is
  /// shown as a single UI element (the Sky hub cards, the area picker when
  /// creating a project) rather than browsed into.
  IconData get icon {
    switch (this) {
      case LifeArea.physical:
        return Icons.accessibility_new;
      case LifeArea.psychological:
        return Icons.psychology;
      case LifeArea.professional:
        return Icons.work;
      case LifeArea.financial:
        return Icons.savings;
      case LifeArea.personal:
        return Icons.self_improvement;
      case LifeArea.social:
        return Icons.groups;
      case LifeArea.spiritual:
        return Icons.all_inclusive;
      case LifeArea.philanthropic:
        return Icons.volunteer_activism;
    }
  }

  /// The slug equivalent of [icon]. None of these appear in
  /// `icon_for_slug.dart` — the two sets are kept disjoint by construction,
  /// so an area and a project can never render with the same glyph — and
  /// the project icon picker filters them out again anyway, as a guard
  /// against the two drifting back together.
  ///
  /// Physical wears `accessibility_new` (a standing figure) rather than the
  /// dumbbell it used to: the dumbbell is a shape in the constellation
  /// library now, and the library's own icon for it has to be the dumbbell.
  String get iconSlug {
    switch (this) {
      case LifeArea.physical:
        return 'accessibility_new';
      case LifeArea.psychological:
        return 'psychology';
      case LifeArea.professional:
        return 'work';
      case LifeArea.financial:
        return 'savings';
      case LifeArea.personal:
        return 'self_improvement';
      case LifeArea.social:
        return 'groups';
      case LifeArea.spiritual:
        return 'all_inclusive';
      case LifeArea.philanthropic:
        return 'volunteer_activism';
    }
  }

  /// Key into `suggestedIconsByArea` (icon_for_slug.dart). Kept
  /// separate from [name] because that map spells this area
  /// "philanthropical", not "philanthropic".
  String get suggestedIconsKey {
    switch (this) {
      case LifeArea.philanthropic:
        return 'philanthropical';
      default:
        return name;
    }
  }
}
