import 'app_strings.dart';

class StringsEn implements AppStrings {
  @override
  String get visionUnderline => 'Underline';
  @override
  String get visionDivider => 'Divider';

  @override
  String get moodboardTitle => 'Moodboard';
  @override
  String get moodboardPageDescription =>
      'Collect images, videos and words that make the life you want in this area visible. Add what inspires you and return here to keep your direction alive.';
  @override
  String get moodboardAddLabel => 'Add';
  @override
  String get moodboardEmpty =>
      'Collect photos, videos and words that bring your vision to life.';
  @override
  String get moodboardQuote => 'Quote';
  @override
  String get moodboardQuoteDescription =>
      'Write a short quote to add to the moodboard.';
  @override
  String get moodboardQuoteTextLabel => 'Quote';
  @override
  String get moodboardQuoteAuthorLabel => 'Author';
  @override
  String get moodboardQuoteAuthorHint => 'Optional';
  @override
  String get moodboardQuoteStyleLabel => 'Choose a style';
  @override
  String get moodboardQuoteStyleCelestial => 'Celestial';
  @override
  String get moodboardQuoteStyleAurora => 'Aurora';
  @override
  String get moodboardQuoteStyleEditorial => 'Editorial';
  @override
  String get moodboardQuoteStyleConstellation => 'Constellation';
  @override
  String get moodboardQuoteStyleMinimal => 'Minimal';
  @override
  String get moodboardVideo => 'Video';
  @override
  String get moodboardEdit => 'Edit';
  @override
  String get moodboardRemove => 'Remove';
  @override
  String get moodboardRemoveConfirm => 'Remove this item?';
  @override
  String get moodboardRemoveDescription =>
      'The item will be permanently removed from the moodboard.';
  @override
  String get moodboardSaveError =>
      'Could not save. Check available storage and try again.';
  @override
  String get moodboardMediaError => 'Media unavailable or format unsupported.';
  @override
  String get moodboardPlay => 'Play';
  @override
  String get moodboardPause => 'Pause';
  @override
  String get areaSectionOpen => 'Open & Edit';
  @override
  String get areaReflectionsTitle => 'Reflections';

  @override
  String get carouselOneAtATime => 'One at a time';
  @override
  String get carouselFreeScroll => 'Free scrolling';
  @override
  String get visionUndo => 'Undo';
  @override
  String get viewAreaImageAction => 'View image';
  @override
  String get visionRedo => 'Redo';
  @override
  String get visionWrite => 'Write';
  @override
  String get visionPreview => 'Preview';
  @override
  String get visionHeading => 'Heading';
  @override
  String get visionSection => 'Section';
  @override
  String get visionBold => 'Bold';
  @override
  String get visionItalic => 'Italic';
  @override
  String get visionBulletList => 'Bullet list';
  @override
  String get visionNumberedList => 'Numbered list';
  @override
  String get visionEditorHint =>
      'Give your vision room to grow. Use the toolbar to format text and a blank line to separate paragraphs.';
  @override
  String get visionSaveError =>
      'Could not save. Your text is still here: try again.';
  const StringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get areaPhysical => 'Physical';
  @override
  String get areaPsychological => 'Psychological';
  @override
  String get areaProfessional => 'Professional';
  @override
  String get areaFinancial => 'Financial';
  @override
  String get areaPersonal => 'Personal';
  @override
  String get areaSocial => 'Social';
  @override
  String get areaSpiritual => 'Spiritual';
  @override
  String get areaPhilanthropic => 'Philanthropic';
  @override
  String get areaPhysicalDescription =>
      'Movement, strength, and the health that carries everything else.';
  @override
  String get areaPsychologicalDescription =>
      'Your mind — clarity, resilience, and emotional balance.';
  @override
  String get areaProfessionalDescription =>
      "Your work — career, craft, and the skills you're building.";
  @override
  String get areaFinancialDescription =>
      'Your money — saving, earning, and long-term security.';
  @override
  String get areaPersonalDescription =>
      'Your growth — habits, discipline, and self-improvement.';
  @override
  String get areaSocialDescription =>
      'Your people — friends, family, and real connection.';
  @override
  String get areaSpiritualDescription =>
      'Your inner life — meaning, stillness, and what you believe.';
  @override
  String get areaPhilanthropicDescription =>
      "Your impact — giving, service, and other people's lives.";

  @override
  List<String> get reflectionQuestionsPhysical => const [
    'How do you feel in your body these days?',
    'What do you do regularly to take care of your health?',
    "What's a physical habit you'd like to build, and what's holding you back?",
    'When do you feel most energetic during the day? What brings that on?',
  ];
  @override
  List<String> get reflectionQuestionsPsychological => const [
    "What's weighing on your mind the most right now?",
    'How do you handle stress when it shows up?',
    'What recurring thought would you like to let go of?',
    'What makes you feel calm and centered?',
  ];
  @override
  List<String> get reflectionQuestionsProfessional => const [
    'Do you feel fulfilled in your work? Why or why not?',
    "What's the next skill you want to develop?",
    'What would make your work feel more meaningful?',
    'Where do you see yourself professionally a year from now?',
  ];
  @override
  List<String> get reflectionQuestionsFinancial => const [
    "What's your relationship with money like?",
    'What worries you most about your finances?',
    "What's one concrete financial goal for the coming months?",
    'What would financial security actually feel like for you?',
  ];
  @override
  List<String> get reflectionQuestionsPersonal => const [
    'What are you learning about yourself lately?',
    'Which value guides your choices the most?',
    "What would you like to stop putting off?",
    'What are you proud of, even something small?',
  ];
  @override
  List<String> get reflectionQuestionsSocial => const [
    'Who would you like to spend more time with?',
    'How do you take care of your most important relationships?',
    'Is there a relationship that needs your attention right now?',
    'What do you really look for in the people around you?',
  ];
  @override
  List<String> get reflectionQuestionsSpiritual => const [
    'What gives your days meaning?',
    'When do you feel connected to something bigger than yourself?',
    'How do you cultivate inner peace?',
    'What does living authentically mean to you?',
  ];
  @override
  List<String> get reflectionQuestionsPhilanthropic => const [
    'How do you contribute to something bigger than yourself?',
    'Who have you helped recently, and how did it make you feel?',
    'What cause matters to you, and why?',
    "What could you give — time, skills, energy — that you're not giving yet?",
  ];
  @override
  String get reflectionQuestionsSectionLabel => 'Questions';
  @override
  String get reflectionQuestionsSubtitle =>
      "Answer when something genuinely moves you — it's fine to leave some blank.";
  @override
  String get reflectionsPageDescription =>
      'Use these questions to gain clarity about this area of your life. Open a question, write what comes up and note how difficult it was to find the answer.';
  @override
  String get reflectionAnswerHint => 'Write your answer here...';
  @override
  String get reflectionDifficultyLabel =>
      'How difficult was it to find this answer?';
  @override
  String get reflectionAnsweredCountLabel => 'answered';

  @override
  String get openMenuAction => 'Menu';
  @override
  String get menuButtonHoldHint => 'Hold to open';
  @override
  String get menuSearchSection => 'Sky';
  @override
  String get menuActivitySection => 'Activity';
  @override
  String get menuLightYourSky => 'Light Your Sky';
  @override
  String get menuLightAStar => 'Stars';
  @override
  String get menuNewConstellation => 'Constellations';
  @override
  String get lightYourSkyChooserSupernovaOption => 'Supernovas';
  @override
  String get menuShootingStars => 'Shooting Stars';
  @override
  String get menuDataSection => 'Data';
  @override
  String get menuSearch => 'Sky';
  @override
  String get menuStatistics => 'Statistics';
  @override
  String get menuNightlightSection => 'Nightlight';
  @override
  String get menuFindYourLight => 'Find Your Light';
  @override
  String get menuChallengesSection => 'Challenges';
  @override
  String get socialSection => 'Social';
  @override
  String get menuFriends => 'Friends';
  @override
  String get menuSettings => 'Settings';
  @override
  String get menuInfoSection => 'Info';
  @override
  String get menuMetaphor => 'Metaphor';
  @override
  String get menuOnboarding => 'Onboarding';

