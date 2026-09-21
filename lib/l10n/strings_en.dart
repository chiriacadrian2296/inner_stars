import 'app_strings.dart';

class StringsEn implements AppStrings {
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
  String get reflectionQuestionsSectionLabel => 'Reflection questions';
  @override
  String get reflectionQuestionsSubtitle =>
      "Answer when something genuinely moves you — it's fine to leave some blank.";
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
  String get menuSearchSection => 'Search';
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
  String get menuSearch => 'Search Stars';
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
  String get statsEyebrow => 'YOUR NUMBERS';
  @override
  String get statsTitle => 'Statistics';

  @override
  String get homeEyebrow => 'YOUR PROGRESS';
  @override
  String get homeTitle => 'Your dashboard';
  @override
  String get homeSubtitle =>
      'Every star is a win, lit when you needed the light.';
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
  String get addStarForDayLabel => 'Add a star for this day';

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
  String get filterAreasAction => 'Filter areas';
  @override
  String get areaFilterDefaultLabel => 'Areas';
  @override
  String activeAreasCount(int count) => count == 1 ? '1 area' : '$count areas';
  @override
  String get filterKindAction => 'Filter kinds';
  @override
  String get filterKindSectionTitle => 'Star kind';
  @override
  String get allKindsLabel => 'All kinds';
  @override
  String get kindFilterDefaultLabel => 'Star kinds';
  @override
  String activeKindsCount(int count) =>
      count == 1 ? '1 star kind' : '$count star kinds';
  @override
  String get applyFilterAction => 'Apply filter';
  @override
  String get filterDateRangeAction => 'Filter by date';
  @override
  String get dateRangeFilterSectionTitle => 'Date range';
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
  String get clearFilterAction => 'Clear';
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
  String get searchScreenEyebrow => 'SEARCH';
  @override
  String get areaVisionLabel => 'Your vision for this area';
  @override
  String get areaVisionHint =>
      "What kind of reality do you want here? What are you working toward?";
  @override
  String get editVisionAction => 'Edit vision';
  @override
  String get areaVisionPlaceholderPhysical =>
      'E.g. I move through my days with energy and strength, sleep well, '
      'and take care of this body I only get once. I show up for it '
      'consistently, not just when I feel like it.';
  @override
  String get areaVisionPlaceholderPsychological =>
      'E.g. My mind is clear and steady. I know how to calm myself, and I '
      "keep learning who I am. When things get hard, I don't run from what "
      "I'm feeling.";
  @override
  String get areaVisionPlaceholderProfessional =>
      'E.g. I do work that challenges me and matters, growing my skills '
      'without losing myself in it. I want to look back and be proud of '
      'how I got here, not just where I ended up.';
  @override
  String get areaVisionPlaceholderFinancial =>
      "E.g. I'm building real security — saving with intention and "
      'spending in ways that match what I actually value. Money stops '
      'being something I worry about and becomes something I use well.';
  @override
  String get areaVisionPlaceholderPersonal =>
      'E.g. I keep growing into who I want to be, one honest habit at a '
      "time. I'd rather make slow, real progress than fake a shortcut.";
  @override
  String get areaVisionPlaceholderSocial =>
      'E.g. I have people around me who know the real me, and I show up '
      "for them too. I'd rather have a few real connections than a lot of "
      'surface ones.';
  @override
  String get areaVisionPlaceholderSpiritual =>
      'E.g. I feel connected to something larger than myself, and I make '
      "space for stillness. I trust that not everything needs an answer "
      'right away.';
  @override
  String get areaVisionPlaceholderPhilanthropic =>
      'E.g. I give what I can — time, skill, attention — to lives beyond '
      "my own. It doesn't have to be big to be real.";
  @override
  String get areaCoverEnterAction => 'Manage This Area';
  @override
  String get areaCoverVisionTitle => 'Vision';
  @override
  String get areaConstellationsStatLabel => 'Constellations';
  @override
  String get areaStarsStatLabel => 'Stars';
  @override
  String get areaIntensityStatLabel => 'Intensity';

