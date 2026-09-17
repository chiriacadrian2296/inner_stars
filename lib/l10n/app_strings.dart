/// Every user-facing piece of text in the app, in one interface — resolved
/// per [SettingsController.locale] via `context.strings` (see
/// `strings_scope.dart`). Kept as a hand-written interface + one
/// implementation per language rather than Flutter's ARB/gen-l10n pipeline:
/// the language is a Settings choice here, not the device locale, and the
/// string set is small enough that a plain Dart class is simpler to read,
/// grep, and keep in sync than generated code.
abstract class AppStrings {
  String get languageCode;

  // Life areas
  String get areaPhysical;
  String get areaPsychological;
  String get areaProfessional;
  String get areaFinancial;
  String get areaPersonal;
  String get areaSocial;
  String get areaSpiritual;
  String get areaPhilanthropic;
  String get areaPhysicalDescription;
  String get areaPsychologicalDescription;
  String get areaProfessionalDescription;
  String get areaFinancialDescription;
  String get areaPersonalDescription;
  String get areaSocialDescription;
  String get areaSpiritualDescription;
  String get areaPhilanthropicDescription;

  // Reflection questions — four prepared prompts per life area, shown as an
  // accordion on that area's own Supernova page (`AreaDetailScreen`),
  // alongside its free-form vision. Kept as one `List<String>` getter per
  // area (index = question id) rather than one getter per question, so
  // adding/reordering doesn't grow the interface further.
  List<String> get reflectionQuestionsPhysical;
  List<String> get reflectionQuestionsPsychological;
  List<String> get reflectionQuestionsProfessional;
  List<String> get reflectionQuestionsFinancial;
  List<String> get reflectionQuestionsPersonal;
  List<String> get reflectionQuestionsSocial;
  List<String> get reflectionQuestionsSpiritual;
  List<String> get reflectionQuestionsPhilanthropic;
  String get reflectionQuestionsSectionLabel;
  String get reflectionQuestionsSubtitle;
  String get reflectionAnswerHint;
  String get reflectionDifficultyLabel;
  String get reflectionAnsweredCountLabel;

  // The Sky's own side menu — the app has exactly one screen now (the
  // Sky), and everything else opens from there. Grouped into sections;
  // [menuLightAStar]/[menuNewConstellation]/[lightYourSkyChooserSupernovaOption]
  // no longer sit directly in the menu themselves — they're the three
  // choices offered by the popup [menuLightYourSky] opens.
  String get openMenuAction;
  // Shown briefly on the Sky's own star-shaped menu button (see
  // `_MenuStarButtonState`) whenever a press lets go before the short
  // hold that opens the menu completes.
  String get menuButtonHoldHint;
  String get menuSearchSection;
  String get menuActivitySection;
  String get menuLightYourSky;
  String get menuLightAStar;
  String get menuNewConstellation;
  String get lightYourSkyChooserSupernovaOption;
  String get menuShootingStars;
  String get menuDataSection;
  String get menuSearch;
  String get menuStatistics;
  String get menuNightlightSection;
  String get menuFindYourLight;
  String get menuChallengesSection;
  String get socialSection;
  String get menuFriends;
  String get menuSettings;
  String get menuInfoSection;
  String get menuMetaphor;
  String get menuOnboarding;

  // One-line captions shown under each menu entry, but only in the modal
  // variant of the menu ([SkyMenuContent]'s `detailed: true`) — the
  // drawer stays as compact as it already was tuned to be.
  String get menuLightYourSkyDescription;
  String get menuShootingStarsDescription;
  String get menuFindYourLightDescription;
  String get menuSearchDescription;
  String get menuStatisticsDescription;
  String get menuFriendsDescription;
  String get menuMetaphorDescription;
  String get menuSettingsDescription;

  // Placeholder screens — features sketched into the menu ahead of the
  // real thing existing yet. [comingSoonBadge] is the shared eyebrow for
  // all of them; each screen pairs it with its own menu label as a title
  // and its own body text.
  String get comingSoonBadge;
  String get shootingStarsBody;
  String get friendsBody;