  @override
  String get menuLightYourSkyDescription =>
      'Enrich your sky with new sources of light.';
  @override
  String get menuShootingStarsDescription => 'A wish, timed — coming soon.';
  @override
  String get menuFindYourLightDescription =>
      "For when you're in the dark and need some light.";
  @override
  String get menuSearchDescription =>
      'Find any star, constellation, or supernova.';
  @override
  String get skyViewModeTooltip => 'View';
  @override
  String get skyViewModeTitle => 'View';
  @override
  String get skyViewList => 'List';
  @override
  String get skyViewGrid => 'Grid';
  @override
  String get skyViewCardSize => 'Card Size';
  @override
  String get skyViewSizeCompact => 'Compact';
  @override
  String get skyViewSizeMedium => 'Medium';
  @override
  String get skyViewSizeLarge => 'Large';
  @override
  String get skyViewSizeExtraLarge => 'Extra Large';
  @override
  String get menuStatisticsDescription =>
      "Today's star, your calendar, and your all-time numbers.";
  @override
  String get menuFriendsDescription =>
      "Shared constellations and celebrating wins together — coming soon.";
  @override
  String get menuMetaphorDescription => 'What every word in the sky means.';
  @override
  String get menuSettingsDescription =>
      'Language, reminders, and everything about your account.';
  @override
  String get menuLabSection => 'Lab';
  @override
  String get menuMoonLab => 'Moon Lab';
  @override
  String get menuMoonLabDescription =>
      "Experiment with Moon's look and layers.";

  @override
  String get comingSoonBadge => 'COMING SOON';
  @override
  String get shootingStarsBody =>
      'A wish you make the moment you spot it — then chase before it '
      "burns out. Shooting stars are still taking shape; soon you'll be "
      'able to set yourself a small, timed challenge and catch it in the '
      'sky before your window closes.';
  @override
  String get friendsBody =>
      "Shared constellations, messages, and celebrating each other's wins "
      'together — the social side of the sky is still ahead.';

  @override
  String get profileSection => 'Profile & Account';
  @override
  String get profilePlaceholderBody =>
      'Sign-in, your profile picture, a short description of yourself, '
      'and your friends list will live here.';
  @override
  String get customizationSection => 'Customization';
  @override
  String get customizationPlaceholderBody =>
      'Choosing your own fonts and graphic style is coming — for now the '
      'app picks them for you.';
  @override
  String get passkeySection => 'Passkey';
  @override
  String get passkeyPlaceholderBody =>
      'Passwordless sign-in with a passkey is on the way.';
  @override
  String get socialPlaceholderBody =>
      'Settings for how you appear to friends will live here once the '
      'social side of the app exists.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get todayStarSectionLabel => "Today's star";
  @override
  String get litTodayTitle => "Congrats, you've lit a star today!";
  @override
  String get litTodayTitleHighlight => 'star';
  @override
  String get litTodaySubtitle => "- you've brought new light to your life -";
  @override
  String get litTodaySubtitleHighlight => 'light';
  @override
  String get notLitTodayLabel => 'No star lit today yet';
  @override
  String get notLitTodayHighlight => 'star';
  @override
  String get lightStarCta => 'Light One';
  @override
  String get totalStarsLabel => 'Total stars';
  @override
  String get streaksSectionLabel => 'Streaks';
  @override
  String get currentStreakLabel => 'Current streak';
  @override
  String get longestStreakLabel => 'Longest streak';
  @override
  String get activityLabel => 'Activity';
  @override
  String get dayDetailEmpty => 'No stars lit this day.';
  @override
  String get addStarForDayLabel => 'Add';

  @override
  String get firstStarLabel => 'First star';
  @override
  String get mostRecentStarLabel => 'Most recent star';
  @override
  String get combinedIntensityLabel => 'Combined intensity';
  @override
  String get starsByAreaLabel => 'By supernova';
  @override
  String get streakFromLabel => 'From';
  @override
  String get streakToLabel => 'To';
  @override
  String get todayLabel => 'Today';
  @override
  String get starsLoggedLabel => 'Stars logged';
  @override
  @override
  String get noCurrentStreakBody =>
      'No streak going right now. Light a star today to start one.';

  @override
  String get searchHint => 'Search by title or description';
  @override
  String get noSearchResults => 'No stars match your search.';
  @override
  String get noSearchResultsSupernovas => 'No supernovas match your search.';
  @override
  String get noSearchResultsConstellations =>
      'No constellations match your search.';
  @override
  String get noSearchResultsStars => 'No stars match your search.';
  @override
  String get skyEmptyConstellations => 'No constellations yet.';
  @override
  String get skyEmptyStars => 'No stars yet.';
  @override
  String intensityCount(int value) => '$value intensity';
  @override
  String createdOnLabel(String date) => 'Created $date';
  @override
  String lastStarLabel(String date) => 'Last star $date';
  @override
  String get constellationsModeLabel => 'Constellations';
  @override
  String get listModeLabel => 'Stars';
  @override
  String get skyModeSupernovas => 'Supernovas';
  @override
  String get filtersAction => 'Filters';
  @override
  String get filterAreasAction => 'Filter areas';
  @override
  String get areaFilterDefaultLabel => 'Areas';
  @override
  String activeAreasCount(int count) => count == 1 ? '1 area' : '$count areas';
  @override
  String resultsAreasWord(int count) => count == 1 ? 'area' : 'areas';
  @override
  String resultsConstellationsWord(int count) =>
      count == 1 ? 'constellation' : 'constellations';
  @override
  String resultsStarsWord(int count) => count == 1 ? 'star' : 'stars';
  @override
  String get filterKindAction => 'Filter kinds';
  @override
  String get filterKindSectionTitle => 'Star Kinds';
  @override
  String get allKindsLabel => 'All';
  @override
  String get kindFilterDefaultLabel => 'Star Kinds';
  @override
  String activeKindsCount(int count) =>
      count == 1 ? '1 star kind' : '$count star kinds';
  @override
  String get applyFilterAction => 'Apply';
  @override
  String get filterDateRangeAction => 'Filter by date';
  @override
  String get dateRangeFilterSectionTitle => 'Date Range';
  @override
  String get dateRangeUnitWeek => 'Week';
  @override
  String get dateRangeUnitMonth => 'Month';
  @override
  String get dateRangeUnitYear => 'Year';
  @override
  String get dateRangeStepBackAction => 'Previous period';
  @override
  String get dateRangeStepForwardAction => 'Next period';
  @override
  String get dateRangeFromLabel => 'From';
  @override
  String get dateRangeToLabel => 'To';
  @override
  String get clearFilterAction => 'Reset';
  @override
  String get clearSearchTooltip => 'Clear search';
  @override
  String get sortAction => 'Sort results';
  @override
  String get sortButtonDefaultLabel => 'Sort';
  @override
  String get sortSheetTitle => 'Sort by';
  @override
  String get sortFieldDate => 'Date';
  @override
  String get sortFieldIntensity => 'Intensity';
  @override
  String get sortFieldName => 'Name';
  @override
  String get sortDirectionAscending => 'Ascending';
  @override
  String get sortDirectionDescending => 'Descending';
  @override
  String get searchButtonLabel => 'Search';
  @override
  String get takeMeThereAction => 'Take me there';
  @override
  String get creationSuccessOpenAction => 'Open';
  @override
  String get creationSuccessFlyAction => 'Fly';
  @override
  String get searchCardMenuOpenAction => 'Open card menu';
  @override
  String get searchCardMenuCloseAction => 'Close card menu';
  @override
  String get searchCardOpenAction => 'Open';
  @override
  String get actionFly => 'Fly';
  @override
  String get actionLight => 'Light';
  @override
  String get actionTurnOff => 'Turn off';
  @override
  String get actionReignite => 'Reignite';
  @override
  String get noDateShortLabel => 'No date';
  @override
  String get formerPulsarLabel => 'former habit';
  @override
  String get searchScreenEyebrow => 'SEARCH';
  @override
  String get areaVisionLabel => 'Your vision for this area';
  @override
  String get areaVisionHint =>
      "What kind of reality do you want here? What are you working toward?";
  @override
  String get visionPageTitle => 'Vision';
  @override
  String get visionPageDescription =>
      'Define the reality you want in this area of your life. Write what you want to move toward and describe it in words that can guide your choices over time.';
  @override
  String get editVisionAction => 'Edit vision';
  @override
  String get areaVisionPlaceholderPhysical => '''
*Example vision — make it your own.*

# Feeling at home in my body

I want to feel at home in my body and have energy for what I love. I cultivate **strength, care and rest** through habits I can sustain in difficult weeks too.

## In my everyday life

- Move in ways I enjoy, at my own pace.
- Make room for sleep and recovery.
- Listen to my needs without judging myself.

## I notice I am growing when…

I notice sooner when I need a break and feel more present in my days.
''';
  @override
  String get areaVisionPlaceholderPsychological => '''
*Example vision — make it your own.*

# Being on my own side

I want to understand my feelings and treat myself with **respect and kindness**. I make room for emotions and learn to choose my response, even when I cannot change what happens.

## In my everyday life

- Pause to name what I am feeling.
- Recognize my limits and ask for support.
- Speak to myself as I would to someone I love.

## I notice I am growing when…

I can recover from a difficult day without turning it into a judgment of myself.
''';
  @override
  String get areaVisionPlaceholderProfessional => '''
*Example vision — make it your own.*

# Work I can recognize myself in

I want a path that brings together **skill, curiosity and usefulness**. I devote myself to projects whose value I understand and give work a sustainable place in my life.

## In my everyday life

- Develop the skills I want to use.
- Seek feedback and share what I learn.
- Protect time for life outside work.

## I notice I am growing when…

I can explain what I am learning and why my contribution matters, beyond the results.
''';
  @override
  String get areaVisionPlaceholderFinancial => '''
*Example vision — make it your own.*

# More peace, more possibilities

I want a clear, thoughtful relationship with money. I build **security and freedom of choice**, making room for both present needs and future hopes.

## In my everyday life

- Understand my income and spending.
- Prioritize what matters to me.
- Set resources aside when I can.

## I notice I am growing when…

I approach financial decisions with more clarity and less avoidance.
''';
  @override
  String get areaVisionPlaceholderPersonal => '''
*Example vision — make it your own.*

# A life that feels like mine

I want to make room for curiosity and become someone I can trust. I cultivate **creativity, independence and discovery** without turning every interest into a performance.

## In my everyday life

- Make time for an interest simply because I enjoy it.
- Try something new and allow myself to be a beginner.
- Keep small promises to myself.

## I notice I am growing when…

I can see choices in my week that feel truly my own.
''';
  @override
  String get areaVisionPlaceholderSocial => '''
*Example vision — make it your own.*

# Relationships with room to be ourselves

I want connections where I can be myself and give others that same space. I choose **listening, reciprocity and honesty**, including the courage to express needs and boundaries.

## In my everyday life

- Give attention to the people I care about.
- Listen without immediately preparing a reply.
- Be clear about what I can offer and what I need.

## I notice I am growing when…

I feel free to ask for closeness and offer presence while staying connected to my own needs.
''';
  @override
  String get areaVisionPlaceholderSpiritual => '''
*Example vision — make it your own.*

# Making room for what matters

I want to feel connected to life and live according to my values. I seek **meaning, wonder and reflection** in a form that feels right to me, leaving room for unanswered questions.

## In my everyday life

- Make time for silence or contemplation.
- Connect with nature, a practice or a community.
- Ask whether my choices reflect what I believe.

## I notice I am growing when…

Even on ordinary days, I find something that invites me to pause and be present.
''';
  @override
  String get areaVisionPlaceholderPhilanthropic => '''
*Example vision — make it your own.*

# Leaving something good behind

I want to support people and places beyond my everyday life. I offer **time, attention and skills** in practical, sustainable ways, starting with the needs of those receiving help.

## In my everyday life

- Listen before deciding how to help.
- Choose a cause I can support consistently.
- Offer what I can while respecting my limits.

## I notice I am growing when…

My contribution meets a real need and is something I can sustain.
''';
  @override
  String get areaCoverEnterAction => 'Manage';
  @override
  String get areaCoverVisionTitle => 'Vision';