  @override
  String get dataSection => 'Debug tools';
  @override
  String get seedSampleData => 'Seed sample data';
  @override
  String seedSampleDataResult(int count) =>
      'Added $count stars to each seed constellation.';
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
  String get skyTourTapSupernovaTitle => 'Tap a supernova';
  @override
  String get skyTourTapSupernovaBody =>
      'Go on — tap any supernova to fly there.';
  @override
  String get skyTourTapConstellationTitle => 'Tap a constellation';
  @override
  String get skyTourTapConstellationBody =>
      'Now tap a constellation inside it to fly closer still.';
  @override
  String get skyTourTapStarTitle => 'Tap a star';
  @override
  String get skyTourTapStarBody => 'Tap any star to fly right up to it.';
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
  String get skyTourQuickSettingsHintTitle => 'Quick Settings';
  @override
  String get skyTourQuickSettingsHintBody =>
      'Jumps straight to sound and display settings.';
  @override
  String get skyTourSupernovasHintTitle => 'Supernovas';
  @override
  String get skyTourSupernovasHintBody =>
      'Takes you to any life area\'s own supernova.';
  @override
  String get skyTourConstellationsHintTitle => 'Constellations';
  @override
  String get skyTourConstellationsHintBody =>
      'Starts a brand-new constellation from scratch.';
  @override
  String get skyTourStarsHintTitle => 'Stars';
  @override
  String get skyTourStarsHintBody =>
      'Opens the form to record a win, a goal, or a habit.';
  @override
  String get skyTourSearchHintTitle => 'Search Stars';
  @override
  String get skyTourSearchHintBody =>
      'Finds any supernova, constellation, or star by name.';
  @override
  String get starTourIntroTitle => 'Recording a victory';
  @override
  String get starTourIntroBody =>
      'This form covers all three kinds of stars — a victory already won, '
      'a goal you\'re working toward, and a habit you\'re building. Here\'s '
      'a quick look at every field.';
  @override
  String get starTourKindTitle => 'Goals are stars not lit yet';
  @override
  String get starTourKindBody =>
      'Tap here to set a goal — it waits in your sky, unlit, until you '
      'reach it.';
  @override
  String get starTourLegendTitle => 'Required or optional';
  @override
  String get starTourLegendBody =>
      'A solid dot means a field is required; an outlined one means it\'s '
      'optional. Every field below shows one of these.';
  @override
  String get starTourSupernovaFieldTitle => 'Which area of life';
  @override
  String get starTourSupernovaFieldBody =>
      'Every star belongs to one of your eight supernovas — pick the one '
      'this fits.';
  @override
  String get starTourConstellationFieldTitle => 'Which constellation';
  @override
  String get starTourConstellationFieldBody =>
      'Stars group into constellations — pick the one this belongs to.';
  @override
  String get starTourTitleFieldTitle => 'Name your goal';
  @override
  String get starTourTitleFieldBody => 'What do you want to achieve?';
  @override
  String get starTourDetailsFieldTitle => 'Add details';
  @override
  String get starTourDetailsFieldBody =>
      "Say more if it helps — this part's optional.";
  @override
  String get starTourDateFieldTitle => 'When it happened';
  @override
  String get starTourDateFieldBody =>
      'The date and time this victory actually happened.';
  @override
  String get starTourTargetDateFieldTitle => 'A target date';
  @override
  String get starTourTargetDateFieldBody =>
      "Optional — when you're aiming to reach this by, if you know it yet.";
  @override
  String get starTourIntensityTitle => 'How much it cost';
  @override
  String get starTourIntensityBody =>
      "Rate the effort, 1 to 5 — not how big the result looks, what it "
      'actually took from you.';
  @override
  String get starTourHabitFrequencyTitle => 'Set the pace';
  @override
  String get starTourHabitFrequencyBody =>
      "How often you're aiming for this — daily or weekly, and how many "
      'times.';
  @override
  String get starTourReminderTitle => 'A daily nudge';
  @override
  String get starTourReminderBody =>
      'Optional — turn this on for a reminder at a time you pick.';
  @override
  String get starTourPhotoTitle => 'Add a photo';
  @override
  String get starTourPhotoBody =>
      'Optional — a picture of the moment, cropped to fit your sky.';
  @override
  String get starTourSaveTitle => 'Place it in your sky';
  @override
  String get starTourSaveBody =>
      "When you're ready, save it — it'll wait there, unlit, until you "
      'reach it.';
  @override
  String get searchTourIntroTitle => 'Finding anything in your sky';
  @override
  String get searchTourIntroBody =>
      'Search and filter your supernovas, constellations, and stars from '
      'here.';
  @override
  String get searchTourModeTitle => 'Three ways to look';
  @override
  String get searchTourModeBody =>
      'Switch between Supernovas, Constellations, and Stars.';
  @override
  String get searchTourFieldTitle => 'Search';
  @override
  String get searchTourFieldBody => 'Type to filter by name.';
  @override
  String get searchTourFilterButtonTitle => 'Filter by area';
  @override
  String get searchTourFilterButtonBody =>
      "Narrow things down to just the areas you care about right now.";
  @override
  String get searchTourAllAreasTitle => 'All areas';
  @override
  String get searchTourAllAreasBody =>
      'Flip this on to include them all, or pick just the ones you care about.';
  @override
  String get searchTourApplyTitle => 'Apply';
  @override
  String get searchTourApplyBody => 'Save your filter and see the results.';
  @override
  String get lightYourSkyTourIntroTitle => 'Three ways to light your sky';
  @override
  String get lightYourSkyTourIntroBody =>
      'Every star starts here — pick whichever one matches what you want '
      'to record.';
  @override
  String get lightYourSkyTourSupernovaTitle => 'Supernovas';
  @override
  String get lightYourSkyTourSupernovaBody =>
      'Revisit and edit the vision for one of your life areas.';
  @override
  String get lightYourSkyTourConstellationTitle => 'Constellations';
  @override
  String get lightYourSkyTourConstellationBody =>
      'Start a new project — a shape your stars will fill in.';
  @override
  String get lightYourSkyTourStarTitle => 'Stars';
  @override
  String get lightYourSkyTourStarBody =>
      'Record an effort: a victory, a goal, or a new habit.';
  @override
  String get constellationTourIntroTitle => 'Starting a new project';
  @override
  String get constellationTourIntroBody =>
      "A quick look at every field before you fill them in.";
  @override
  String get constellationTourLegendTitle => 'Required or optional';
  @override
  String get constellationTourLegendBody =>
      'A solid dot means a field is required; an outlined one means it\'s '
      'optional. Every field below shows one of these.';
  @override
  String get constellationTourAreaTitle => 'Pick an area';
  @override
  String get constellationTourAreaBody =>
      "Which part of your life is this project for?";
  @override
  String get constellationTourIconFieldTitle => 'Pick a badge';
  @override
  String get constellationTourIconFieldBody =>
      'The small icon that marks this constellation in lists.';
  @override
  String get constellationTourNameTitle => 'Name it';
  @override
  String get constellationTourNameBody => "What's this project called?";
  @override
  String get constellationTourDescriptionTitle => 'Add a description';
  @override
  String get constellationTourDescriptionBody =>
      "Optional — say more about what it's for.";
  @override
  String get constellationTourCanvasTitle => 'Give it a shape';
  @override
  String get constellationTourCanvasBody =>
      'Every project needs a shape its stars will fill — this is what '
      "you've chosen so far. Tap it any time to change it.";
  @override
  String get constellationTourDrawButtonTitle => 'Draw your own';
  @override
  String get constellationTourDrawButtonBody =>
      'Sketch a custom shape from scratch.';
  @override
  String get constellationTourLibraryButtonTitle => 'Pick from the library';
  @override
  String get constellationTourLibraryButtonBody =>
      "Choose a ready-made shape instead of drawing your own.";
  @override
  String get constellationTourResetButtonTitle => 'Start over';
  @override
  String get constellationTourResetButtonBody =>
      'Clears the shape you\'ve picked so far.';
  @override
  String get constellationTourSaveTitle => 'Create it';
  @override
  String get constellationTourSaveBody => 'Save your new constellation.';
  @override
  String get supernovaTourIntroTitle => 'Reflecting on your life areas';
  @override
  String get supernovaTourIntroBody =>
      'Each of your eight areas keeps its own reflections — here\'s how '
      'to get to them.';
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
  String get replayToursAction => 'Replay tutorials';
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
  String get quickSettingsButtonTooltip => 'Quick Settings';
  @override
  String get quickSettingsEyebrow => 'QUICK SETTINGS';
  @override
  String get quickSettingsTitle => 'Quick Settings';
  @override
  String get quickSettingsAudioSection => 'Audio';
  @override
  String get quickSettingsOpenSoundLabAction => 'Open Sound Lab';
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
  String get shapeLibraryTitle => 'Shape Library';
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
  String get editSelectedShapeAction => 'Edit this shape';

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
  String get chooseIconTitle => 'Choose An Icon';
  @override
  String get pickerConfirmAction => 'OK';
  @override
  String get closeAction => 'Close';
  @override
  String get createProject => 'Create constellation';
  @override
  String get newProject => 'New constellation';

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
  String get addPhotoHint => 'Add a photo';
  @override
  String get takePhotoOption => 'Take a photo';
  @override
  String get choosePhotoOption => 'Choose from library';
  @override
  String get photoPickError => "Couldn't get that photo. Try again?";
  @override
  String get cropPhotoTitle => 'Adjust photo';
  @override
  String get cropPhotoConfirm => 'Done';
  @override
  String get cropPhotoHint => 'Pinch and drag to fit your photo into the frame';
  @override
  String get saveChanges => 'Save changes';
  @override
  String get lightThisStar => 'Light this star';
  @override
  String get placeThisStarAction => 'Put it in the sky';
  @override
  String get cannotSaveMissingInfo => "Can't save yet — some info is missing";
  @override
  String get gotIt => 'Got it';
  @override
  String get deleteStarConfirmTitle => 'Delete this star?';
  @override
  String get deleteStarConfirmBody =>
      "This turns the star into a dead one — it leaves here, but stays in its spot in the sky, and you can reignite it later.";
  @override
  String get deletePulsarConfirmTitle => 'Delete this pulsar?';
  @override
  String get deletePulsarConfirmBody =>
      'The pulsar becomes a dead star — it stops beating, but stays in its spot in the sky, and you can reignite it later as a pulsar again.';
  @override
  String get deleteStarAction => 'Delete';
  @override
  String get discardChangesConfirmTitle => 'Discard changes?';
  @override
  String get discardChangesConfirmBody =>
      "You'll lose the changes you made to this star.";
  @override
  String get discardChangesAction => 'Discard';