  // Settings — placeholder sections, sketched the same way (see above),
  // but as panels within the Settings page rather than screens of their
  // own; [socialSection] above doubles as this one's header too.
  String get profileSection;
  String get profilePlaceholderBody;
  String get customizationSection;
  String get customizationPlaceholderBody;
  String get passkeySection;
  String get passkeyPlaceholderBody;
  String get socialPlaceholderBody;

  // Statistics tab
  String get statsEyebrow;
  String get statsTitle;

  // Home dashboard
  String get homeEyebrow;
  String get homeTitle;
  String get homeSubtitle;
  String get todayStarSectionLabel;
  String get litTodayTitle;
  String get litTodayTitleHighlight;
  String get litTodaySubtitle;
  String get litTodaySubtitleHighlight;
  String get notLitTodayLabel;
  String get notLitTodayHighlight;
  String get lightStarCta;
  String get totalStarsLabel;
  String get streaksSectionLabel;
  String get currentStreakLabel;
  String get longestStreakLabel;
  String get activityLabel;
  String get dayDetailEmpty;
  String get addStarForDayLabel;

  // Stat detail screens (tapping Total Stars / Current Streak / Longest
  // Streak on the dashboard)
  String get firstStarLabel;
  String get mostRecentStarLabel;
  String get combinedIntensityLabel;
  String get starsByAreaLabel;
  String get streakFromLabel;
  String get streakToLabel;
  String get todayLabel;
  String get starsLoggedLabel;
  String get noCurrentStreakBody;

  // Area detail (constellations / list view switch)
  String get searchHint;
  String get noSearchResults;
  String get skyEmptyConstellations;
  String get skyEmptyStars;

  // Constellation card stats (Sky > area > Constellations view)
  String intensityCount(int value);
  String createdOnLabel(String date);
  String lastStarLabel(String date);

  // Settings — data section (seed/reset, moved here from the old Home)
  String get dataSection;
  String get seedSampleData;
  String seedSampleDataResult(int count);
  String get resetAllData;
  String get resetAllDataConfirmTitle;
  String get resetAllDataConfirmBody;
  String get cancel;
  String get deleteEverything;
  String get allDataCleared;
  String get archiveEmpty;

  // Sound Lab — its own screen (not a Settings section anymore), opened
  // from a dedicated button on the Sky: the background loop (pick a
  // track, play/pause), its tap/hold/zoom-in/zoom-out sounds (pick one
  // each), and a volume slider per category. The only place any of this
  // is ever surfaced — see `AudioService`.
  String get soundLabEyebrow;
  String get soundLabTitle;
  String get soundLabSubtitle;
  String get soundLabButtonTooltip;
  String get soundLabResetAction;
  String get backgroundTrackLabel;
  String get pauseBackgroundTrackAction;
  String get playBackgroundTrackAction;
  String get tapSoundLabel;
  String get holdSoundLabel;
  String get whooshInLabel;
  String get whooshOutLabel;
  String get volumeSectionLabel;
  String get backgroundVolumeLabel;
  String get tapVolumeLabel;
  String get holdVolumeLabel;
  String get whooshVolumeLabel;
  String get backgroundTrackObservingTheStar;
  String get backgroundTrackHeavenlyLoop;
  String get backgroundTrackOutThere;
  String get backgroundTrackAmbientRelaxing;
  String get backgroundTrackBackgroundSpace;
  String get backgroundTrackNightlight;
  String get skySoundPluckSoft;
  String get skySoundPluckBright;
  String get skySoundGlassLow;
  String get skySoundGlassHigh;
  String get skySoundGlassChime;
  String get skySoundGlassBell;
  String get skySoundGlassShine;
  String get skySoundGlassTwinkle;
  String get skySoundBong;
  String get skySoundConfirmation;
  String get skySoundChimeSoft;
  String get skySoundChimeWarm;
  String get skySoundChimeBright;
  String get skySoundSelect;
  String get skySoundBlip;
  String get skySoundStarBlip;
  String get skySoundShimmer;
  String get skySoundTick;
  String get skySoundToggle;
  String get skySoundClick;
  String get skySoundCosmicDing;
  String get skySoundCosmicBlink;
  String get skySoundCosmicBeep;
  String get skyWhooshA;
  String get skyWhooshB;
  String get skyWhooshC;
  String get skyWhooshD;
  String get skyWhooshE;
  String get skyWhooshF;