  @override
  String get dataSection => 'Debug tools';
  @override
  String get seedSampleData => 'Seed sample data';
  @override
  String seedSampleDataResult(int count) =>
      'Added $count stars to the sample constellations.';
  @override
  String get resetAllData => 'Reset all data';
  @override
  String get resetAllDataConfirmTitle => 'Reset all data?';
  @override
  String get resetAllDataConfirmBody =>
      'This permanently deletes every star and constellation. This cannot be undone.';
  @override
  String get cancel => 'Cancel';
  @override
  String get deleteEverything => 'Delete everything';
  @override
  String get allDataCleared => 'All data cleared.';
  @override
  String get archiveEmpty =>
      'Your archive is still empty. Light your first star, even a small one.';

  @override
  String get soundLabEyebrow => 'AUDIO';
  @override
  String get soundLabTitle => 'Sound Lab';
  @override
  String get soundLabSubtitle =>
      'Background track, tap/hold sounds, and the sky\'s own movement whooshes — every sound experiment lives here.';
  @override
  String get soundLabButtonTooltip => 'Sound Lab';
  @override
  String get soundLabResetAction => 'Reset to defaults';
  @override
  String get backgroundTrackLabel => 'Background track';
  @override
  String get pauseBackgroundTrackAction => 'Pause';
  @override
  String get playBackgroundTrackAction => 'Play';
  @override
  String get tapSoundLabel => 'Tap sound';
  @override
  String get holdSoundLabel => 'Hold sound';
  @override
  String get whooshInLabel => 'Zoom-in whoosh';
  @override
  String get whooshOutLabel => 'Zoom-out whoosh';
  @override
  String get backgroundTrackObservingTheStar => 'Observing the Star';
  @override
  String get backgroundTrackHeavenlyLoop => 'Heavenly Drift';
  @override
  String get backgroundTrackOutThere => 'Out There';
  @override
  String get backgroundTrackAmbientRelaxing => 'Relaxing Ambience';
  @override
  String get backgroundTrackBackgroundSpace => 'Cosmic Meditation';
  @override
  String get backgroundTrackNightlight => 'Nightlight';
  @override
  String get skySoundPluckSoft => 'Soft pluck';
  @override
  String get skySoundPluckBright => 'Bright pluck';
  @override
  String get skySoundGlassLow => 'Low glass';
  @override
  String get skySoundGlassHigh => 'High glass';
  @override
  String get skySoundGlassChime => 'Glass chime';
  @override
  String get skySoundGlassBell => 'Glass bell';
  @override
  String get skySoundGlassShine => 'Glass shine';
  @override
  String get skySoundGlassTwinkle => 'Glass twinkle';
  @override
  String get skySoundBong => 'Bell';
  @override
  String get skySoundConfirmation => 'Confirmation';
  @override
  String get skySoundChimeSoft => 'Soft chime';
  @override
  String get skySoundChimeWarm => 'Warm ding';
  @override
  String get skySoundChimeBright => 'Bright ding';
  @override
  String get skySoundSelect => 'Select';
  @override
  String get skySoundBlip => 'Blip';
  @override
  String get skySoundStarBlip => 'Star blip';
  @override
  String get skySoundShimmer => 'Shimmer';
  @override
  String get skySoundTick => 'Tick';
  @override
  String get skySoundToggle => 'Toggle';
  @override
  String get skySoundClick => 'Click';
  @override
  String get skySoundCosmicDing => 'Cosmic ding';
  @override
  String get skySoundCosmicBlink => 'Cosmic blink';
  @override
  String get skySoundCosmicBeep => 'Cosmic beep';
  @override
  String get skyWhooshA => 'Light whoosh';
  @override
  String get skyWhooshB => 'Heavy whoosh';
  @override
  String get skyWhooshC => 'Swift whoosh';
  @override
  String get skyWhooshD => 'Airy whoosh';
  @override
  String get skyWhooshE => 'Quick swoosh';
  @override
  String get skyWhooshF => 'Soft swoosh';
  @override
  String get tourSkipAction => 'Skip';
  @override
  String get tourBackAction => 'Back';
  @override
  String get tourNextAction => 'Next';
  @override
  String get tourDoneAction => 'Done';
  @override
  String tourProgressLabel(int step, int length) => '$step of $length';
  @override
  String get skyTourWelcomeTitle => 'Welcome to your sky';
  @override
  String get skyTourWelcomeBody =>
      'Every area of your life has its own supernova, every project its '
      'own constellation, every win and goal its own star. This is where '
      'it all lives — let\'s take a quick look around.';
  @override
  String get skyTourWelcomeStartAction => 'Start';
  @override
  String get skyTourTapConstellationTitle => 'Tap to fly there';
  @override
  String get skyTourTapConstellationBody =>
      'Tap any supernova, constellation or star to fly right up to it. Try this constellation.';
  @override
  String get skyTourDoubleTapTitle => 'Double-tap to zoom out';
  @override
  String get skyTourDoubleTapBody =>
      'Double-tap anywhere on empty sky to zoom back out.';
  @override
  String get skyTourHoldTitle => 'Hold to peek';
  @override
  String get skyTourHoldBody =>
      'Press and hold a constellation to peek at it before deciding '
      'whether to fly there.';
  @override
  String get skyTourTooltipTitle => 'Every kind shows something different';
  @override
  String get skyTourTooltipBody =>
      'A supernova, a constellation, a star — each one\'s popup shows its '
      'own info and options. Close this one — the X, tapping elsewhere, '
      'or moving on — to continue.';
  @override
  String get skyTourMenuTitle => 'Open the menu';
  @override
  String get skyTourMenuBody =>
      'Hold this star to create something new or find your way around.';
  @override
  String get skyTourMenuCloseTitle => 'Closing this menu';
  @override
  String get skyTourMenuCloseBody =>
      'Swipe it down, tap outside it, or use the back button — any of '
      'these closes it.';
  @override
  String get skyTourMenuCloseTryAction => 'Try it';
  @override
  String get skyTourQuickMenuTapTitle => 'A quicker way in';
  @override
  String get skyTourQuickMenuTapBody =>
      'A plain tap on this star — no holding — opens a faster shortcut '
      'menu instead of the full one.';
  @override
  String get skyTourNightlightHintTitle => 'Nightlight';
  @override
  String get skyTourNightlightHintBody =>
      'A place to find light whenever you need it.';
  @override
  String get skyTourSkyHintTitle => 'Sky';
  @override
  String get skyTourSkyHintBody =>
      'Find and add supernovas, constellations, and stars.';
  @override
  String get starTourKindTitle => 'Three kinds of stars';
  @override
  String get starTourKindBody =>
      'Choose between a Victory (already done), a Goal (still to do, an unlit star) and a Habit (a pulsar you repeat). Each one asks for different details.';
  @override
  String get starTourIntensityTitle => 'How much it cost';
  @override
  String get starTourIntensityBody =>
      "Rate the effort, 1 to 5 — not how big the result looks, what it "
      'actually took from you.';
  @override
  String get searchTourModeTitle => 'Three levels';
  @override
  String get searchTourModeBody =>
      'Switch between Supernovas (your life areas), Constellations (your projects) and Stars (single efforts).';
  @override
  String get searchTourFilterButtonTitle => 'View, filters and sorting';
  @override
  String get searchTourFilterButtonBody =>
      'Switch between grid and list, narrow things down by area, kind or date, and change the order.';
  @override
  String get lightYourSkyTourIntroTitle => 'Three ways to light your sky';
  @override
  String get lightYourSkyTourIntroBody =>
      'Supernovas are your life areas and their visions. Constellations are projects: shapes your stars fill in. Stars are single efforts: a victory, a goal or a habit.';
  @override
  String get constellationTourCanvasTitle => 'Give it a shape';
  @override
  String get constellationTourCanvasBody =>
      'Every project needs a shape its stars will fill. Tap the preview or Draw to design your own, pick one from the library, or start over.';
  @override
  String get supernovaTourListTitle => 'Your eight areas';
  @override
  String get supernovaTourListBody =>
      'Tap one to see, and edit, the vision you wrote for it.';
  @override
  String get supernovaTourEditTitle => 'Edit your vision';
  @override
  String get supernovaTourEditBody =>
      'Write down the reality you want here — you can always come back '
      'and revise it.';
  @override
  String get supernovaTourReflectionTitle => 'Reflection questions';
  @override
  String get supernovaTourReflectionBody =>
      'A few prompts for this area — answer whenever you feel like it.';
  @override
  String get replayToursAction => 'Replay';
  @override
  String get replayToursResult =>
      'Tutorials reset — open each screen again to see them';
  @override
  String get tutorialsButtonTooltip => 'Tutorials';
  @override
  String get tutorialsManagementTitle => 'Tutorials';
  @override
  String get tutorialsEnabledLabel => 'Show tutorials';
  @override
  String get tutorialsEnabledDescription =>
      'Guided tips appear the first time you open a screen that has one.';
  @override
  String get tutorialsScreenIntro =>
      'Forgot how something works, or want to show it to a friend? Replay any tutorial here.';
  @override
  String get tutorialDemoProjectName => 'Getting fit';
  @override
  String get tutorialDemoStarTitle => 'My first 5K run';
  @override
  String get tutorialDemoStarDescription =>
      'Crossed the line without stopping. Slower than I hoped, but I did it.';
  @override
  String get resetToursAction => 'Reset All Tutorials';
  @override
  String get tutorialsOpenAction => 'Open Tutorials';
  @override
  String get tutorialReplayConfirmTitle => 'Watch it again?';
  @override
  String get tutorialReplayConfirmBody =>
      'Do you want to see the live tutorial for this feature again? You\'ll be taken to the right place, and brought back here when it ends.';
  @override
  String get tutorialReplayConfirmAction => 'Yes, Show Me';
  @override
  String get tutorialEntrySkyNavigationTitle => 'Navigating the Cosmo';
  @override
  String get tutorialEntrySkyNavigationBody =>
      'Move through the sky, zoom, and open the menu.';
  @override
  String get tutorialEntryLightYourSkyTitle => 'Light Your Sky';
  @override
  String get tutorialEntryLightYourSkyBody =>
      'Supernovas, constellations and stars: what you can create.';
  @override
  String get tutorialEntryStarFormTitle => 'Recording a Star';
  @override
  String get tutorialEntryStarFormBody =>
      'Victories, goals and habits: choosing the right kind.';
  @override
  String get tutorialEntryShapeEditorTitle => 'Drawing a Shape';
  @override
  String get tutorialEntryShapeEditorBody =>
      'Place, connect and move stars in the shape editor.';
  @override
  String get tutorialEntryConstellationFormTitle => 'Creating a Constellation';
  @override
  String get tutorialEntryConstellationFormBody =>
      'Pick an area and give your project a shape.';
  @override
  String get tutorialEntrySearchStarsTitle => 'Browsing the Sky';
  @override
  String get tutorialEntrySearchStarsBody =>
      'Search, filter and switch between the three levels.';
  @override
  String get tutorialEntrySupernovaVisionTitle => 'Life Area Visions';
  @override
  String get tutorialEntrySupernovaVisionBody =>
      'Reflect on each area and write your vision.';
  @override
  String get tutorialEntryStarReaderTitle => 'Reading a Star';
  @override
  String get tutorialEntryStarReaderBody =>
      'Browse your stars and see what you can do with them.';
  @override
  String get quickSettingsButtonTooltip => 'Quick Settings';
  @override
  String get quickSettingsEyebrow => 'QUICK SETTINGS';
  @override
  String get quickSettingsTitle => 'Quick Settings';
  @override
  String get quickSettingsAudioSection => 'Audio';
  @override
  String get quickSettingsOpenSoundLabAction => 'Sound Lab';
  @override
  String get uiSandboxButtonTooltip => 'UI Sandbox';
  @override
  String get uiSandboxTitle => 'UI Sandbox';
  @override
  String get uiSandboxIntro =>
      'A read-only audit of current variants and proposed standards. Samples are interactive but never touch real app data.';
  @override
  String get uiSandboxFiltersTitle => 'Audit filters';
  @override
  String get uiSandboxViewportTitle => 'Responsive specimens';
  @override
  String get uiSandboxViewportBody =>
      'Switch viewport width, then exercise the isolated states below.';
  @override
  String get uiSandboxMatrixTitle => 'Audit matrix';
  @override
  String uiSandboxMatrixBody(int count) =>
      '$count matching entries. Expand one to review evidence, options and recommendation.';
  @override
  String uiSandboxVariantsCount(int count) => '$count current variants';
  @override
  String uiSandboxCandidatesCount(int count) => '$count candidates';
  @override
  String uiSandboxCategoriesCount(int count) => '$count categories';
  @override
  String get uiSandboxCategoryLabel => 'Category';
  @override
  String get uiSandboxAllLabel => 'All';
  @override
  String get uiSandboxAllStatesLabel => 'All decisions';
  @override
  String get uiSandboxExistingLabel => 'Current variant';
  @override
  String get uiSandboxCandidateLabel => 'Candidate standard';
  @override
  String get uiSandboxReviewStatus => 'To review';
  @override
  String get uiSandboxKeepStatus => 'Keep';
  @override
  String get uiSandboxReplaceStatus => 'Replace';
  @override
  String get uiSandboxExceptionStatus => 'Approved exception';
  @override
  String get uiSandboxOriginsLabel => 'Origins';
  @override
  String get uiSandboxStatesLabel => 'States checked';
  @override
  String get uiSandboxDifferencesLabel => 'Differences';
  @override
  String get uiSandboxRationaleLabel => 'Possible rationale';
  @override
  String get uiSandboxRisksLabel => 'UX and accessibility risks';
  @override
  String get uiSandboxOptionsLabel => 'Options';
  @override
  String get uiSandboxRecommendationLabel => 'Candidate recommendation';
  @override
  String get uiSandboxResetFiltersAction => 'Reset filters';
  @override
  String get uiSandboxTypographyCategory => 'Typography';
  @override
  String get uiSandboxActionsCategory => 'Buttons and actions';
  @override
  String get uiSandboxFieldsCategory => 'Fields';
  @override
  String get uiSandboxSelectionCategory => 'Selection controls';
  @override
  String get uiSandboxSurfacesCategory => 'Cards and surfaces';
  @override
  String get uiSandboxOverlaysCategory => 'Dialogs and sheets';
  @override
  String get uiSandboxNavigationCategory => 'Navigation';
  @override
  String get uiSandboxFeedbackCategory => 'Feedback';
  @override
  String get uiSandboxSpacingCategory => 'Spacing and shape';
  @override
  String get uiSandboxColorCategory => 'Color and states';
  @override
  String get uiSandboxIconsCategory => 'Icons';
  @override
  String get uiSandboxMotionCategory => 'Motion';
  @override
  String get uiSandboxTypographySpecimen => 'Typography variants';
  @override
  String get uiSandboxActionsSpecimen => 'Action variants and states';
  @override
  String get uiSandboxFieldsSpecimen => 'Field states';
  @override
  String get uiSandboxSelectionSpecimen => 'Selection states';
  @override
  String get uiSandboxSurfacesSpecimen => 'Gold theme principle';
  @override
  String get uiSandboxOverlaysSpecimen => 'Isolated modal patterns';
  @override
  String get volumeSectionLabel => 'Volume';
  @override
  String get backgroundVolumeLabel => 'Background';
  @override
  String get tapVolumeLabel => 'Tap';
  @override
  String get holdVolumeLabel => 'Hold';
  @override
  String get whooshVolumeLabel => 'Movement';