  @override
  String get targetDateLabel => 'Target date';
  @override
  String get selectATargetDateHint => 'Select a date';

  @override
  String goalTargetLabel(String date) => 'Goal for $date';
  @override
  String get markAchievedAction => 'Mark as achieved';
  @override
  String get markAchievedSheetTitle => 'How much did it take to get there?';
  @override
  String get markAchievedConfirm => 'Light this star';
  @override
  String get undoAchievedAction => 'Mark as not achieved';
  @override
  String get deadStarBody =>
      'This star was deleted. You can reignite it as a brand new star, in the same spot in the sky.';
  @override
  String get deadPulsarBody =>
      'This pulsar was deleted. You can reignite it as a brand new pulsar, in the same spot in the sky — its old streak stays behind.';
  @override
  String get reigniteAction => 'Reignite this star';

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
  String get markHabitDoneAction => 'Mark today as done';
  @override
  String get habitDoneTodayLabel => 'Done today';
  @override
  String get undoHabitTodayAction => 'Undo';
  @override
  String habitProgressToday(int done, int target) => '$done/$target today';
  @override
  String habitProgressThisWeek(int done, int target) =>
      '$done/$target this week';

  @override
  String unlitStarsBadge(int count) =>
      count == 1 ? '1 unlit star' : '$count unlit stars';
  @override
  String activePulsarsBadge(int count) =>
      count == 1 ? '1 active pulsar' : '$count active pulsars';