  // Guided tutorials (hint_kit) — the card controls every tour shares
  // (see `TourLabels`), and each individual tour's own step copy below it.
  // Onboarding/`MetaphorScreen` are parked in favor of these (see the TRB).
  String get tourSkipAction;
  String get tourBackAction;
  String get tourNextAction;
  String get tourDoneAction;
  String tourProgressLabel(int step, int length);

  // "sky-navigation" tour — the Sky screen itself (`sky_screen.dart`). First
  // tour a fresh install ever sees. Every step but the last advances only
  // on the real gesture it describes (see `TourGestureStep`), not on a
  // Next tap.
  //
  // Order 1, the tour's own opening (see `appTourWelcomeCard`) — the one
  // step with a real button (Start) rather than a gesture, and the only
  // copy in this whole tour that isn't teaching a specific control.
  String get skyTourWelcomeTitle;
  String get skyTourWelcomeBody;
  String get skyTourWelcomeStartAction;
  String get skyTourTapSupernovaTitle;
  String get skyTourTapSupernovaBody;
  String get skyTourTapConstellationTitle;
  String get skyTourTapConstellationBody;
  String get skyTourTapStarTitle;
  String get skyTourTapStarBody;
  String get skyTourDoubleTapTitle;
  String get skyTourDoubleTapBody;
  String get skyTourHoldTitle;
  String get skyTourHoldBody;
  String get skyTourTooltipTitle;
  String get skyTourTooltipBody;
  String get skyTourMenuTitle;
  String get skyTourMenuBody;
  // The tour's own continuation into the full menu (order 9) and the
  // quick-access mini menu (orders 10-15) — see `_openMenuModal`/
  // `_QuickAccessFan` in `sky_screen.dart`. Order 9 shows while the full
  // menu modal from order 8 is open, and waits for it to actually close
  // (any of the three ways) rather than a Next tap. Orders 11-15 are
  // purely informational — the real buttons stay modal (not
  // `passthrough`) until the tour finishes, so a Next tap is what moves
  // each one along (never Skip — this tour never offers one, at any
  // step).
  String get skyTourMenuCloseTitle;
  String get skyTourMenuCloseBody;
  String get skyTourMenuCloseTryAction;
  String get skyTourQuickMenuTapTitle;
  String get skyTourQuickMenuTapBody;
  String get skyTourQuickSettingsHintTitle;
  String get skyTourQuickSettingsHintBody;
  String get skyTourSupernovasHintTitle;
  String get skyTourSupernovasHintBody;
  String get skyTourConstellationsHintTitle;
  String get skyTourConstellationsHintBody;
  String get skyTourStarsHintTitle;
  String get skyTourStarsHintBody;
  String get skyTourSearchHintTitle;
  String get skyTourSearchHintBody;

  // "star-form" tour (`lib/tutorials/`) — the whole star form, every
  // creatable kind (lit victory, unlit goal, pulsar habit).
  String get starTourIntroTitle;
  String get starTourIntroBody;
  String get starTourKindTitle;
  String get starTourKindBody;
  String get starTourLegendTitle;
  String get starTourLegendBody;
  String get starTourSupernovaFieldTitle;
  String get starTourSupernovaFieldBody;
  String get starTourConstellationFieldTitle;
  String get starTourConstellationFieldBody;
  String get starTourTitleFieldTitle;
  String get starTourTitleFieldBody;
  String get starTourDetailsFieldTitle;
  String get starTourDetailsFieldBody;
  String get starTourDateFieldTitle;
  String get starTourDateFieldBody;
  String get starTourTargetDateFieldTitle;
  String get starTourTargetDateFieldBody;
  String get starTourIntensityTitle;
  String get starTourIntensityBody;
  String get starTourHabitFrequencyTitle;
  String get starTourHabitFrequencyBody;
  String get starTourReminderTitle;
  String get starTourReminderBody;
  String get starTourPhotoTitle;
  String get starTourPhotoBody;
  String get starTourSaveTitle;
  String get starTourSaveBody;

