import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// One replayable tour, as the Tutorials screen lists it. [name] is the
/// `hint_kit` tour name; the screen owns how each one is launched, since that
/// needs repositories and navigation this plain description shouldn't carry.
class TutorialEntry {
  const TutorialEntry({
    required this.name,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String name;
  final IconData icon;
  final String Function(AppStrings) title;
  final String Function(AppStrings) body;
}

/// Every tour the user can replay, in the order the Tutorials screen shows
/// them. Keep in sync with `kAllTourNames` (tutorial_management.dart);
/// 'shape-editor' is the one exception: it replays the editor's own help
/// dialog rather than a `hint_kit` tour.
final List<TutorialEntry> kTutorialCatalog = [
  TutorialEntry(
    name: 'sky-navigation',
    icon: Icons.explore_outlined,
    title: (s) => s.tutorialEntrySkyNavigationTitle,
    body: (s) => s.tutorialEntrySkyNavigationBody,
  ),
  TutorialEntry(
    name: 'light-your-sky',
    icon: Icons.flare,
    title: (s) => s.tutorialEntryLightYourSkyTitle,
    body: (s) => s.tutorialEntryLightYourSkyBody,
  ),
  TutorialEntry(
    name: 'star-form',
    icon: Icons.star_border,
    title: (s) => s.tutorialEntryStarFormTitle,
    body: (s) => s.tutorialEntryStarFormBody,
  ),
  TutorialEntry(
    name: 'constellation-form',
    icon: Icons.insights,
    title: (s) => s.tutorialEntryConstellationFormTitle,
    body: (s) => s.tutorialEntryConstellationFormBody,
  ),
  TutorialEntry(
    name: 'shape-editor',
    icon: Icons.draw_outlined,
    title: (s) => s.tutorialEntryShapeEditorTitle,
    body: (s) => s.tutorialEntryShapeEditorBody,
  ),
  TutorialEntry(
    name: 'search-stars',
    icon: Icons.search,
    title: (s) => s.tutorialEntrySearchStarsTitle,
    body: (s) => s.tutorialEntrySearchStarsBody,
  ),
  TutorialEntry(
    name: 'supernova-vision',
    icon: Icons.visibility_outlined,
    title: (s) => s.tutorialEntrySupernovaVisionTitle,
    body: (s) => s.tutorialEntrySupernovaVisionBody,
  ),
  TutorialEntry(
    name: 'star-reader',
    icon: Icons.auto_stories_outlined,
    title: (s) => s.tutorialEntryStarReaderTitle,
    body: (s) => s.tutorialEntryStarReaderBody,
  ),
];