  @override
  String starsCount(int count) => '$count star${count == 1 ? '' : 's'}';
  @override
  String areaEmptyProjects(String areaName) =>
      'No constellations yet in $areaName. Start one to begin lighting stars here.';
  @override
  String get noProjectsYet =>
      'No constellations yet. Start one to begin lighting stars.';

  @override
  String get constellationShapeMissing =>
      "This constellation's shape couldn't be found.";

  @override
  String get drawYourOwnConstellation => 'Draw Your Own Stars Shape';
  @override
  String get constellationEditorTitle => 'Draw Your Stars Shape';
  @override
  String get constellationEditorEditTitle => 'Edit Your Stars Shape';
  @override
  String constellationEditorDisconnectedWarning(int count) =>
      '$count unconnected star${count == 1 ? '' : 's'}';
  @override
  String constellationEditorStarCount(int count, int max) =>
      'Used $count/$max stars';
  @override
  String get undoAction => 'Undo';
  @override
  String get redoAction => 'Redo';
  @override
  String get deletePointAction => 'Delete';
  @override
  String get saveConstellationAction => 'Save';
  @override
  String get nameYourConstellationTitle => 'Name Your Stars Shape';
  @override
  String get nameYourConstellationDescription =>
      'Choose a short name so you can recognize it in the sky.';
  @override
  String get constellationNameHint => 'E.g. My own path';
  @override
  String get constellationEditorGridToggleLabel => 'Grid';
  @override
  String get constellationEditorMirrorToggleLabel => 'Mirror';
  @override
  String get constellationEditorMirrorAxisVerticalLabel => 'Vertical';
  @override
  String get constellationEditorMirrorAxisHorizontalLabel => 'Horizontal';
  @override
  String get constellationEditorHelpAction => 'How this works';
  @override
  String get constellationEditorHelpTitle => 'How this works';
  @override
  String get constellationEditorHelpAddPoint => 'Tap empty space to add a star';
  @override
  String get constellationEditorHelpConnectPoint =>
      'Tap a star, then tap another to connect them with a line';
  @override
  String get constellationEditorHelpDisarmPoint =>
      'Tap the same star again to deselect it without connecting';
  @override
  String get constellationEditorHelpMovePoint =>
      'Press and drag a star to move it';
  @override
  String get constellationEditorHelpDeletePoint =>
      'Select a star, then tap the delete icon to remove it';
  @override
  String get constellationEditorHelpMirrorToggle =>
      'Turn on mirror mode to add, move, and delete stars on both sides at once';
  @override
  String get constellationEditorHelpMirrorAxis =>
      'Switch the axis to mirror left/right or top/bottom';
  @override
  String get constellationEditorHelpDontShowAgain => "Don't show this again";
  @override
  String get constellationEditorHelpClose => 'Got it';
  @override
  String get chooseShapeLabel => 'Constellation shape';
  @override
  String get shapeLibraryTitle => 'Constellation Shape';
  @override
  String get pickFromLibraryShort => 'Shapes';
  @override
  String get drawShapeShort => 'Draw';
  @override
  String get resetShapeShort => 'Reset';
  @override
  String get shapeSearchHint => 'Search shapes';
  @override
  String get shapeLibraryTabLabel => 'Library';
  @override
  String get yourShapesTabLabel => 'Your shapes';
  @override
  String get noCustomShapesYetHint => "You haven't drawn any shapes yet";
  @override
  String get editSelectedShapeAction => 'Edit';