  // "search-stars" tour — the Sky's search/filter popup
  // (`SkyExplorerView`/`area_filter_sheet.dart`).
  String get searchTourIntroTitle;
  String get searchTourIntroBody;
  String get searchTourModeTitle;
  String get searchTourModeBody;
  String get searchTourFieldTitle;
  String get searchTourFieldBody;
  String get searchTourFilterButtonTitle;
  String get searchTourFilterButtonBody;
  String get searchTourAllAreasTitle;
  String get searchTourAllAreasBody;
  String get searchTourAllKindsTitle;
  String get searchTourAllKindsBody;
  String get searchTourApplyTitle;
  String get searchTourApplyBody;

  // "light-your-sky" tour — the Supernovas/Constellations/Stars chooser
  // popup opened from the Sky's own menu (`sky_menu_drawer.dart`).
  String get lightYourSkyTourIntroTitle;
  String get lightYourSkyTourIntroBody;
  String get lightYourSkyTourSupernovaTitle;
  String get lightYourSkyTourSupernovaBody;
  String get lightYourSkyTourConstellationTitle;
  String get lightYourSkyTourConstellationBody;
  String get lightYourSkyTourStarTitle;
  String get lightYourSkyTourStarBody;

  // "constellation-form" tour — `NewProjectScreen`.
  String get constellationTourIntroTitle;
  String get constellationTourIntroBody;
  String get constellationTourLegendTitle;
  String get constellationTourLegendBody;
  String get constellationTourAreaTitle;
  String get constellationTourAreaBody;
  String get constellationTourIconFieldTitle;
  String get constellationTourIconFieldBody;
  String get constellationTourNameTitle;
  String get constellationTourNameBody;
  String get constellationTourDescriptionTitle;
  String get constellationTourDescriptionBody;
  String get constellationTourCanvasTitle;
  String get constellationTourCanvasBody;
  String get constellationTourDrawButtonTitle;
  String get constellationTourDrawButtonBody;
  String get constellationTourLibraryButtonTitle;
  String get constellationTourLibraryButtonBody;
  String get constellationTourResetButtonTitle;
  String get constellationTourResetButtonBody;
  String get constellationTourSaveTitle;
  String get constellationTourSaveBody;

  // "supernova-vision" tour — `VisionsScreen` into `AreaDetailScreen`.
  String get supernovaTourIntroTitle;
  String get supernovaTourIntroBody;
  String get supernovaTourListTitle;
  String get supernovaTourListBody;
  String get supernovaTourEditTitle;
  String get supernovaTourEditBody;
  String get supernovaTourReflectionTitle;
  String get supernovaTourReflectionBody;

  String get replayToursAction;
  String get replayToursResult;
  String get tutorialsButtonTooltip;
  String get tutorialsManagementTitle;
  String get tutorialsEnabledLabel;
  String get tutorialsEnabledDescription;

  // "Quick Settings" — one of the quick-access mini menu's five entries
  // (see `_QuickAccessFan` in `sky_screen.dart`, opened by a plain tap on
  // the Sky's menu button). The other four reuse existing labels/tooltips
  // above (search, supernova/constellation/star creation); this backs its
  // own lightweight page, which bundles the background music toggle+volume,
  // the sky grid toggle and the tutorials toggle in one place — deeper
  // audio tuning still lives in Sound Lab, linked from here.
  String get quickSettingsButtonTooltip;
  String get quickSettingsEyebrow;
  String get quickSettingsTitle;
  String get quickSettingsAudioSection;
  String get quickSettingsOpenSoundLabAction;

  // Sky + area projects
  String starsCount(int count);
  String areaEmptyProjects(String areaName);

  /// Shown in the constellation picker when no supernova has been chosen
  /// yet, so it lists every constellation across every area — the
  /// area-scoped [areaEmptyProjects] doesn't apply since there's no single
  /// area to name.
  String get noProjectsYet;
  String get constellationsModeLabel;
  String get listModeLabel;
  String get skyModeSupernovas;
  String get filterAreasAction;
  String get applyAreaFilterAction;
  String get filterKindSectionTitle;
  String get allKindsLabel;
  String get searchButtonLabel;
  String get takeMeThereAction;
  String get searchScreenEyebrow;

  // Area detail (the vision text, description, and big stat numbers for a
  // single Supernova)
  String get areaVisionLabel;
  String get areaVisionHint;
  String get editVisionAction;
  String get areaConstellationsStatLabel;
  String get areaStarsStatLabel;
  String get areaIntensityStatLabel;