  @override
  String get starKindNascentName => 'Nascent star';
  @override
  String get starKindNascentPlural => 'Nascent stars';
  @override
  String get starKindNascentMeaning => 'Not configured yet';
  @override
  String get starKindNascentExample =>
      'A point on a brand new constellation — drawn, but not decided yet.';
  @override
  String get starKindLitName => 'Lit star';
  @override
  String get starKindLitPlural => 'Lit stars';
  @override
  String get starKindLitMeaning => 'Victory — done';
  @override
  String get starKindLitExample =>
      'I got through the interview even though I was terrified.';
  @override
  String get starKindUnlitName => 'Unlit star';
  @override
  String get starKindUnlitPlural => 'Unlit stars';
  @override
  String get starKindUnlitMeaning => 'Goal — to do';
  @override
  String get starKindUnlitExample => 'Run my first 10 km.';
  @override
  String get starKindPulsarName => 'Pulsar';
  @override
  String get starKindPulsarPlural => 'Pulsars';
  @override
  String get starKindPulsarMeaning => 'Habit — doing';
  @override
  String get starKindPulsarExample => 'Ten minutes of stretching, every day.';
  @override
  String get starKindDeadName => 'Dead star';
  @override
  String get starKindDeadPlural => 'Dead stars';
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
  String get allAreasLabel => 'All supernovas';
  @override
  String get admireAllAreasLabel => 'All';
  @override
  String get pickAtLeastOneArea => 'Pick at least one supernova to continue.';
  @override
  String get noStarsInSelection =>
      "No stars lit yet in the supernovas you picked.";
  @override
  String get viewYourStars => 'View your stars';

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
  String get nightlightExplainedBodyPart1 =>
      "When you're *agitated* or feeling low, the *mind* tends to "
      "*protect* itself by *rationalizing*: it will find *reasons* that "
      "sound logical to *play down every victory* you're about to see, "
      "*even the truest* ones.";
  @override
  String get nightlightExplainedBodyPart2 =>
      "Not because *they don't count*, but because in that state it's "
      'almost *impossible* to *look at them with clear eyes*.';
  @override
  String get nightlightExplainedBodyPart3 =>
      "That's why we *breathe* together first: it *helps* the *body*, "
      'and with it, the *mind* comes *out of that state*.';
  @override
  String get nightlightExplainedContinue => 'Continue';
  @override
  String get nightlightBreathingGetReady => 'Get ready';
  @override
  String get nightlightBreathingInhale => 'Breathe In';
  @override
  String get nightlightBreathingExhale => 'Breathe Out';
  @override
  String get nightlightBreathingSkip => "I'm ready";
  @override
  String nightlightBreathingCycleLabel(int current, int total) =>
      'Cycle $current of $total';
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
  String get starReaderTapForPhotoHint => 'Tap anywhere to see the photo';
  @override
  String get starReaderTapForDataHint => 'Tap anywhere to see the details';

  @override
  String get starQuickLookViewAction => 'View';
  @override
  String get starQuickLookEditAction => 'Edit';
  @override
  String get starQuickLookShareAction => 'Share';
  @override
  String get nascentStarQuickLookConfigureAction => 'Configure';
  @override
  String constellationTooltipLitCount(int lit, int total) =>
      '$lit/$total stars lit';
  @override
  String get creationSuccessEyebrow => 'Congrats!';
  @override
  String get creationSuccessLitMessage => 'A star is lit in your sky.';
  @override
  String get creationSuccessUnlitMessage =>
      'A new goal is set, waiting in your sky.';
  @override
  String get creationSuccessPulsarMessage =>
      'A new pulsar is alive, pulsing in your sky.';
  @override
  String get creationSuccessConstellationMessage =>
      'A new constellation is added to your sky.';
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
  String get downloadApkAction => 'Download the Android app';
  @override
  String get downloadApkPromptTitle => 'Want the real app?';
  @override
  String get downloadApkPromptContinueAction => 'Stay on the web';

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