  @override
  String get fieldLegendTitle => 'Info';
  @override
  String get requiredFieldLegend => 'Required';
  @override
  String get optionalFieldLegend => 'Optional';

  @override
  String get newProjectEyebrow => 'NEW CONSTELLATION';
  @override
  String get newProjectQuestion => 'What constellation is this?';
  @override
  String get areaLabel => 'Supernova';
  @override
  String get galaxyLabel => 'Galaxy';
  @override
  String get nameLabel => 'Name';
  @override
  String get newProjectNameHint => 'E.g. Run a marathon';
  @override
  String get projectDescriptionLabel => 'Description';
  @override
  String get projectDescriptionHint =>
      'E.g. Train three times a week and build up to 42K';
  @override
  String get iconLabel => 'Icon';
  @override
  String get chooseIconTitle => 'Icon';
  @override
  String get pickerConfirmAction => 'OK';
  @override
  String get closeAction => 'Close';
  @override
  String get displaySettingsTitle => 'Display';
  @override
  String get displaySettingsDescription =>
      'Choose which controls are visible in the sky.';
  @override
  String get createProject => 'Create constellation';
  @override
  String get newProject => 'New constellation';
  @override
  String get newAction => 'New';

  @override
  String get newStarEyebrow => 'NEW STAR';
  @override
  String get editStarEyebrow => 'EDIT STAR';
  @override
  String get configureStarEyebrow => 'CONFIGURE THIS STAR';
  @override
  String get litStarQuestion => 'What did you get through?';
  @override
  String get unlitStarQuestion => 'What do you want to reach?';
  @override
  String get pulsarQuestion => 'What do you want to keep doing, day by day?';
  @override
  String get projectLabel => 'Constellation';
  @override
  String get selectAProject => 'Select a constellation';
  @override
  String get selectASupernova => 'Select a supernova';
  @override
  String get dateLabel => 'Date';
  @override
  String get selectADateHint => 'Select a date';
  @override
  String get timeLabel => 'Time';
  @override
  String get selectATimeHint => 'Select a time';
  @override
  String get titleFieldLabel => 'Title';
  @override
  String get litTitleHint => 'E.g. Ran my first 5K';
  @override
  String get unlitTitleHint => 'E.g. Run a 5K';
  @override
  String get pulsarTitleHint => 'E.g. Go for a run';
  @override
  String get litDetailsHint => 'E.g. My legs were sore, but I finished';
  @override
  String get unlitDetailsHint => 'E.g. Sign up for a race and train for it';
  @override
  String get pulsarDetailsHint => 'E.g. Every morning before work';
  @override
  String get detailsLabel => 'Details';
  @override
  String get intensityLabel => 'Intensity';
  @override
  String get photoLabel => 'Photo';
  @override
  String get mainPhotoLabel => 'Main Photo';
  @override
  String get addPhotoHint => 'Add a photo';
  @override
  String get photoSourceTitle => 'Add Photo';
  @override
  String get takePhotoOption => 'Capture';
  @override
  String get choosePhotoOption => 'Upload';
  @override
  String get photoPickError => "Couldn't get that photo. Try again?";
  @override
  String get extrasHint =>
      'Add a voice note, photos, a video or a link to remember this victory.';
  @override
  String get extraVoiceNote => 'Voice Note';
  @override
  String get extraPhoto => 'Photo';
  @override
  String get extraLink => 'Link';
  @override
  String get resetExtraAction => 'Reset';
  @override
  String get addExtraAction => 'Add';
  @override
  String mediaMaxDuration(String duration) => 'Max $duration';
  @override
  String get recordVoiceTitle => 'Record a Voice Note';
  @override
  String get recordStart => 'Record';
  @override
  String get recordStop => 'Stop';
  @override
  String get recordKeep => 'Keep It';
  @override
  String get micPermissionDenied =>
      "Microphone access is off. Enable it in your phone's settings to record.";
  @override
  String get linkTitle => 'Add a Link';
  @override
  String get linkUrlHint => 'https://example.com';
  @override
  String get linkLabelHint => 'Label (optional)';
  @override
  String get linkInvalid => "That doesn't look like a valid link.";
  @override
  String get linkAdd => 'Add';
  @override
  String get mediaError => "Couldn't add that. Try again?";
  @override
  String get linkOpenError => "Couldn't open that link.";
  @override
  String get removeExtraTooltip => 'Remove';
  @override
  String mediaLimitReached(int max) => 'You can add up to $max extras.';
  @override
  String voiceNoteLabel(String duration) => 'Voice note · $duration';
  @override
  String get voiceNotesLabel => 'Voice Notes';
  @override
  String get extraPhotosLabel => 'Secondary Photos';
  @override
  String get videosLabel => 'Videos';
  @override
  String get linksLabel => 'Links';
  @override
  String get addVoiceNoteHint => 'Record a voice note';
  @override
  String get addExtraPhotosHint => 'Add photos';
  @override
  String get addVideoHint => 'Add a video';
  @override
  String get addLinkHint => 'Add a link';
  @override
  String get cropPhotoTitle => 'Adjust photo';
  @override
  String get cropPhotoConfirm => 'Done';
  @override
  String get cropPhotoHint => 'Pinch and drag to fit your photo into the frame';
  @override
  String get saveChanges => 'Save';
  @override
  String get lightThisStar => 'Save';
  @override
  String get placeThisStarAction => 'Save';
  @override
  String get cannotSaveTitle => 'Missing information';
  @override
  String get cannotSaveMissingInfo =>
      'Complete the required fields shown below before saving.';
  @override
  String get constellationFullTitle => 'Constellation full';
  @override
  String get constellationFullCreateNew => 'Create';
  @override
  String constellationFullStars(int max) =>
      'This constellation already holds its $max stars. Start a new one in the same area to keep going?';
  @override
  String constellationFullPulsars(int max) =>
      'This constellation already holds its $max pulsars. Start a new one in the same area to keep going?';
  @override
  String get gotIt => 'OK';
  @override
  String get deleteStarConfirmTitle => 'Delete this star?';
  @override
  String get deleteStarConfirmBody =>
      "This turns the star into a failure — it leaves here, but stays in its spot in the sky, and you can reignite it later.";
  @override
  String get deletePulsarConfirmTitle => 'Delete this habit?';
  @override
  String get deletePulsarConfirmBody =>
      'The habit becomes a failure — it stops beating, but stays in its spot in the sky, and you can reignite it later as a habit again.';
  @override
  String get deleteStarAction => 'Delete';
  @override
  String get discardChangesConfirmTitle => 'Discard changes?';
  @override
  String get discardChangesConfirmBody => "You'll lose the changes you made.";
  @override
  String get discardChangesAction => 'Discard';