  // Constellation
  String get constellationShapeMissing;

  // Constellation editor (hand-drawn custom shapes)
  String get drawYourOwnConstellation;
  String get constellationEditorTitle;
  String get constellationEditorEditTitle;
  String constellationEditorDisconnectedWarning(int count);

  /// The always-visible "Used N/max stars" count above the canvas — same
  /// line as [constellationEditorDisconnectedWarning], itself always
  /// visible too now (even at zero), replacing the old cap-reached-only
  /// message (reaching [_maxEditorPoints] is now just this count landing
  /// on its own max, self-explanatory without a separate string).
  String constellationEditorStarCount(int count, int max);
  String get undoAction;
  String get redoAction;
  String get deletePointAction;
  String get saveConstellationAction;
  String get nameYourConstellationTitle;
  String get constellationNameHint;
  String get constellationEditorGridToggleLabel;
  String get constellationEditorMirrorToggleLabel;
  String get constellationEditorMirrorAxisVerticalLabel;
  String get constellationEditorMirrorAxisHorizontalLabel;
  String get constellationEditorHelpAction;
  String get constellationEditorHelpTitle;
  String get constellationEditorHelpAddPoint;
  String get constellationEditorHelpConnectPoint;
  String get constellationEditorHelpDisarmPoint;
  String get constellationEditorHelpMovePoint;
  String get constellationEditorHelpDeletePoint;
  String get constellationEditorHelpMirrorToggle;
  String get constellationEditorHelpMirrorAxis;
  String get constellationEditorHelpDontShowAgain;
  String get constellationEditorHelpClose;

  // Ready-made constellation library (constellation_presets.dart). Shape
  // and category names aren't here — they live with the catalogue, the
  // same way seed_data.dart owns its own translated project names.
  String get chooseShapeLabel;
  String get shapeLibraryTitle;
  String get pickFromLibraryShort;
  String get drawShapeShort;
  String get resetShapeShort;
  String get shapeSearchHint;

  /// The picker sheet's own two tabs — every ready-made shape vs. the
  /// ones this user has already drawn/saved themselves (formerly a
  /// separate "Your constellations" section on the form itself, folded
  /// into this same sheet).
  String get shapeLibraryTabLabel;
  String get yourShapesTabLabel;
  String get noCustomShapesYetHint;
  String get editSelectedShapeAction;

  // Shared by every form that marks its own fields required/optional (see
  // `FieldRequirementLegend` in `widgets/app_field.dart`) — the one place
  // those words are spelled out; every per-field marker is icon-only.
  String get fieldLegendTitle;
  String get requiredFieldLegend;
  String get optionalFieldLegend;

  // New project
  String get newProjectEyebrow;
  String get newProjectQuestion;
  String get areaLabel;
  String get nameLabel;
  String get newProjectNameHint;
  String get projectDescriptionLabel;
  String get projectDescriptionHint;
  String get iconLabel;
  String get chooseIconTitle;
  String get pickerConfirmAction;
  String get closeAction;
  String get createProject;
  String get newProject;

  // The star form — one page for every kind of star (see [StarKind]).
  String get newStarEyebrow;
  String get editStarEyebrow;

  /// Shown instead of [newStarEyebrow] when the form was opened by tapping
  /// a nascent star: nothing is being added, an existing star is being
  /// given a meaning.
  String get configureStarEyebrow;

  String get litStarQuestion;
  String get unlitStarQuestion;
  String get pulsarQuestion;
  String get projectLabel;
  String get selectAProject;

  /// The star form's own supernova field — separate from [areaLabel]
  /// (the new-project screen's own field for the same thing) only because
  /// this one needs its own hint text alongside [selectAProject]'s.
  String get selectASupernova;
  String get dateLabel;
  String get selectADateHint;
  String get timeLabel;
  String get selectATimeHint;
  String get titleFieldLabel;

  // Title/Details placeholders — one consistent example (running) carried
  // across all three kinds, each tense-matched to what that kind actually
  // records: a lit star already happened, an unlit one hasn't yet, a
  // pulsar is a standing routine. Kept as one running example throughout
  // rather than a different topic per kind so the three read as the same
  // idea at different stages, not unrelated placeholder text.
  String get litTitleHint;
  String get unlitTitleHint;
  String get pulsarTitleHint;
  String get litDetailsHint;
  String get unlitDetailsHint;
  String get pulsarDetailsHint;