  @override
  String get targetDateLabel => 'Target date';
  @override
  String get selectATargetDateHint => 'Select a date';

  @override
  String goalTargetLabel(String date) => 'Goal for $date';

  @override
  String starSlotLabel(int slot) => 'Star #$slot';

  @override
  String pulsarNumberLabel(int number) => 'Habit #$number';
  @override
  String get markAchievedAction => 'Mark as achieved';
  @override
  String get markAchievedSheetTitle => 'How much did it take to get there?';
  @override
  String get markAchievedConfirm => 'Save';
  @override
  String get undoAchievedAction => 'Mark as not achieved';
  @override
  String get deadStarBody =>
      'This star was deleted. You can reignite it as a brand new star, in the same spot in the sky.';
  @override
  String get deadPulsarBody =>
      'This habit was deleted. You can reignite it as a brand new habit, in the same spot in the sky — its old streak stays behind.';
  @override
  String get reigniteAction => 'Reignite';

  @override
  String get habitFrequencyLabel => 'Frequency';
  @override
  String get habitFrequencyDaily => 'Every day';
  @override
  String get habitFrequencyWeekly => 'Every week';
  @override
  String habitFrequencySummaryDaily(int times) =>
      times == 1 ? 'Once a day' : '$times times a day';
  @override
  String habitFrequencySummaryWeekly(int times) => times == 1
      ? 'Once a week'
      : '$times times a week, on $times different days';
  @override
  String get customReminderToggleLabel => 'Custom reminder time';

  @override
  String get habitCurrentStreakLabel => 'Current streak';
  @override
  String get habitCheckAction => 'Check';
  @override
  String get habitUncheckAction => 'Uncheck';
  @override
  String get habitStillToDoLabel => 'Still to do';
  @override
  String get habitDoneTodayLabel => 'Done for today';
  @override
  String get undoHabitTodayAction => 'Undo';
  @override
  String get habitTodayLabel => 'Today';
  @override
  String get cardBadgeVoice => 'Voice notes';
  @override
  String get cardBadgePhotos => 'Photos';
  @override
  String get cardBadgeVideos => 'Videos';
  @override
  String get cardBadgeLinks => 'Links';
  @override
  String get cardBadgeLitStars => 'Lit stars';
  @override
  String get cardBadgeGoals => 'Goals';
  @override
  String get cardBadgeEmptySlots => 'Empty slots';
  @override
  String get cardBadgePulsarsToday => 'Habits lit today';
  @override
  String get cardBadgeHabits => 'Habits';
  @override
  String get cardBadgeDeadStars => 'Dead stars';
  @override
  String get cardBadgeConstellations => 'Constellations';
  @override
  String habitProgressToday(int done, int target) => '$done/$target today';
  @override
  String habitProgressThisWeek(int done, int target) =>
      '$done/$target this week';
  @override
  String habitThisWeekCaption(bool doneToday) =>
      doneToday ? 'This week · today done' : 'This week · not today yet';
  @override
  String get habitStatsSectionTitle => 'Pulsars';
  @override
  String get starsStatsSectionTitle => 'Stars';
  @override
  String get habitStatsActiveLabel => 'Active';
  @override
  String get habitStatsOnTrackLabel => 'On track';
  @override
  String get habitStatsConsistencyLabel => 'Consistency';
  @override
  String get habitStatsLongestLabel => 'Personal best';
  @override
  String get habitStatsTotalLabel => 'Total completions';
  @override
  String get habitStatsTrendLabel => 'Recent rhythm';
  @override
  String get habitStatsWeekdaysLabel => 'Your week';
  @override
  String get habitStatsBestDayLabel => 'Strongest day';
  @override
  String get habitStatsSupportDayLabel => 'Day to support';
  @override
  String get habitStatsNotEnoughData =>
      'A little more history will reveal this pattern.';
  @override
  String get habitStatsArchiveAction => 'Archive';
  @override
  String get habitStatsArchiveTitle => 'Past pulsars';
  @override
  String get habitStatsArchiveEmpty => 'No past pulsars yet.';
  @override
  String habitStatsDays(int count) => count == 1 ? '1 day' : '$count days';
  @override
  String habitStatsWeeks(int count) => count == 1 ? '1 week' : '$count weeks';

  @override
  String activePulsarsBadge(int count) =>
      count == 1 ? '1 active habit' : '$count active habits';

  @override
  String get starKindNascentName => 'Opportunity';
  @override
  String get starKindNascentPlural => 'Opportunities';
  @override
  String get starKindNascentMeaning => 'Not configured yet';

  @override
  String get starKindNascentExample =>
      'A point on a brand new constellation — drawn, but not decided yet.';
  @override
  String get starKindLitName => 'Victory';
  @override
  String get starKindLitPlural => 'Victories';
  @override
  String get starKindLitMeaning => 'Done';
  @override
  String get starKindLitExample =>
      'I got through the interview even though I was terrified.';
  @override
  String get starKindUnlitName => 'Goal';
  @override
  String get starKindUnlitPlural => 'Goals';
  @override
  String get starKindUnlitMeaning => 'To do';
  @override
  String get starKindUnlitExample => 'Run my first 10 km.';
  @override
  String get starKindPulsarName => 'Habit';
  @override
  String get starKindPulsarPlural => 'Habits';
  @override
  String get starKindPulsarMeaning => 'Ongoing';
  @override
  String get starKindPulsarExample => 'Ten minutes of stretching, every day.';
  @override
  String get starKindDeadName => 'Failure';
  @override
  String get starKindDeadPlural => 'Failures';
  @override
  String get starKindDeadMeaning => 'Deleted — can be reignited';
  @override
  String get starKindDeadExample =>
      'A goal you let go of — still there, still yours to reignite.';

  @override
  String get photoBadgeLabel => 'Photo';
  @override
  String get targetDateBadgeLabel => 'Target';
  @override
  String get deadDateBadgeLabel => 'Died';
  @override
  String get streakBadgeLabel => 'Streak';
  @override
  String get noPhotoLabel => 'No photo';
  @override
  String get noTargetDateLabel => 'No target date';
  @override
  String get noDeadDateLabel => 'No death date';

  @override
  String get chooseSupernovasToInclude => 'Choose which supernovas to include';
  @override
  String get allAreasLabel => 'All';
  @override
  String get admireAllAreasLabel => 'All';
  @override
  String get pickAtLeastOneArea => 'Pick at least one supernova to continue.';
  @override
  String get noStarsInSelection =>
      "No stars lit yet in the supernovas you picked.";
  @override
  String get viewYourStars => 'View';

  @override
  String get nightlightGateQuestionPrefix => 'Before we start, are you ';
  @override
  String get nightlightGateQuestionOkWord => 'okay';
  @override
  String get nightlightGateQuestionMiddle => ' or in ';
  @override
  String get nightlightGateQuestionCrisisWord => 'crisis';
  @override
  String get nightlightGateQuestionSuffix => ' mode?';
  @override
  String get nightlightGateOkPrefix => "I'm ";
  @override
  String get nightlightGateOkWord => 'okay';
  @override
  String get nightlightGateCrisisPrefix => "I'm in ";
  @override
  String get nightlightGateCrisisWord => 'crisis';
  @override
  String get nightlightExplainedTitle => 'Calm Down';
  @override
  String get nightlightExplainedSchemeAgitated => 'Agitated';
  @override
  String get nightlightExplainedSchemeBreathe => 'Breathe';
  @override
  String get nightlightExplainedSchemeClarity => 'See Clearly';
  @override
  String get nightlightExplainedBody =>
      "Before we look at your victories, let's pause for a moment and "
      '*breathe* to calm down. Follow the instructions on the screen.';
  @override
  String get nightlightExplainedContinue => 'Continue';
  @override
  String get nightlightBreathingGetReady => 'Get ready';
  @override
  String get nightlightBreathingInhale => 'Breathe In';
  @override
  String get nightlightBreathingExhale => 'Breathe Out';
  @override
  String get nightlightBreathingSkip => 'Continue';
  @override
  String nightlightBreathingCycleLabel(int current, int total) =>
      'Cycle $current of $total';
  @override
  String nightlightBreathingCyclesUntilSkip(int remaining) => remaining == 1
      ? 'You can continue after 1 cycle'
      : 'You can continue after $remaining cycles';
  @override
  String get nightlightBreathingCheckInTitle => 'How do you feel now?';
  @override
  String get nightlightBreathingCheckInBody =>
      "I hope you're feeling better now. If you're not okay yet, you can "
      'redo the exercise. If you feel okay, you can move on.';
  @override
  String get nightlightBreathingCheckInRedo => 'Redo';
  @override
  String get nightlightBreathingCheckInProceed => 'Proceed';

  @override
  String get newConstellationOption => 'New constellation';

  @override
  String get visionsEyebrow => 'THE BIGGEST PICTURE';
  @override
  String get visionsTitle => 'Your Visions';
  @override
  String get areasTitle => 'Areas';
  @override
  String get visionsSubtitle =>
      'One vision per supernova — the reality you want in that area of your '
      'life. Come back to read them, and rewrite them as you change.';
  @override
  String get visionEmptyLabel => 'No vision written yet';

  @override
  String get guideEyebrow => 'HOW YOUR SKY WORKS';
  @override
  String get guideTitle => 'The Metaphor';
  @override
  String get guideIntroBody =>
      'Everything here is one sky, read at three sizes: the areas of your '
      'life burn as supernovas, the projects orbiting them are '
      'constellations, and every effort you make is a star.';
  @override
  String get examplesLabel => 'Examples';
  @override
  String get guideAreaTitle => 'Supernova';
  @override
  String get guideAreaMeaning => 'An area of your life';
  @override
  String get guideAreaBody =>
      'The biggest thing in your sky, and the only fixed one: 8 areas, '
      'always the same. A supernova holds your vision — the reality you '
      'want in that part of your life. Everything else is placed around '
      'the one it belongs to.';
  @override
  String get guideAreaExamples =>
      'Physical · Professional · Social — each with the vision you write '
      'for it: "a body I trust, all year round".';
  @override
  String get guideConstellationTitle => 'Constellation';
  @override
  String get guideConstellationMeaning => 'A project in your life';
  @override
  String get guideConstellationBody =>
      'A shape you draw yourself, orbiting one supernova. It gathers every '
      'effort about the same thing. Its shape is there from the first day '
      '— the stars along it simply start out nascent, waiting for you.';
  @override
  String get guideConstellationExamples =>
      'Get back in shape · Build this app · Be a better friend';
  @override
  String get guideStarTitle => 'Star';
  @override
  String get guideStarMeaning => 'One effort — past, present or future';
  @override
  String get guideStarBody =>
      'The smallest thing in your sky, and the only one you make yourself. '
      'A star is always an effort; its kind says where that effort sits in '
      'time, and whether it is burning right now.';
  @override
  String get guideStarExamples =>
      'I trained even though I did not want to · Run 10 km · Ten minutes '
      'of stretching, every day';
  @override
  String get guideKindsTitle => 'The five kinds of star';
  @override
  String get guideKindsBody =>
      'Gold means light: the effort is burning. Blue means no light: '
      'nothing is being given right now. White means the slot is still '
      'yours to fill.';
  @override
  String get guideIntensityTitle => 'Intensity';
  @override
  String get guideIntensityBody =>
      'Every burning star carries an intensity, 1 to 5 — how much the '
      'effort actually cost you, not how big the result looks from '
      'outside. A lit star keeps the intensity it took; a pulsar carries '
      'what it costs you each day.';

  @override
  List<String> get upliftingQuotes => const [
    "You don't have to see the whole staircase, just take the first step.",
    'Small steps still move you forward.',
    "You've survived every hard day so far. That's a perfect record.",
    'Rest is not the same as giving up.',
    'You are allowed to be both a work in progress and worthy of love at the same time.',
    'This feeling is real, but it is not permanent.',
    "You don't have to have it all figured out to keep going.",
    'Progress, not perfection.',
    "Some days, just being here is enough. That counts.",
    "You've made it through 100% of your worst days so far.",
    'Be patient with yourself. Nothing in nature blooms all year.',
    "It's okay to not be okay — just don't stay there alone.",
    "One breath at a time. That's all this moment is asking of you.",
    'You are stronger than you think and more loved than you know.',
    'Even the darkest night will end, and the sun will rise.',
    "Healing isn't linear, and that's alright.",
  ];