  String get detailsLabel;
  String get intensityLabel;
  String get photoLabel;
  String get addPhotoHint;
  String get takePhotoOption;
  String get choosePhotoOption;
  String get photoPickError;
  String get cropPhotoTitle;
  String get cropPhotoConfirm;
  String get cropPhotoHint;
  String get saveChanges;
  String get lightThisStar;

  /// The save action's label for a star that isn't being lit right now — an
  /// unlit star or a pulsar, both of which are placed in the sky rather
  /// than lit up.
  String get placeThisStarAction;

  String get cannotSaveMissingInfo;
  String get gotIt;
  String get deleteStarConfirmTitle;
  String get deleteStarConfirmBody;
  String get deletePulsarConfirmTitle;
  String get deletePulsarConfirmBody;
  String get deleteStarAction;
  String get discardChangesConfirmTitle;
  String get discardChangesConfirmBody;
  String get discardChangesAction;

  String get targetDateLabel;
  String get selectATargetDateHint;

  // Star reader — unlit/dead states
  String goalTargetLabel(String date);
  String get markAchievedAction;
  String get markAchievedSheetTitle;
  String get markAchievedConfirm;
  String get undoAchievedAction;
  String get deadStarBody;

  /// A dead star that used to be a pulsar says so, and says what reigniting
  /// it will give back — a pulsar again, never a free choice.
  String get deadPulsarBody;
  String get reigniteAction;

  // Pulsar-only fields on the star form
  String get habitFrequencyLabel;
  String get habitFrequencyDaily;
  String get habitFrequencyWeekly;

  /// "Once a day" for 1, "N times a day" for more — the live summary under
  /// the frequency picker's own stepper.
  String habitFrequencySummaryDaily(int times);

  /// "Once a week" for 1, "N times a week, on N different days" for more —
  /// spelling out that repeats on the same day don't count twice, since
  /// that's the one thing about a weekly habit that isn't obvious from the
  /// number alone.
  String habitFrequencySummaryWeekly(int times);

  String get customReminderToggleLabel;

  // Habit reader
  String get habitCurrentStreakLabel;
  String get markHabitDoneAction;
  String get habitDoneTodayLabel;
  String get undoHabitTodayAction;

  /// "2/3 today" — the daily-N-times stepper's own progress line, shown
  /// instead of [habitDoneTodayLabel]/[markHabitDoneAction] once the
  /// habit's target is more than 1.
  String habitProgressToday(int done, int target);

  /// "2/3 this week" — a weekly habit's own progress line, shown alongside
  /// [habitCurrentStreakLabel] rather than instead of it (the day itself is
  /// still a plain done/not-done toggle; only the week total is a count).
  String habitProgressThisWeek(int done, int target);

  // Constellation card badges, alongside the existing star count
  String unlitStarsBadge(int count);
  String activePulsarsBadge(int count);

  // The five kinds of star (see [StarKind]) — each has a singular name for
  // one card's own label, a plural for filter chips and counts, a one-line
  // meaning that translates the astronomy back into plain words, and an
  // example for the metaphor guide. Always reached through `StarKindX`
  // rather than read directly, so no screen hardcodes which is which.
  String get starKindNascentName;
  String get starKindNascentPlural;
  String get starKindNascentMeaning;
  String get starKindNascentExample;
  String get starKindLitName;
  String get starKindLitPlural;
  String get starKindLitMeaning;
  String get starKindLitExample;
  String get starKindUnlitName;
  String get starKindUnlitPlural;
  String get starKindUnlitMeaning;
  String get starKindUnlitExample;
  String get starKindPulsarName;
  String get starKindPulsarPlural;
  String get starKindPulsarMeaning;
  String get starKindPulsarExample;
  String get starKindDeadName;
  String get starKindDeadPlural;
  String get starKindDeadMeaning;
  String get starKindDeadExample;