  @override
  String indexOfCount(int index, int total) => '$index of $total';
  @override
  String get shareStarLabel => 'Share this Star';
  @override
  String get shareStarError => "Couldn't share that star. Try again?";
  @override
  String get shareContentError => "Couldn't share that. Try again?";
  @override
  String get sharePreviewTitle => 'Share preview';
  @override
  String get shareChooseLayout => 'Choose a layout';
  @override
  String get shareLayoutImmersive => 'Editorial';
  @override
  String get shareLayoutFramed => 'Photo';
  @override
  String get shareLayoutPostcard => 'Statement';
  @override
  String get shareNowAction => 'Share';
  @override
  String get starReaderTourIntroTitle => 'Moving between stars';
  @override
  String get starReaderTourIntroBody =>
      'Swipe sideways to go to the previous or next star. On a star with a photo, tap an empty spot to see just the photo.';
  @override
  String get starReaderTourDockTitle => 'Everything you can do';
  @override
  String get starReaderTourDockBody =>
      'These buttons change with the star: light it, share it, edit it, delete it, or bring it back.';

  @override
  String get starQuickLookViewAction => 'View';
  @override
  String get starQuickLookEditAction => 'Edit';
  @override
  String get starQuickLookShareAction => 'Share';

  @override
  String get constellationQuickLookAddStarAction => '+ Star';

  @override
  String get areaQuickLookReflectionsAction => 'Reflections';

  @override
  String get areaQuickLookNewConstellationAction => '+ Constellation';
  @override
  String get nascentStarQuickLookConfigureAction => 'Configure';
  @override
  String constellationTooltipLitCount(int lit, int total) =>
      '$lit/$total victories';
  @override
  String get creationSuccessEyebrow => 'Congrats!';
  @override
  String get creationSuccessLitMessage => 'A star has been lit in your sky.';
  @override
  String get creationSuccessUnlitMessage =>
      'A new goal has been set in your sky.';
  @override
  String get creationSuccessPulsarMessage =>
      'A new habit has begun pulsing in your sky.';
  @override
  String get creationSuccessConstellationMessage =>
      'A new constellation has been added to your sky.';
  @override
  String areaTooltipStarCount(int count) =>
      '$count star${count == 1 ? '' : 's'} lit';

  @override
  String get settingsEyebrow => 'SETTINGS';
  @override
  String get settingsTitle => 'Settings';
  @override
  String get languageSection => 'Language';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageItalian => 'Italiano';
  @override
  String get languageRomanian => 'Română';
  @override
  String get reminderSection => 'Daily reminder';
  @override
  String get reminderToggleLabel => 'Remind me to light a star';
  @override
  String get reminderTimeLabel => 'Reminder time';

  @override
  String get skyGridSection => 'Sky grid';
  @override
  String get skyGridToggleLabel => 'Show coordinate grid on the sky';
  @override
  String get skySupernovaeSection => 'Supernovae';
  @override
  String get skySupernovaeToggleLabel => 'Show the supernovae over the artwork';
  @override
  String get skyArtworkSection => 'Artwork';
  @override
  String get skyArtworkOpacityLabel => 'Opacity';
  @override
  String get skySupernovaScaleLabel => 'Supernova size';
  @override
  String get skySupernovaIntensityLabel => 'Supernova brightness';
  @override
  String get skyArtworkBlendLabel => 'Blending Mode';
  @override
  String get skyArtworkResetDefaultsLabel => 'Reset to defaults';
  @override
  String get skyArtworkControlsTooltip => 'Artwork controls';
  @override
  String get skyArtworkScaleLabel => 'Size';
  @override
  String get skyArtworkColorLabel => 'Color';
  @override
  String get skyArtworkSaturationLabel => 'Saturation';
  @override
  String get skyArtworkLightnessLabel => 'Lightness';
  @override
  String get skyArtworkLayerLabel => 'Layer';
  @override
  String get skyArtworkLayerBehindSky => 'Behind the sky';
  @override
  String get skyArtworkLayerBehindSupernovae => 'Behind supernovae';
  @override
  String get skyArtworkLayerAboveStars => 'Above stars';

  @override
  String get appLockSection => 'App Lock';
  @override
  String get appLockToggleLabel => 'Enable App Lock';
  @override
  String get appLockBiometricToggleLabel => 'Use Fingerprint';
  @override
  String get appLockChangePinLabel => 'Change PIN';
  @override
  String get appLockSetPinTitle => 'Set a PIN';
  @override
  String get appLockConfirmPinTitle => 'Confirm Your PIN';
  @override
  String get appLockEnterCurrentPinTitle => 'Enter Your Current PIN';
  @override
  String get appLockPinMismatchError => "The PINs didn't match — try again.";
  @override
  String get appLockWrongPinError => 'Wrong PIN — try again.';
  @override
  String get appLockBiometricReason => 'Unlock Inner Stars';
  @override
  String get appLockUnlockTitle => 'Enter Your PIN';
  @override
  String get notificationPermissionDenied =>
      'Notifications are turned off for this app in your phone settings.';
  @override
  String get testNotificationButton => 'Send test notification';
  @override
  String get reminderNotificationTitle => 'Light a star';

  @override
  List<String> get reminderNotificationBodies => const [
    'What got you through today, even a little?',
    'Even the smallest step still lights a star.',
    'Take a moment — what went right today?',
    'Your sky is waiting for tonight\'s star.',
    'Did you get through something today? Write it down.',
  ];
  @override
  String get aboutSection => 'About';
  @override
  String aboutVersion(String version) => 'Version $version';
  @override
  String get aboutTagline =>
      'A personal growth app for recording the moments you got through.';
  @override
  String get downloadApkBannerBody =>
      "You're using the web version. For the real Android app, with "
      'notifications and everything else, download the APK.';
  @override
  String get downloadApkAction => 'Download';
  @override
  String get downloadApkPromptTitle => 'Want the real app?';
  @override
  String get downloadApkPromptContinueAction => 'Continue';

  @override
  List<String> get monthAbbreviations => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  List<String> get weekdayAbbreviations => const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  String monthTitle(DateTime month) =>
      '${_fullMonths[month.month - 1]} ${month.year}';

  @override
  String get onboardingIntroTitle => 'Welcome to your Sky';
  @override
  String get onboardingIntroBody =>
      'Inner Stars turns the things you accomplish into your own night '
      "sky — a place to look back on everything you've been through.";
  @override
  String get onboardingNascentTitle => 'A constellation is born whole';
  @override
  String get onboardingNascentBody =>
      'Draw a constellation and its shape is already there: the lines, and '
      'a nascent star on every point. Tap one to decide what it becomes.';
  @override
  String get onboardingLitTitle => 'An effort you made is a lit star';
  @override
  String get onboardingLitBody =>
      'The moment you get through something that mattered, you light a '
      'star. It stays there — proof of what you did, whenever you need to '
      'see it again.';
  @override
  String get onboardingPulsarTitle => 'Habits beat like pulsars';
  @override
  String get onboardingPulsarBody =>
      'Something you keep doing day by day is a pulsar — gold for as long '
      'as you keep the rhythm, dark the moment you lose it.';
  @override
  String get onboardingUnlitTitle => 'Goals are stars not lit yet';
  @override
  String get onboardingUnlitBody =>
      "Set a goal and it waits in the sky, unlit. Reach it and it lights "
      "up like any other star — let it go instead, and it becomes a dead "
      "star. Either way, it's still part of your sky.";
  @override
  String get onboardingConstellationsTitle => 'Group them into constellations';
  @override
  String get onboardingConstellationsBody =>
      'Stars and pulsars about the same thing — a project, a relationship, '
      'anything — belong to a constellation you name yourself.';
  @override
  String get onboardingAreasTitle => 'Constellations orbit supernovas';
  @override
  String get onboardingAreasBody =>
      'Every constellation orbits one of 8 supernovas — the fixed '
      'areas of your life, from physical to social to spiritual. Together, '
      "they're your Sky.";
  @override
  String get onboardingOutroTitle => 'Ready to light your first star?';
  @override
  String get onboardingOutroBody =>
      'Open the Sky menu any time: light a star, draw a constellation, or '
      'go back and re-read your visions.';
  @override
  String get onboardingNextAction => 'Next';
  @override
  String get onboardingGetStartedAction => 'Get started';
  @override
  String get onboardingSkipTooltip => 'Skip';
  @override
  String get dateInputInvalidValues => 'Invalid values';
  @override
  String get dateInputInvalidDay => 'Check the highlighted day.';
  @override
  String get dateInputInvalidMonth => 'The month must be between 1 and 12.';
  @override
  String dateInputInvalidYear(int firstYear, int lastYear) =>
      'The year must be between $firstYear and $lastYear.';
  @override
  String get dateInputOutsideRange => 'This date is outside the allowed range.';
}

const _fullMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