  // Star card's "extra" badge — the one kind-specific fact shown between
  // the description and the intensity/date block (photo/target/death
  // date/streak), and the "created" line every card ends with.
  String get photoBadgeLabel;
  String get targetDateBadgeLabel;
  String get deadDateBadgeLabel;
  String get streakBadgeLabel;
  String get noPhotoLabel;
  String get noTargetDateLabel;
  String get noDeadDateLabel;

  // Admire Your Stars (random reflection, filterable by area)
  String get chooseSupernovasToInclude;
  String get allAreasLabel;
  String get admireAllAreasLabel;
  String get pickAtLeastOneArea;
  String get noStarsInSelection;
  String get viewYourStars;

  // Nightlight — the calm-check gate in front of [AdmireStarsScreen], plus
  // the explanation and breathing screens shown when the answer is "in
  // crisis" (see `nightlight_gate_screen.dart` and its two follow-ups).
  // The gate question, split around its two keywords (rather than one
  // plain sentence) so `nightlight_gate_screen.dart` can bold just those
  // two words — the same ones the two buttons below use — to make the
  // correlation between question and answer visible at a glance.
  String get nightlightGateQuestionPrefix;
  String get nightlightGateQuestionOkWord;
  String get nightlightGateQuestionMiddle;
  String get nightlightGateQuestionCrisisWord;
  String get nightlightGateQuestionSuffix;

  // The two buttons' own labels, split the same way — a plain prefix plus
  // the one word that should be bold, rather than the whole label. The
  // bold word doesn't need to match the question's own wording exactly
  // (grammar differs; e.g. Italian's "a posto" vs. a button's "bene") —
  // the shared bold *treatment* is what ties question to answer.
  String get nightlightGateOkPrefix;
  String get nightlightGateOkWord;
  String get nightlightGateCrisisPrefix;
  String get nightlightGateCrisisWord;
  // The explanation screen: a title, a quick 3-step icon scheme
  // (agitated -> breathe -> see clearly) above the text, then the
  // explanation itself broken into short paragraphs rather than one dense
  // block. Each paragraph carries its own `*word*`-marked bold spans
  // inline (parsed by `nightlight_explained_screen.dart`'s
  // `parseBoldMarkup`) rather than one single bold phrase per paragraph —
  // lets a paragraph mark as many of its own words bold as it needs to,
  // wherever they fall in its own sentence.
  String get nightlightExplainedTitle;
  String get nightlightExplainedSchemeAgitated;
  String get nightlightExplainedSchemeBreathe;
  String get nightlightExplainedSchemeClarity;
  String get nightlightExplainedBodyPart1;
  String get nightlightExplainedBodyPart2;
  String get nightlightExplainedBodyPart3;
  String get nightlightExplainedContinue;
  String get nightlightBreathingGetReady;
  String get nightlightBreathingInhale;
  String get nightlightBreathingExhale;
  String get nightlightBreathingSkip;

  // Shown once cycles start: which one this is out of the fixed total, and
  // a plain mm:ss clock counting down to the exercise's own end.
  String nightlightBreathingCycleLabel(int current, int total);

  // The check-in shown when the exercise finishes on its own (cycles ran
  // out) rather than the user tapping "I'm ready" themselves — asks how
  // they're feeling now rather than assuming the exercise alone was enough.
  String get nightlightBreathingCheckInTitle;
  String get nightlightBreathingCheckInBody;
  String get nightlightBreathingCheckInRedo;
  String get nightlightBreathingCheckInProceed;

  String get newConstellationOption;

  // Your visions — the page that gathers all 8 supernovas so their visions
  // can be re-read and revised in one place.
  String get visionsEyebrow;
  String get visionsTitle;
  String get visionsSubtitle;
  String get visionEmptyLabel;

  // The metaphor guide — one page explaining every level of the sky and how
  // they nest, openable any time from the menu's Info section
  // ([menuMetaphor]).
  String get guideEyebrow;
  String get guideTitle;
  String get guideIntroBody;
  String get examplesLabel;
  String get guideAreaTitle;
  String get guideAreaMeaning;
  String get guideAreaBody;
  String get guideAreaExamples;
  String get guideConstellationTitle;
  String get guideConstellationMeaning;
  String get guideConstellationBody;
  String get guideConstellationExamples;
  String get guideStarTitle;
  String get guideStarMeaning;
  String get guideStarBody;
  String get guideStarExamples;
  String get guideKindsTitle;
  String get guideKindsBody;
  String get guideIntensityTitle;
  String get guideIntensityBody;

  /// A fixed set of short, hand-written uplifting phrases — cycled through
  /// automatically, one at a time, by the quote carousel below the area
  /// chips in [AdmireStarsScreen]. Not a translation of a single canonical
  /// list; each language's phrasing is its own.
  List<String> get upliftingQuotes;

  // Star reader
  String indexOfCount(int index, int total);
  String get shareStarLabel;
  String get shareStarError;

  /// The hint pill over a lit star's photo in [StarReaderScreen] — shown
  /// pinned in place across both its states, only its text/icon swapping:
  /// [starReaderTapForPhotoHint] before the tap that hides every other
  /// control to show the photo full-screen, [starReaderTapForDataHint]
  /// after, to tap back. "Anywhere" spelled out because the pill itself
  /// isn't the tap target — it's just a reminder floating over the real
  /// one, which is the whole screen.
  String get starReaderTapForPhotoHint;
  String get starReaderTapForDataHint;

  // Sky tooltips (tapping a star or a constellation on the Sky itself)
  String get starQuickLookViewAction;
  String get starQuickLookEditAction;

  /// Short enough to sit fourth-across next to [starQuickLookViewAction]/
  /// [starQuickLookEditAction]/[deleteStarAction] in the tooltip's own
  /// compact action row — [shareStarLabel] is a full sentence-length label
  /// meant for a full-width button elsewhere, too long for this one.
  String get starQuickLookShareAction;

  /// [SkyNascentStarTooltip]'s own single action — opens the star form on
  /// that exact slot, same as tapping the nascent star directly would.
  String get nascentStarQuickLookConfigureAction;
  String constellationTooltipLitCount(int lit, int total);
  String areaTooltipStarCount(int count);

  // CreationSuccessDialog — shown right after creating any star or a new
  // constellation. One shared eyebrow, one message per kind of thing just
  // made.
  String get creationSuccessEyebrow;
  String get creationSuccessLitMessage;
  String get creationSuccessUnlitMessage;
  String get creationSuccessPulsarMessage;
  String get creationSuccessConstellationMessage;

  // Settings
  String get settingsEyebrow;
  String get settingsTitle;
  String get languageSection;
  String get languageEnglish;
  String get languageItalian;
  String get languageRomanian;
  String get reminderSection;
  String get reminderToggleLabel;
  String get reminderTimeLabel;
  String get skyGridSection;
  String get skyGridToggleLabel;
  String get notificationPermissionDenied;
  String get testNotificationButton;
  String get reminderNotificationTitle;

  /// A handful of varied notification body phrases, cycled through day by
  /// day so the reminder doesn't say the exact same thing every time.
  List<String> get reminderNotificationBodies;
  String get aboutSection;
  String aboutVersion(String version);
  String get aboutTagline;

  /// 12 short month abbreviations, January first, for [formatDisplayDate].
  List<String> get monthAbbreviations;

  /// 7 short weekday abbreviations, Monday first, for the dashboard's
  /// calendar header.
  List<String> get weekdayAbbreviations;

  /// The dashboard calendar's month heading, e.g. "August 2026".
  String monthTitle(DateTime month);

  // Onboarding — the first-launch "stories" tutorial, walking the same
  // metaphor the guide lays out in full: nascent/lit/pulsar/unlit/dead
  // stars, constellations, supernovas. Also reachable from Settings' debug
  // tools to replay it.
  String get onboardingIntroTitle;
  String get onboardingIntroBody;
  String get onboardingNascentTitle;
  String get onboardingNascentBody;
  String get onboardingLitTitle;
  String get onboardingLitBody;
  String get onboardingPulsarTitle;
  String get onboardingPulsarBody;
  String get onboardingUnlitTitle;
  String get onboardingUnlitBody;
  String get onboardingConstellationsTitle;
  String get onboardingConstellationsBody;
  String get onboardingAreasTitle;
  String get onboardingAreasBody;
  String get onboardingOutroTitle;
  String get onboardingOutroBody;
  String get onboardingNextAction;
  String get onboardingGetStartedAction;
  String get onboardingSkipTooltip;
}
