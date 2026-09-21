import 'app_strings.dart';

class StringsRo implements AppStrings {
  const StringsRo();

  @override
  String get languageCode => 'ro';

  @override
  String get areaPhysical => 'Fizică';
  @override
  String get areaPsychological => 'Psihologică';
  @override
  String get areaProfessional => 'Profesională';
  @override
  String get areaFinancial => 'Financiară';
  @override
  String get areaPersonal => 'Personală';
  @override
  String get areaSocial => 'Socială';
  @override
  String get areaSpiritual => 'Spirituală';
  @override
  String get areaPhilanthropic => 'Filantropică';
  @override
  String get areaPhysicalDescription =>
      'Corpul tău — mișcare, forță și sănătatea care susține totul.';
  @override
  String get areaPsychologicalDescription =>
      'Mintea ta — claritate, reziliență și echilibru emoțional.';
  @override
  String get areaProfessionalDescription =>
      'Munca ta — carieră, meșteșug și abilitățile pe care le construiești.';
  @override
  String get areaFinancialDescription =>
      'Banii tăi — economisire, câștig și siguranță pe termen lung.';
  @override
  String get areaPersonalDescription =>
      'Creșterea ta — obiceiuri, disciplină și dezvoltare personală.';
  @override
  String get areaSocialDescription =>
      'Oamenii tăi — prieteni, familie și conexiuni reale.';
  @override
  String get areaSpiritualDescription =>
      'Viața ta interioară — sens, liniște și ceea ce crezi.';
  @override
  String get areaPhilanthropicDescription =>
      'Impactul tău — a dărui, a sluji și viețile celorlalți.';

  @override
  List<String> get reflectionQuestionsPhysical => const [
    'Cum te simți în corpul tău în perioada asta?',
    'Ce faci în mod regulat pentru a avea grijă de sănătatea ta?',
    'Care este un obicei fizic pe care ai vrea să-l construiești, și ce te oprește?',
    'Când te simți cel mai energic în timpul zilei? Ce provoacă asta?',
  ];
  @override
  List<String> get reflectionQuestionsPsychological => const [
    'Ce te apasă cel mai mult din punct de vedere mental acum?',
    'Cum gestionezi stresul când apare?',
    'Ce gând recurent ai vrea să lași să plece?',
    'Ce te face să te simți calm și centrat?',
  ];
  @override
  List<String> get reflectionQuestionsProfessional => const [
    'Te simți împlinit în munca pe care o faci? De ce?',
    'Care este următoarea abilitate pe care vrei să o dezvolți?',
    'Ce ar face munca ta mai plină de sens?',
    'Unde te vezi profesional peste un an?',
  ];
  @override
  List<String> get reflectionQuestionsFinancial => const [
    'Ce relație ai cu banii?',
    'Ce te îngrijorează cel mai mult în privința finanțelor tale?',
    'Care este un obiectiv financiar concret pentru lunile următoare?',
    'Ce ar însemna pentru tine siguranța financiară?',
  ];
  @override
  List<String> get reflectionQuestionsPersonal => const [
    'Ce înveți despre tine în ultima vreme?',
    'Ce valoare te ghidează cel mai mult în alegerile tale?',
    'Ce ai vrea să nu mai amâni?',
    'De ce ești mândru, chiar dacă e ceva mic?',
  ];
  @override
  List<String> get reflectionQuestionsSocial => const [
    'Cu cine ai vrea să petreci mai mult timp?',
    'Cum ai grijă de relațiile tale cele mai importante?',
    'Există o relație care are nevoie de atenția ta acum?',
    'Ce cauți cu adevărat la oamenii din jurul tău?',
  ];
  @override
  List<String> get reflectionQuestionsSpiritual => const [
    'Ce dă sens zilelor tale?',
    'În ce momente te simți conectat la ceva mai mare decât tine?',
    'Cum cultivi pacea interioară?',
    'Ce înseamnă pentru tine să trăiești autentic?',
  ];
  @override
  List<String> get reflectionQuestionsPhilanthropic => const [
    'Cum contribui la ceva mai mare decât tine?',
    'Pe cine ai ajutat recent, și cum te-a făcut să te simți?',
    'Ce cauză îți este dragă, și de ce?',
    'Ce ai putea oferi — timp, abilități, energie — pe care nu-l oferi încă?',
  ];
  @override
  String get reflectionQuestionsSectionLabel => 'Întrebări de reflecție';
  @override
  String get reflectionQuestionsSubtitle =>
      'Răspunde când ceva te mișcă cu adevărat — poți lăsa unele necompletate.';
  @override
  String get reflectionAnswerHint => 'Scrie aici răspunsul tău...';
  @override
  String get reflectionDifficultyLabel =>
      'Cât de greu a fost să găsești acest răspuns?';
  @override
  String get reflectionAnsweredCountLabel => 'răspunsuri';

  @override
  String get openMenuAction => 'Meniu';
  @override
  String get menuButtonHoldHint => 'Ține apăsat pentru a deschide';
  @override
  String get menuSearchSection => 'Căutare';
  @override
  String get menuActivitySection => 'Activitate';
  @override
  String get menuLightYourSky => 'Aprinde-ți Cerul';
  @override
  String get menuLightAStar => 'Stele';
  @override
  String get menuNewConstellation => 'Constelații';
  @override
  String get lightYourSkyChooserSupernovaOption => 'Supernove';
  @override
  String get menuShootingStars => 'Stele Căzătoare';
  @override
  String get menuDataSection => 'Date';
  @override
  String get menuSearch => 'Caută Stele';
  @override
  String get menuStatistics => 'Statistici';
  @override
  String get menuNightlightSection => 'Nightlight';
  @override
  String get menuFindYourLight => 'Găsește-ți Lumina';
  @override
  String get menuChallengesSection => 'Provocări';
  @override
  String get socialSection => 'Social';
  @override
  String get menuFriends => 'Prieteni';
  @override
  String get menuSettings => 'Setări';
  @override
  String get menuInfoSection => 'Info';
  @override
  String get menuMetaphor => 'Metaforă';
  @override
  String get menuOnboarding => 'Onboarding';

  @override
  String get menuLightYourSkyDescription =>
      'Îmbogățește-ți cerul cu noi surse de lumină.';
  @override
  String get menuShootingStarsDescription =>
      'O dorință cu limită de timp — în curând.';
  @override
  String get menuFindYourLightDescription =>
      'Pentru când ești în întuneric și ai nevoie de puțină lumină.';
  @override
  String get menuSearchDescription =>
      'Găsește orice stea, constelație sau supernovă.';
  @override
  String get menuStatisticsDescription =>
      'Steaua de azi, calendarul tău și numerele tale de-a lungul timpului.';
  @override
  String get menuFriendsDescription =>
      'Constelații comune și victorii sărbătorite împreună — în curând.';
  @override
  String get menuMetaphorDescription => 'Ce înseamnă fiecare cuvânt din cer.';
  @override
  String get menuSettingsDescription =>
      'Limbă, mementouri și tot ce ține de contul tău.';

  @override
  String get comingSoonBadge => 'ÎN CURÂND';
  @override
  String get shootingStarsBody =>
      'O dorință pusă în clipa în care o zărești — de urmărit înainte să se '
      'stingă. Stelele căzătoare sunt încă în lucru: în curând vei putea să '
      'îți dai o mică provocare cu limită de timp și să o prinzi pe cer '
      'înainte să se închidă fereastra.';
  @override
  String get friendsBody =>
      'Constelații comune, mesaje și sărbătorirea împreună a victoriilor '
      'celuilalt — latura socială a cerului urmează să vină.';

  @override
  String get profileSection => 'Profil & Cont';
  @override
  String get profilePlaceholderBody =>
      'Autentificarea, poza ta de profil, o scurtă descriere despre tine și '
      'lista ta de prieteni vor avea loc aici.';
  @override
  String get customizationSection => 'Personalizare';
  @override
  String get customizationPlaceholderBody =>
      'În curând vei putea alege tu fonturile și stilul grafic — deocamdată '
      'aplicația le alege pentru tine.';
  @override
  String get passkeySection => 'Passkey';
  @override
  String get passkeyPlaceholderBody =>
      'Autentificarea fără parolă, cu o passkey, este pe drum.';
  @override
  String get socialPlaceholderBody =>
      'Setările despre cum apari prietenilor vor avea loc aici de îndată ce '
      'latura socială a aplicației va exista.';

  @override
  String get statsEyebrow => 'NUMERELE TALE';
  @override
  String get statsTitle => 'Statistici';

  @override
  String get homeEyebrow => 'PROGRESUL TĂU';
  @override
  String get homeTitle => 'Panoul tău';
  @override
  String get homeSubtitle =>
      'Fiecare stea e o victorie, aprinsă atunci când aveai nevoie de lumină.';
  @override
  String get todayStarSectionLabel => 'Steaua zilei';
  @override
  String get litTodayTitle => 'Felicitări, ai aprins o stea azi!';
  @override
  String get litTodayTitleHighlight => 'stea';
  @override
  String get litTodaySubtitle => '- ai adus lumină nouă în viața ta -';
  @override
  String get litTodaySubtitleHighlight => 'lumină';
  @override
  String get notLitTodayLabel => 'Nicio stea aprinsă azi încă';
  @override
  String get notLitTodayHighlight => 'stea';
  @override
  String get lightStarCta => 'Aprinde una';
  @override
  String get totalStarsLabel => 'Stele în total';
  @override
  String get streaksSectionLabel => 'Serii';
  @override
  String get currentStreakLabel => 'Serie curentă';
  @override
  String get longestStreakLabel => 'Cea mai lungă serie';
  @override
  String get activityLabel => 'Activitate';
  @override
  String get dayDetailEmpty => 'Nicio stea aprinsă în această zi.';
  @override
  String get addStarForDayLabel => 'Adaugă o stea pentru această zi';

  @override
  String get firstStarLabel => 'Prima stea';
  @override
  String get mostRecentStarLabel => 'Cea mai recentă stea';
  @override
  String get combinedIntensityLabel => 'Intensitate combinată';
  @override
  String get starsByAreaLabel => 'Pe supernove';
  @override
  String get streakFromLabel => 'De la';
  @override
  String get streakToLabel => 'Până la';
  @override
  String get todayLabel => 'Azi';
  @override
  String get starsLoggedLabel => 'Stele notate';
  @override
  @override
  String get noCurrentStreakBody =>
      'Nicio serie activă acum. Aprinde o stea azi ca să începi una.';

  @override
  String get searchHint => 'Caută după titlu sau descriere';
  @override
  String get noSearchResults => 'Nicio stea nu corespunde căutării.';
  @override
  String get noSearchResultsSupernovas =>
      'Nicio supernovă nu corespunde căutării.';
  @override
  String get noSearchResultsConstellations =>
      'Nicio constelație nu corespunde căutării.';
  @override
  String get noSearchResultsStars => 'Nicio stea nu corespunde căutării.';
  @override
  String get skyEmptyConstellations => 'Încă nicio constelație.';
  @override
  String get skyEmptyStars => 'Încă nicio stea.';
  @override
  String intensityCount(int value) => '$value intensitate';
  @override
  String createdOnLabel(String date) => 'Creată la $date';
  @override
  String lastStarLabel(String date) => 'Ultima stea $date';
  @override
  String get constellationsModeLabel => 'Constelații';
  @override
  String get listModeLabel => 'Stele';
  @override
  String get skyModeSupernovas => 'Supernove';
  @override
  String get filterAreasAction => 'Filtrează zonele';
  @override
  String get areaFilterDefaultLabel => 'Zone';
  @override
  String activeAreasCount(int count) => count == 1 ? '1 zonă' : '$count zone';
  @override
  String get filterKindAction => 'Filtrează tipurile';
  @override
  String get filterKindSectionTitle => 'Tipul stelei';
  @override
  String get allKindsLabel => 'Toate tipurile';
  @override
  String get kindFilterDefaultLabel => 'Tipuri de stele';
  @override
  String activeKindsCount(int count) =>
      count == 1 ? '1 tip de stea' : '$count tipuri de stele';
  @override
  String get applyFilterAction => 'Aplică filtrul';
  @override
  String get filterDateRangeAction => 'Filtrează după perioadă';
  @override
  String get dateRangeFilterSectionTitle => 'Perioadă';
  @override
  String get dateRangeUnitWeek => 'Săptămână';
  @override
  String get dateRangeUnitMonth => 'Lună';
  @override
  String get dateRangeUnitYear => 'An';
  @override
  String get dateRangeStepBackAction => 'Perioada anterioară';
  @override
  String get dateRangeStepForwardAction => 'Perioada următoare';
  @override
  String get dateRangeFromLabel => 'De la';
  @override
  String get dateRangeToLabel => 'Până la';
  @override
  String get clearFilterAction => 'Șterge';
  @override
  String get sortAction => 'Sortează rezultatele';
  @override
  String get sortButtonDefaultLabel => 'Sortează';
  @override
  String get sortSheetTitle => 'Sortează după';
  @override
  String get sortFieldDate => 'Dată';
  @override
  String get sortFieldIntensity => 'Intensitate';
  @override
  String get sortFieldName => 'Nume';
  @override
  String get sortDirectionAscending => 'Crescător';
  @override
  String get sortDirectionDescending => 'Descrescător';
  @override
  String get searchButtonLabel => 'Caută';
  @override
  String get takeMeThereAction => 'Du-mă acolo';
  @override
  String get searchScreenEyebrow => 'CAUTĂ';
  @override
  String get areaVisionLabel => 'Viziunea ta pentru această zonă';
  @override
  String get areaVisionHint =>
      'Ce fel de realitate îți dorești aici? Spre ce vrei să lucrezi?';
  @override
  String get editVisionAction => 'Editează viziunea';
  @override
  String get areaVisionPlaceholderPhysical =>
      'Ex. Mă mișc prin zilele mele cu energie și forță, dorm bine și am '
      'grijă de acest corp pe care îl am o singură dată. Sunt constant, nu '
      'doar atunci când am chef.';
  @override
  String get areaVisionPlaceholderPsychological =>
      'Ex. Mintea mea este limpede și stabilă. Știu cum să mă liniștesc și '
      'continui să aflu cine sunt. Când lucrurile devin grele, nu fug de ce '
      'simt.';
  @override
  String get areaVisionPlaceholderProfessional =>
      'Ex. Fac o muncă ce mă provoacă și contează, și cresc fără să mă '
      'pierd în ea. Vreau să privesc înapoi cu mândrie pentru drumul '
      'parcurs, nu doar pentru rezultat.';
  @override
  String get areaVisionPlaceholderFinancial =>
      'Ex. Construiesc o siguranță reală — economisesc cu intenție și '
      'cheltuiesc în acord cu ce contează cu adevărat pentru mine. Banii '
      'încetează să mai fie o grijă și devin ceva ce folosesc bine.';
  @override
  String get areaVisionPlaceholderPersonal =>
      'Ex. Continui să devin persoana care vreau să fiu, un obicei sincer '
      'pe rând. Prefer un progres lent și real unei scurtături false.';
  @override
  String get areaVisionPlaceholderSocial =>
      'Ex. Am în jurul meu oameni care mă cunosc cu adevărat, și le sunt '
      'alături și eu. Prefer câteva legături adevărate în locul multora '
      'superficiale.';
  @override
  String get areaVisionPlaceholderSpiritual =>
      'Ex. Simt o legătură cu ceva mai mare decât mine și fac loc '
      'liniștii. Nu am nevoie de un răspuns imediat la tot.';
  @override
  String get areaVisionPlaceholderPhilanthropic =>
      'Ex. Ofer ce pot — timp, abilități, atenție — vieților dincolo de a '
      'mea. Nu trebuie să fie mare ca să conteze.';
  @override
  String get areaCoverEnterAction => 'Gestionează Această Zonă';
  @override
  String get areaCoverVisionTitle => 'Viziune';
  @override
  String get areaConstellationsStatLabel => 'Constelații';
  @override
  String get areaStarsStatLabel => 'Stele';
  @override
  String get areaIntensityStatLabel => 'Intensitate';

  @override
  String get dataSection => 'Instrumente de depanare';
  @override
  String get seedSampleData => 'Generează date de exemplu';
  @override
  String seedSampleDataResult(int count) =>
      'S-au adăugat $count stele la fiecare constelație de exemplu.';
  @override
  String get resetAllData => 'Resetează toate datele';
  @override
  String get resetAllDataConfirmTitle => 'Resetezi toate datele?';
  @override
  String get resetAllDataConfirmBody =>
      'Această acțiune șterge definitiv fiecare stea și constelație. Nu poate fi anulată.';
  @override
  String get cancel => 'Anulează';
  @override
  String get deleteEverything => 'Șterge tot';
  @override
  String get allDataCleared => 'Toate datele au fost șterse.';
  @override
  String get archiveEmpty =>
      'Arhiva ta e încă goală. Aprinde prima ta stea, chiar și una mică.';

  @override
  String get soundLabEyebrow => 'AUDIO';
  @override
  String get soundLabTitle => 'Laborator audio';
  @override
  String get soundLabSubtitle =>
      'Piesa de fundal, sunetele de atingere/apăsare și swoosh-urile deplasării pe cer — toate experimentele sonore sunt aici.';
  @override
  String get soundLabButtonTooltip => 'Laborator audio';
  @override
  String get soundLabResetAction => 'Resetează la valorile implicite';
  @override
  String get backgroundTrackLabel => 'Piesă de fundal';
  @override
  String get pauseBackgroundTrackAction => 'Pune pe pauză';
  @override
  String get playBackgroundTrackAction => 'Redă';
  @override
  String get tapSoundLabel => 'Sunet la atingere';
  @override
  String get holdSoundLabel => 'Sunet la apăsare prelungită';
  @override
  String get whooshInLabel => 'Swoosh la apropiere';
  @override
  String get whooshOutLabel => 'Swoosh la depărtare';
  @override
  String get backgroundTrackObservingTheStar => 'Privind steaua';
  @override
  String get backgroundTrackHeavenlyLoop => 'Derivă celestă';
  @override
  String get backgroundTrackOutThere => 'Acolo, departe';
  @override
  String get backgroundTrackAmbientRelaxing => 'Ambient relaxant';
  @override
  String get backgroundTrackBackgroundSpace => 'Meditație cosmică';
  @override
  String get backgroundTrackNightlight => 'Nightlight';
  @override
  String get skySoundPluckSoft => 'Pizzicato blând';
  @override
  String get skySoundPluckBright => 'Pizzicato strălucitor';
  @override
  String get skySoundGlassLow => 'Cristal grav';
  @override
  String get skySoundGlassHigh => 'Cristal acut';
  @override
  String get skySoundGlassChime => 'Clopoțel de cristal';
  @override
  String get skySoundGlassBell => 'Clopot de cristal';
  @override
  String get skySoundGlassShine => 'Strălucire de cristal';
  @override
  String get skySoundGlassTwinkle => 'Sclipire de cristal';
  @override
  String get skySoundBong => 'Clopot';
  @override
  String get skySoundConfirmation => 'Confirmare';
  @override
  String get skySoundChimeSoft => 'Clopoțel blând';
  @override
  String get skySoundChimeWarm => 'Ding cald';
  @override
  String get skySoundChimeBright => 'Ding strălucitor';
  @override
  String get skySoundSelect => 'Selecție';
  @override
  String get skySoundBlip => 'Blip';
  @override
  String get skySoundStarBlip => 'Blip stelar';
  @override
  String get skySoundShimmer => 'Sclipire';
  @override
  String get skySoundTick => 'Tic';
  @override
  String get skySoundToggle => 'Comutator';
  @override
  String get skySoundClick => 'Click';
  @override
  String get skySoundCosmicDing => 'Ding cosmic';
  @override
  String get skySoundCosmicBlink => 'Blink cosmic';
  @override
  String get skySoundCosmicBeep => 'Beep cosmic';
  @override
  String get skyWhooshA => 'Swoosh ușor';
  @override
  String get skyWhooshB => 'Swoosh greu';
  @override
  String get skyWhooshC => 'Swoosh rapid';
  @override
  String get skyWhooshD => 'Swoosh aerisit';
  @override
  String get skyWhooshE => 'Swoosh iute';
  @override
  String get skyWhooshF => 'Swoosh moale';
  @override
  String get tourSkipAction => 'Omite';
  @override
  String get tourBackAction => 'Înapoi';
  @override
  String get tourNextAction => 'Următorul';
  @override
  String get tourDoneAction => 'Gata';
  @override
  String tourProgressLabel(int step, int length) => '$step din $length';
  @override
  String get skyTourWelcomeTitle => 'Bine ai venit pe cerul tău';
  @override
  String get skyTourWelcomeBody =>
      'Fiecare arie a vieții tale are propria supernovă, fiecare proiect '
      'propria constelație, fiecare victorie și obiectiv propria stea. '
      'Aici trăiește totul — hai să aruncăm o privire rapidă.';
  @override
  String get skyTourWelcomeStartAction => 'Începe';
  @override
  String get skyTourTapSupernovaTitle => 'Atinge o supernovă';
  @override
  String get skyTourTapSupernovaBody =>
      'Încearcă — atinge orice supernovă pentru a zbura acolo.';
  @override
  String get skyTourTapConstellationTitle => 'Atinge o constelație';
  @override
  String get skyTourTapConstellationBody =>
      'Acum atinge o constelație din interiorul ei pentru a te apropia '
      'și mai mult.';
  @override
  String get skyTourTapStarTitle => 'Atinge o stea';
  @override
  String get skyTourTapStarBody =>
      'Atinge orice stea pentru a zbura chiar lângă ea.';
  @override
  String get skyTourDoubleTapTitle => 'Atinge de două ori pentru a micșora';
  @override
  String get skyTourDoubleTapBody =>
      'Atinge de două ori orice punct gol de pe cer pentru a micșora '
      'înapoi.';
  @override
  String get skyTourHoldTitle => 'Ține apăsat pentru a privi';
  @override
  String get skyTourHoldBody =>
      'Ține apăsat pe o constelație pentru a o privi înainte de a decide '
      'dacă zbori acolo.';
  @override
  String get skyTourTooltipTitle => 'Fiecare tip arată altceva';
  @override
  String get skyTourTooltipBody =>
      'O supernova, o constelație, o stea — fiecare are propriul popup, '
      'cu informații și opțiuni diferite. Închide-l — cu X, atingând '
      'altundeva sau mutându-te — pentru a continua.';
  @override
  String get skyTourMenuTitle => 'Deschide meniul';
  @override
  String get skyTourMenuBody =>
      'Ține apăsată această stea pentru a crea ceva nou sau a te orienta.';
  @override
  String get skyTourMenuCloseTitle => 'Închiderea acestui meniu';
  @override
  String get skyTourMenuCloseBody =>
      'Trage-l în jos, atinge în afara lui sau folosește butonul înapoi — '
      'oricare dintre acestea îl închide.';
  @override
  String get skyTourMenuCloseTryAction => 'Încearcă';
  @override
  String get skyTourQuickMenuTapTitle => 'O cale mai rapidă';
  @override
  String get skyTourQuickMenuTapBody =>
      'O simplă atingere pe această stea — fără să o ții apăsată — '
      'deschide un meniu rapid în loc de cel complet.';
  @override
  String get skyTourQuickSettingsHintTitle => 'Setări rapide';
  @override
  String get skyTourQuickSettingsHintBody =>
      'Te duce direct la setările de sunet și afișaj.';
  @override
  String get skyTourSupernovasHintTitle => 'Supernove';
  @override
  String get skyTourSupernovasHintBody =>
      'Te duce la supernova oricărei arii de viață.';
  @override
  String get skyTourConstellationsHintTitle => 'Constelații';
  @override
  String get skyTourConstellationsHintBody =>
      'Începe o constelație nouă de la zero.';
  @override
  String get skyTourStarsHintTitle => 'Stele';
  @override
  String get skyTourStarsHintBody =>
      'Deschide formularul pentru a înregistra o victorie, un obiectiv '
      'sau un obicei.';
  @override
  String get skyTourSearchHintTitle => 'Caută Stele';
  @override
  String get skyTourSearchHintBody =>
      'Găsește orice supernovă, constelație sau stea după nume.';
  @override
  String get starTourIntroTitle => 'Înregistrarea unei victorii';
  @override
  String get starTourIntroBody =>
      'Acest formular acoperă toate cele trei tipuri de stele — o '
      'victorie deja obținută, un obiectiv spre care lucrezi, și un '
      'obicei pe care îl construiești. Iată o privire rapidă asupra '
      'fiecărui câmp.';
  @override
  String get starTourKindTitle => 'Obiectivele sunt stele încă neaprinse';
  @override
  String get starTourKindBody =>
      'Atinge aici pentru a stabili un obiectiv — te așteaptă pe cer, '
      'neaprins, până îl atingi.';
  @override
  String get starTourLegendTitle => 'Obligatoriu sau opțional';
  @override
  String get starTourLegendBody =>
      'Un punct plin înseamnă că un câmp e obligatoriu; unul conturat '
      'înseamnă opțional. Fiecare câmp de mai jos arată unul dintre ele.';
  @override
  String get starTourSupernovaFieldTitle => 'Ce zonă a vieții';
  @override
  String get starTourSupernovaFieldBody =>
      'Fiecare stea aparține uneia dintre cele opt supernove — alege-o pe '
      'cea potrivită.';
  @override
  String get starTourConstellationFieldTitle => 'Ce constelație';
  @override
  String get starTourConstellationFieldBody =>
      'Stelele se grupează în constelații — alege-o pe cea căreia îi '
      'aparține.';
  @override
  String get starTourTitleFieldTitle => 'Dă un nume obiectivului tău';
  @override
  String get starTourTitleFieldBody => 'Ce vrei să realizezi?';
  @override
  String get starTourDetailsFieldTitle => 'Adaugă detalii';
  @override
  String get starTourDetailsFieldBody =>
      'Spune mai mult dacă te ajută — această parte este opțională.';
  @override
  String get starTourDateFieldTitle => 'Când s-a întâmplat';
  @override
  String get starTourDateFieldBody =>
      'Data și ora la care această victorie s-a întâmplat cu adevărat.';
  @override
  String get starTourTargetDateFieldTitle => 'O dată țintă';
  @override
  String get starTourTargetDateFieldBody =>
      'Opțional — până când vrei să-l atingi, dacă știi deja.';
  @override
  String get starTourIntensityTitle => 'Cât te-a costat';
  @override
  String get starTourIntensityBody =>
      'Evaluează efortul, de la 1 la 5 — nu cât de mare pare rezultatul, '
      'ci cât te-a costat cu adevărat.';
  @override
  String get starTourHabitFrequencyTitle => 'Stabilește ritmul';
  @override
  String get starTourHabitFrequencyBody =>
      'Cât de des vrei să faci asta — zilnic sau săptămânal, și de câte '
      'ori.';
  @override
  String get starTourReminderTitle => 'Un memento';
  @override
  String get starTourReminderBody =>
      'Opțional — activează-l pentru un memento la ora pe care o alegi.';
  @override
  String get starTourPhotoTitle => 'Adaugă o fotografie';
  @override
  String get starTourPhotoBody =>
      'Opțional — o imagine a momentului, decupată pentru cerul tău.';
  @override
  String get starTourSaveTitle => 'Pune-l pe cerul tău';
  @override
  String get starTourSaveBody =>
      'Când ești gata, salvează-l — va aștepta acolo, neaprins, până îl '
      'atingi.';
  @override
  String get searchTourIntroTitle => 'Găsește orice pe cerul tău';
  @override
  String get searchTourIntroBody =>
      'Caută și filtrează supernovele, constelațiile și stelele tale de '
      'aici.';
  @override
  String get searchTourModeTitle => 'Trei moduri de a privi';
  @override
  String get searchTourModeBody =>
      'Comută între Supernove, Constelații și Stele.';
  @override
  String get searchTourFieldTitle => 'Caută';
  @override
  String get searchTourFieldBody => 'Scrie pentru a filtra după nume.';
  @override
  String get searchTourFilterButtonTitle => 'Filtrează după arie';
  @override
  String get searchTourFilterButtonBody =>
      'Restrânge la ariile care contează pentru tine acum.';
  @override
  String get searchTourAllAreasTitle => 'Toate ariile';
  @override
  String get searchTourAllAreasBody =>
      'Activează pentru a le include pe toate, sau selectează doar cele '
      'care contează pentru tine.';
  @override
  String get searchTourApplyTitle => 'Aplică';
  @override
  String get searchTourApplyBody => 'Salvează filtrul și vezi rezultatele.';
  @override
  String get lightYourSkyTourIntroTitle => 'Trei moduri de a-ți aprinde cerul';
  @override
  String get lightYourSkyTourIntroBody =>
      'Fiecare stea pornește de aici — alege-o pe cea care se potrivește '
      'cu ce vrei să înregistrezi.';
  @override
  String get lightYourSkyTourSupernovaTitle => 'Supernove';
  @override
  String get lightYourSkyTourSupernovaBody =>
      'Revizuiește și editează viziunea pentru una dintre ariile tale de viață.';
  @override
  String get lightYourSkyTourConstellationTitle => 'Constelații';
  @override
  String get lightYourSkyTourConstellationBody =>
      'Începe un proiect nou — o formă pe care stelele tale o vor umple.';
  @override
  String get lightYourSkyTourStarTitle => 'Stele';
  @override
  String get lightYourSkyTourStarBody =>
      'Înregistrează un efort: o victorie, un obiectiv sau un obicei nou.';
  @override
  String get constellationTourIntroTitle => 'Pornirea unui proiect nou';
  @override
  String get constellationTourIntroBody =>
      'O privire rapidă asupra fiecărui câmp înainte de a le completa.';
  @override
  String get constellationTourLegendTitle => 'Obligatoriu sau opțional';
  @override
  String get constellationTourLegendBody =>
      'Un punct plin înseamnă că un câmp e obligatoriu; unul conturat '
      'înseamnă opțional. Fiecare câmp de mai jos arată unul dintre ele.';
  @override
  String get constellationTourAreaTitle => 'Alege o arie';
  @override
  String get constellationTourAreaBody =>
      'Pentru ce parte din viața ta este acest proiect?';
  @override
  String get constellationTourIconFieldTitle => 'Alege o pictogramă';
  @override
  String get constellationTourIconFieldBody =>
      'Pictograma mică ce marchează această constelație în liste.';
  @override
  String get constellationTourNameTitle => 'Dă-i un nume';
  @override
  String get constellationTourNameBody => 'Cum se numește acest proiect?';
  @override
  String get constellationTourDescriptionTitle => 'Adaugă o descriere';
  @override
  String get constellationTourDescriptionBody =>
      'Opțional — spune mai multe despre rostul lui.';
  @override
  String get constellationTourCanvasTitle => 'Dă-i o formă';
  @override
  String get constellationTourCanvasBody =>
      'Fiecare proiect are nevoie de o formă pe care stelele lui o vor '
      'umple — aceasta e ce ai ales până acum. Atinge-o oricând pentru a '
      'o schimba.';
  @override
  String get constellationTourDrawButtonTitle => 'Desenează-ți propria formă';
  @override
  String get constellationTourDrawButtonBody =>
      'Desenează o formă personalizată de la zero.';
  @override
  String get constellationTourLibraryButtonTitle => 'Alege din bibliotecă';
  @override
  String get constellationTourLibraryButtonBody =>
      'Alege o formă deja gata în loc să desenezi una a ta.';
  @override
  String get constellationTourResetButtonTitle => 'Ia-o de la capăt';
  @override
  String get constellationTourResetButtonBody =>
      'Șterge forma aleasă până acum.';
  @override
  String get constellationTourSaveTitle => 'Creează-l';
  @override
  String get constellationTourSaveBody => 'Salvează noua ta constelație.';
  @override
  String get supernovaTourIntroTitle =>
      'Reflectând asupra ariilor tale de viață';
  @override
  String get supernovaTourIntroBody =>
      'Fiecare dintre cele opt arii ale tale își păstrează propriile '
      'reflecții — iată cum ajungi la ele.';
  @override
  String get supernovaTourListTitle => 'Cele opt arii ale tale';
  @override
  String get supernovaTourListBody =>
      'Atinge una pentru a vedea, și edita, viziunea pe care ai scris-o.';
  @override
  String get supernovaTourEditTitle => 'Editează-ți viziunea';
  @override
  String get supernovaTourEditBody =>
      'Scrie aici realitatea pe care ți-o dorești — te poți întoarce '
      'oricând să o revizuiești.';
  @override
  String get supernovaTourReflectionTitle => 'Întrebări de reflecție';
  @override
  String get supernovaTourReflectionBody =>
      'Câteva întrebări pentru această zonă — răspunde când simți nevoia.';
  @override
  String get replayToursAction => 'Repetă tutorialele';
  @override
  String get replayToursResult =>
      'Tutoriale resetate — redeschide fiecare ecran pentru a le revedea';
  @override
  String get tutorialsButtonTooltip => 'Tutoriale';
  @override
  String get tutorialsManagementTitle => 'Tutoriale';
  @override
  String get tutorialsEnabledLabel => 'Arată tutorialele';
  @override
  String get tutorialsEnabledDescription =>
      'Indiciile ghidate apar prima dată când deschizi un ecran care are unul.';
  @override
  String get quickSettingsButtonTooltip => 'Setări rapide';
  @override
  String get quickSettingsEyebrow => 'SETĂRI RAPIDE';
  @override
  String get quickSettingsTitle => 'Setări rapide';
  @override
  String get quickSettingsAudioSection => 'Audio';
  @override
  String get quickSettingsOpenSoundLabAction => 'Deschide Sound Lab';
  @override
  String get volumeSectionLabel => 'Volum';
  @override
  String get backgroundVolumeLabel => 'Fundal';
  @override
  String get tapVolumeLabel => 'Atingere';
  @override
  String get holdVolumeLabel => 'Apăsare prelungită';
  @override
  String get whooshVolumeLabel => 'Deplasare';

  @override
  String starsCount(int count) => count == 1 ? '1 stea' : '$count stele';
  @override
  String areaEmptyProjects(String areaName) =>
      'Încă nicio constelație în $areaName. Începe una pentru a aprinde primele stele aici.';
  @override
  String get noProjectsYet =>
      'Încă nicio constelație. Începe una pentru a aprinde primele stele.';

  @override
  String get constellationShapeMissing =>
      'Forma acestei constelații nu a fost găsită.';

  @override
  String get drawYourOwnConstellation => 'Desenează-ți Propria Formă De Stele';
  @override
  String get constellationEditorTitle => 'Desenează-ți Forma De Stele';
  @override
  String get constellationEditorEditTitle => 'Editează-ți Forma De Stele';
  @override
  String constellationEditorDisconnectedWarning(int count) =>
      '$count ${count == 1 ? 'stea neconectată' : 'stele neconectate'}';
  @override
  String constellationEditorStarCount(int count, int max) =>
      'Folosite $count/$max stele';
  @override
  String get undoAction => 'Anulează';
  @override
  String get redoAction => 'Refă';
  @override
  String get deletePointAction => 'Șterge';
  @override
  String get saveConstellationAction => 'Salvează';
  @override
  String get nameYourConstellationTitle => 'Dă Un Nume Formei Tale De Stele';
  @override
  String get constellationNameHint => 'Ex. Drumul meu';
  @override
  String get constellationEditorGridToggleLabel => 'Grilă';
  @override
  String get constellationEditorMirrorToggleLabel => 'Oglindă';
  @override
  String get constellationEditorMirrorAxisVerticalLabel => 'Verticală';
  @override
  String get constellationEditorMirrorAxisHorizontalLabel => 'Orizontală';
  @override
  String get constellationEditorHelpAction => 'Cum funcționează';
  @override
  String get constellationEditorHelpTitle => 'Cum funcționează';
  @override
  String get constellationEditorHelpAddPoint =>
      'Atinge un spațiu gol pentru a adăuga o stea';
  @override
  String get constellationEditorHelpConnectPoint =>
      'Atinge o stea, apoi atinge alta pentru a le conecta cu o linie';
  @override
  String get constellationEditorHelpDisarmPoint =>
      'Atinge din nou aceeași stea pentru a o deselecta fără a o conecta';
  @override
  String get constellationEditorHelpMovePoint =>
      'Apasă și trage o stea pentru a o muta';
  @override
  String get constellationEditorHelpDeletePoint =>
      'Selectează o stea, apoi atinge iconița de ștergere pentru a o elimina';
  @override
  String get constellationEditorHelpMirrorToggle =>
      'Activează modul oglindă pentru a adăuga, muta și șterge stele pe ambele părți simultan';
  @override
  String get constellationEditorHelpMirrorAxis =>
      'Schimbă axa pentru a oglindi stânga/dreapta sau sus/jos';
  @override
  String get constellationEditorHelpDontShowAgain => 'Nu mai arăta asta';
  @override
  String get constellationEditorHelpClose => 'Am înțeles';
  @override
  String get chooseShapeLabel => 'Forma constelației';
  @override
  String get shapeLibraryTitle => 'Bibliotecă De Forme';
  @override
  String get pickFromLibraryShort => 'Forme';
  @override
  String get drawShapeShort => 'Desenează';
  @override
  String get resetShapeShort => 'Reset';
  @override
  String get shapeSearchHint => 'Caută o formă';
  @override
  String get shapeLibraryTabLabel => 'Bibliotecă';
  @override
  String get yourShapesTabLabel => 'Formele tale';
  @override
  String get noCustomShapesYetHint => 'Nu ai desenat încă nicio formă';
  @override
  String get editSelectedShapeAction => 'Editează această formă';

  @override
  String get fieldLegendTitle => 'Info';
  @override
  String get requiredFieldLegend => 'Obligatoriu';
  @override
  String get optionalFieldLegend => 'Opțional';

  @override
  String get newProjectEyebrow => 'CONSTELAȚIE NOUĂ';
  @override
  String get newProjectQuestion => 'Despre ce constelație e vorba?';
  @override
  String get areaLabel => 'Supernovă';
  @override
  String get nameLabel => 'Nume';
  @override
  String get newProjectNameHint => 'Ex. Aleargă un maraton';
  @override
  String get projectDescriptionLabel => 'Descriere';
  @override
  String get projectDescriptionHint =>
      'Ex. Antrenează-te de trei ori pe săptămână până la 42K';
  @override
  String get iconLabel => 'Pictogramă';
  @override
  String get chooseIconTitle => 'Alege O Pictogramă';
  @override
  String get pickerConfirmAction => 'OK';
  @override
  String get closeAction => 'Închide';
  @override
  String get createProject => 'Creează constelație';
  @override
  String get newProject => 'Constelație nouă';

  @override
  String get newStarEyebrow => 'STEA NOUĂ';
  @override
  String get editStarEyebrow => 'EDITEAZĂ STEAUA';
  @override
  String get configureStarEyebrow => 'CONFIGUREAZĂ ACEASTĂ STEA';
  @override
  String get litStarQuestion => 'Ce ai reușit să depășești?';
  @override
  String get unlitStarQuestion => 'Ce vrei să atingi?';
  @override
  String get pulsarQuestion => 'Ce vrei să faci în continuare, zi de zi?';
  @override
  String get projectLabel => 'Constelație';
  @override
  String get selectAProject => 'Selectează o constelație';
  @override
  String get selectASupernova => 'Selectează o supernovă';
  @override
  String get dateLabel => 'Dată';
  @override
  String get selectADateHint => 'Selectează o dată';
  @override
  String get timeLabel => 'Ora';
  @override
  String get selectATimeHint => 'Selectează o oră';
  @override
  String get titleFieldLabel => 'Titlu';
  @override
  String get litTitleHint => 'Ex. Am alergat primul meu 5K';
  @override
  String get unlitTitleHint => 'Ex. Aleargă un 5K';
  @override
  String get pulsarTitleHint => 'Ex. Ieși la alergat';
  @override
  String get litDetailsHint => 'Ex. Mă dureau picioarele, dar am terminat';
  @override
  String get unlitDetailsHint =>
      'Ex. Înscrie-te la o cursă și antrenează-te pentru ea';
  @override
  String get pulsarDetailsHint => 'Ex. În fiecare dimineață înainte de muncă';
  @override
  String get detailsLabel => 'Detalii';
  @override
  String get intensityLabel => 'Intensitate';
  @override
  String get photoLabel => 'Fotografie';
  @override
  String get addPhotoHint => 'Adaugă o fotografie';
  @override
  String get takePhotoOption => 'Fă o fotografie';
  @override
  String get choosePhotoOption => 'Alege din galerie';
  @override
  String get photoPickError =>
      'Nu am putut obține fotografia. Încerci din nou?';
  @override
  String get cropPhotoTitle => 'Ajustează fotografia';
  @override
  String get cropPhotoConfirm => 'Gata';
  @override
  String get cropPhotoHint =>
      'Ciupește și trage pentru a încadra fotografia în cadru';
  @override
  String get saveChanges => 'Salvează modificările';
  @override
  String get lightThisStar => 'Aprinde această stea';
  @override
  String get placeThisStarAction => 'Pune-o pe cer';
  @override
  String get cannotSaveMissingInfo => 'Nu se poate salva: lipsesc informații';
  @override
  String get gotIt => 'Am înțeles';
  @override
  String get deleteStarConfirmTitle => 'Ștergi această stea?';
  @override
  String get deleteStarConfirmBody =>
      'Steaua va deveni o stea stinsă: dispare de aici, dar rămâne la locul ei pe cer și o poți reaprinde mai târziu.';
  @override
  String get deletePulsarConfirmTitle => 'Ștergi acest pulsar?';
  @override
  String get deletePulsarConfirmBody =>
      'Pulsarul devine o stea stinsă: nu mai pulsează, dar rămâne la locul lui pe cer și îl poți reaprinde mai târziu, tot ca pulsar.';
  @override
  String get deleteStarAction => 'Șterge';
  @override
  String get discardChangesConfirmTitle => 'Renunți la modificări?';
  @override
  String get discardChangesConfirmBody =>
      'Vei pierde modificările făcute acestei stele.';
  @override
  String get discardChangesAction => 'Renunță la modificări';

  @override
  String get targetDateLabel => 'Dată țintă';
  @override
  String get selectATargetDateHint => 'Selectează o dată';

  @override
  String goalTargetLabel(String date) => 'Obiectiv pentru $date';
  @override
  String get markAchievedAction => 'Marchează ca atins';
  @override
  String get markAchievedSheetTitle => 'Cât efort te-a costat să ajungi aici?';
  @override
  String get markAchievedConfirm => 'Aprinde această stea';
  @override
  String get undoAchievedAction => 'Marchează ca neatins';
  @override
  String get deadStarBody =>
      'Această stea a fost ștearsă. O poți reaprinde ca o stea complet nouă, în același loc pe cer.';
  @override
  String get deadPulsarBody =>
      'Acest pulsar a fost șters. Îl poți reaprinde ca un pulsar complet nou, în același loc pe cer — vechea serie rămâne în urmă.';
  @override
  String get reigniteAction => 'Reaprinde această stea';

  @override
  String get habitFrequencyLabel => 'Frecvență';
  @override
  String get habitFrequencyDaily => 'În fiecare zi';
  @override
  String get habitFrequencyWeekly => 'În fiecare săptămână';
  @override
  String habitFrequencySummaryDaily(int times) =>
      times == 1 ? 'O dată pe zi' : 'De $times ori pe zi';
  @override
  String habitFrequencySummaryWeekly(int times) => times == 1
      ? 'O dată pe săptămână'
      : 'De $times ori pe săptămână, în $times zile diferite';
  @override
  String get customReminderToggleLabel => 'Oră de memento personalizată';

  @override
  String get habitCurrentStreakLabel => 'Serie curentă';
  @override
  String get markHabitDoneAction => 'Marchează azi ca făcut';
  @override
  String get habitDoneTodayLabel => 'Făcut azi';
  @override
  String get undoHabitTodayAction => 'Anulează';
  @override
  String habitProgressToday(int done, int target) => '$done/$target azi';
  @override
  String habitProgressThisWeek(int done, int target) =>
      '$done/$target săptămâna aceasta';

  @override
  String unlitStarsBadge(int count) =>
      count == 1 ? '1 stea neaprinsă' : '$count stele neaprinse';
  @override
  String activePulsarsBadge(int count) =>
      count == 1 ? '1 pulsar activ' : '$count pulsari activi';

  @override
  String get starKindNascentName => 'Stea nouă';
  @override
  String get starKindNascentPlural => 'Stele noi';
  @override
  String get starKindNascentMeaning => 'Încă neconfigurată';
  @override
  String get starKindNascentExample =>
      'Un punct dintr-o constelație abia creată: desenat, dar încă nehotărât.';
  @override
  String get starKindLitName => 'Stea aprinsă';
  @override
  String get starKindLitPlural => 'Stele aprinse';
  @override
  String get starKindLitMeaning => 'Victorie — făcută';
  @override
  String get starKindLitExample =>
      'Am dus interviul până la capăt, deși eram îngrozit.';
  @override
  String get starKindUnlitName => 'Stea neaprinsă';
  @override
  String get starKindUnlitPlural => 'Stele neaprinse';
  @override
  String get starKindUnlitMeaning => 'Obiectiv — de făcut';
  @override
  String get starKindUnlitExample => 'Să alerg primii mei 10 km.';
  @override
  String get starKindPulsarName => 'Pulsar';
  @override
  String get starKindPulsarPlural => 'Pulsari';
  @override
  String get starKindPulsarMeaning => 'Obicei — în curs';
  @override
  String get starKindPulsarExample =>
      'Zece minute de stretching, în fiecare zi.';
  @override
  String get starKindDeadName => 'Stea stinsă';
  @override
  String get starKindDeadPlural => 'Stele stinse';
  @override
  String get starKindDeadMeaning => 'Ștearsă — poate fi reaprinsă';
  @override
  String get starKindDeadExample =>
      'Un obiectiv la care ai renunțat: e încă acolo, îl poți reaprinde.';

  @override
  String get photoBadgeLabel => 'Fotografie';
  @override
  String get targetDateBadgeLabel => 'Țintă';
  @override
  String get deadDateBadgeLabel => 'Stinsă';
  @override
  String get streakBadgeLabel => 'Serie';
  @override
  String get noPhotoLabel => 'Fără fotografie';
  @override
  String get noTargetDateLabel => 'Fără dată țintă';
  @override
  String get noDeadDateLabel => 'Fără dată';

  @override
  String get chooseSupernovasToInclude =>
      'Alege supernovele pe care vrei să le incluzi';
  @override
  String get allAreasLabel => 'Toate supernovele';
  @override
  String get admireAllAreasLabel => 'Toate';
  @override
  String get pickAtLeastOneArea =>
      'Alege cel puțin o supernovă pentru a continua.';
  @override
  String get noStarsInSelection =>
      'Nicio stea aprinsă încă în supernovele alese.';
  @override
  String get viewYourStars => 'Privește-ți stelele';

  @override
  String get nightlightGateQuestionPrefix => 'Înainte să începem, ești ';
  @override
  String get nightlightGateQuestionOkWord => 'bine';
  @override
  String get nightlightGateQuestionMiddle => ' sau în ';
  @override
  String get nightlightGateQuestionCrisisWord => 'criză';
  @override
  String get nightlightGateQuestionSuffix => '?';
  @override
  String get nightlightGateOkPrefix => 'Sunt ';
  @override
  String get nightlightGateOkWord => 'bine';
  @override
  String get nightlightGateCrisisPrefix => 'Sunt în ';
  @override
  String get nightlightGateCrisisWord => 'criză';
  @override
  String get nightlightExplainedTitle => 'Calm Down';
  @override
  String get nightlightExplainedSchemeAgitated => 'Agitat';
  @override
  String get nightlightExplainedSchemeBreathe => 'Respiră';
  @override
  String get nightlightExplainedSchemeClarity => 'Vezi Clar';
  @override
  String get nightlightExplainedBodyPart1 =>
      'Când ești *agitat* sau abătut, *mintea* tinde să se *protejeze* '
      '*raționalizând*: va găsi *motive* care par logice ca să '
      '*minimizeze fiecare victorie* pe care ți-o vom arăta, *chiar și '
      'pe cele mai adevărate*.';
  @override
  String get nightlightExplainedBodyPart2 =>
      'Nu pentru că *nu contează*, ci pentru că în starea aceea e '
      'aproape *imposibil* să *le privești cu ochi limpezi*.';
  @override
  String get nightlightExplainedBodyPart3 =>
      'De aceea *respirăm* mai întâi împreună: *ajută* *corpul*, și '
      'odată cu el *mintea*, să *iasă din starea aceea*.';
  @override
  String get nightlightExplainedContinue => 'Continuă';
  @override
  String get nightlightBreathingGetReady => 'Pregătește-te';
  @override
  String get nightlightBreathingInhale => 'Inspiră';
  @override
  String get nightlightBreathingExhale => 'Expiră';
  @override
  String get nightlightBreathingSkip => 'Sunt gata';
  @override
  String nightlightBreathingCycleLabel(int current, int total) =>
      'Ciclul $current din $total';
  @override
  String get nightlightBreathingCheckInTitle => 'Cum te simți acum?';
  @override
  String get nightlightBreathingCheckInBody =>
      'Sper că te simți mai bine acum. Dacă încă nu ești bine, poți '
      'reface exercițiul. Dacă te simți bine, poți continua.';
  @override
  String get nightlightBreathingCheckInRedo => 'Reia';
  @override
  String get nightlightBreathingCheckInProceed => 'Continuă';

  @override
  String get newConstellationOption => 'Constelație nouă';

  @override
  String get visionsEyebrow => 'IMAGINEA CEA MAI MARE';
  @override
  String get visionsTitle => 'Viziunile Tale';
  @override
  String get visionsSubtitle =>
      'O viziune pentru fiecare supernovă — realitatea pe care o vrei în '
      'zona aceea a vieții tale. Revino să le citești și rescrie-le pe '
      'măsură ce te schimbi.';
  @override
  String get visionEmptyLabel => 'Nicio viziune scrisă încă';

  @override
  String get guideEyebrow => 'CUM FUNCȚIONEAZĂ CERUL TĂU';
  @override
  String get guideTitle => 'Metafora';
  @override
  String get guideIntroBody =>
      'Totul aici e un singur cer, citit la trei mărimi: zonele vieții '
      'tale ard ca supernove, proiectele care orbitează în jurul lor sunt '
      'constelații, iar fiecare efort pe care îl faci e o stea.';
  @override
  String get examplesLabel => 'Exemple';
  @override
  String get guideAreaTitle => 'Supernovă';
  @override
  String get guideAreaMeaning => 'O zonă a vieții tale';
  @override
  String get guideAreaBody =>
      'Cel mai mare lucru de pe cerul tău și singurul fix: 8 zone, mereu '
      'aceleași. O supernovă păstrează viziunea ta — realitatea pe care o '
      'vrei în partea aceea a vieții. Tot restul se așază în jurul celei '
      'de care aparține.';
  @override
  String get guideAreaExamples =>
      'Fizic · Profesional · Social — fiecare cu viziunea pe care i-o '
      'scrii: „un corp în care am încredere, tot anul".';
  @override
  String get guideConstellationTitle => 'Constelație';
  @override
  String get guideConstellationMeaning => 'Un proiect din viața ta';
  @override
  String get guideConstellationBody =>
      'O formă pe care o desenezi tu, ce orbitează în jurul unei supernove. '
      'Adună toate '
      'eforturile despre același lucru. Forma ei există din prima zi — '
      'stelele de pe ea pornesc pur și simplu ca stele noi, așteptându-te.';
  @override
  String get guideConstellationExamples =>
      'Revin în formă · Construiesc această aplicație · Sunt un prieten mai bun';
  @override
  String get guideStarTitle => 'Stea';
  @override
  String get guideStarMeaning => 'Un efort — trecut, prezent sau viitor';
  @override
  String get guideStarBody =>
      'Cel mai mic lucru de pe cerul tău și singurul pe care îl faci tu. O '
      'stea e mereu un efort; tipul ei spune unde stă acel efort în timp '
      'și dacă arde chiar acum.';
  @override
  String get guideStarExamples =>
      'M-am antrenat deși nu aveam chef · Să alerg 10 km · Zece minute de '
      'stretching, în fiecare zi';
  @override
  String get guideKindsTitle => 'Cele cinci tipuri de stea';
  @override
  String get guideKindsBody =>
      'Auriul înseamnă lumină: efortul arde. Albastrul înseamnă lipsă de '
      'lumină: acum nu dai nimic. Albul înseamnă un loc care e încă al tău '
      'de umplut.';
  @override
  String get guideIntensityTitle => 'Intensitate';
  @override
  String get guideIntensityBody =>
      'Fiecare stea care arde poartă o intensitate, de la 1 la 5 — cât '
      'te-a costat efortul cu adevărat, nu cât de mare pare rezultatul din '
      'afară. O stea aprinsă păstrează intensitatea care i-a trebuit; un '
      'pulsar o poartă pe cea care te costă în fiecare zi.';

  @override
  List<String> get upliftingQuotes => const [
    'Nu trebuie să vezi toată scara, doar primul pas.',
    'Și pașii mici te duc mai departe.',
    'Ai trecut prin fiecare zi grea de până acum. Un record perfect.',
    'Odihna nu înseamnă renunțare.',
    'Poți fi în același timp o lucrare în desfășurare și demn de iubire.',
    'Acest sentiment e real, dar nu e permanent.',
    'Nu trebuie să ai totul clar ca să mergi mai departe.',
    'Progres, nu perfecțiune.',
    'Unele zile, e suficient să fii încă aici. Și contează.',
    'Ai trecut prin 100% din cele mai grele zile ale tale, până acum.',
    'Fii răbdător cu tine. Nimic în natură nu înflorește tot anul.',
    'E în regulă să nu fii bine — doar nu rămâne acolo singur.',
    'O respirație pe rând. Atât îți cere acest moment.',
    'Ești mai puternic decât crezi și mai iubit decât știi.',
    'Chiar și cea mai întunecată noapte se termină, iar soarele răsare din nou.',
    'Vindecarea nu e liniară, și e în regulă așa.',
  ];

  @override
  String indexOfCount(int index, int total) => '$index din $total';
  @override
  String get shareStarLabel => 'Distribuie această Stea';
  @override
  String get shareStarError =>
      'Nu am putut distribui această stea. Încerci din nou?';
  @override
  String get starReaderTapForPhotoHint =>
      'Atinge oriunde pentru a vedea fotografia';
  @override
  String get starReaderTapForDataHint => 'Atinge oriunde pentru a vedea datele';

  @override
  String get starQuickLookViewAction => 'Vizualizează';
  @override
  String get starQuickLookEditAction => 'Editează';
  @override
  String get starQuickLookShareAction => 'Distribuie';
  @override
  String get nascentStarQuickLookConfigureAction => 'Configurează';
  @override
  String constellationTooltipLitCount(int lit, int total) =>
      '$lit/$total stele aprinse';
  @override
  String get creationSuccessEyebrow => 'Felicitări!';
  @override
  String get creationSuccessLitMessage => 'O stea s-a aprins pe cerul tău.';
  @override
  String get creationSuccessUnlitMessage =>
      'Un obiectiv nou e fixat, te așteaptă pe cer.';
  @override
  String get creationSuccessPulsarMessage =>
      'Un puls nou e viu, pulsează pe cerul tău.';
  @override
  String get creationSuccessConstellationMessage =>
      'O constelație nouă a fost adăugată pe cerul tău.';
  @override
  String areaTooltipStarCount(int count) =>
      '$count ${count == 1 ? 'stea aprinsă' : 'stele aprinse'}';

  @override
  String get settingsEyebrow => 'SETĂRI';
  @override
  String get settingsTitle => 'Setări';
  @override
  String get languageSection => 'Limbă';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageItalian => 'Italiano';
  @override
  String get languageRomanian => 'Română';
  @override
  String get reminderSection => 'Memento zilnic';
  @override
  String get reminderToggleLabel => 'Amintește-mi să aprind o stea';
  @override
  String get reminderTimeLabel => 'Ora mementoului';

  @override
  String get skyGridSection => 'Grila cerului';
  @override
  String get skyGridToggleLabel => 'Arată grila de coordonate pe cer';
  @override
  String get notificationPermissionDenied =>
      'Notificările sunt dezactivate pentru această aplicație în setările telefonului.';
  @override
  String get testNotificationButton => 'Trimite o notificare de test';
  @override
  String get reminderNotificationTitle => 'Aprinde o stea';

  @override
  List<String> get reminderNotificationBodies => const [
    'Ce te-a ajutat să treci peste ziua de azi, chiar și puțin?',
    'Și cel mai mic pas aprinde o stea.',
    'Un moment — ce a mers bine azi?',
    'Cerul tău așteaptă steaua din seara asta.',
    'Ai trecut peste ceva azi? Notează-l.',
  ];
  @override
  String get aboutSection => 'Despre';
  @override
  String aboutVersion(String version) => 'Versiunea $version';
  @override
  String get aboutTagline =>
      'O aplicație de dezvoltare personală pentru a nota momentele pe care le-ai depășit.';
  @override
  String get downloadApkBannerBody =>
      'Folosești versiunea web. Pentru aplicația Android adevărată, cu '
      'notificări și tot restul, descarcă fișierul APK.';
  @override
  String get downloadApkAction => 'Descarcă aplicația pentru Android';
  @override
  String get downloadApkPromptTitle => 'Vrei aplicația adevărată?';
  @override
  String get downloadApkPromptContinueAction => 'Rămâi pe web';

  @override
  List<String> get monthAbbreviations => const [
    'Ian',
    'Feb',
    'Mar',
    'Apr',
    'Mai',
    'Iun',
    'Iul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  List<String> get weekdayAbbreviations => const [
    'Lun',
    'Mar',
    'Mie',
    'Joi',
    'Vin',
    'Sâm',
    'Dum',
  ];

  @override
  String monthTitle(DateTime month) =>
      '${_fullMonths[month.month - 1]} ${month.year}';

  @override
  String get onboardingIntroTitle => 'Bine ai venit pe cerul tău';
  @override
  String get onboardingIntroBody =>
      'Inner Stars transformă lucrurile pe care le realizezi în propriul '
      'tău cer nocturn — un loc unde să privești înapoi la tot ce ai '
      'trecut.';
  @override
  String get onboardingNascentTitle => 'O constelație se naște întreagă';
  @override
  String get onboardingNascentBody =>
      'Cum o desenezi, forma ei e deja acolo: liniile, și o stea nouă în '
      'fiecare punct. Atinge una ca să hotărăști ce devine.';
  @override
  String get onboardingLitTitle => 'Un efort făcut e o stea aprinsă';
  @override
  String get onboardingLitBody =>
      'În momentul în care treci peste ceva important, aprinzi o stea. '
      'Rămâne acolo — dovada a ceea ce ai făcut, oricând vrei să o '
      'revezi.';
  @override
  String get onboardingPulsarTitle => 'Obiceiurile pulsează ca niște pulsari';
  @override
  String get onboardingPulsarBody =>
      'Ceva ce faci zi de zi e un pulsar — auriu atât timp cât păstrezi '
      'ritmul, albastru în clipa în care îl pierzi.';
  @override
  String get onboardingUnlitTitle => 'Obiectivele sunt stele încă neaprinse';
  @override
  String get onboardingUnlitBody =>
      'Stabilește un obiectiv și te așteaptă pe cer, neaprins. Atinge-l și '
      'se aprinde ca orice altă stea — sau renunță, și devine o stea '
      'stinsă. Oricum, rămâne parte din cerul tău.';
  @override
  String get onboardingConstellationsTitle => 'Grupează-le în constelații';
  @override
  String get onboardingConstellationsBody =>
      'Stelele și pulsarii legați de același lucru — un proiect, o '
      'relație, orice — aparțin unei constelații pe care o numești tu.';
  @override
  String get onboardingAreasTitle => 'Constelațiile orbitează supernovele';
  @override
  String get onboardingAreasBody =>
      'Fiecare constelație orbitează în jurul uneia din cele 8 supernove — '
      'zonele '
      'fixe ale vieții tale, de la fizic la social la spiritual. Împreună, '
      'sunt Cerul tău.';
  @override
  String get onboardingOutroTitle => 'Gata să aprinzi prima ta stea?';
  @override
  String get onboardingOutroBody =>
      'Deschide oricând meniul Cerului: de acolo aprinzi o stea, desenezi '
      'o constelație sau îți recitești viziunile.';
  @override
  String get onboardingNextAction => 'Următorul';
  @override
  String get onboardingGetStartedAction => 'Începe';
  @override
  String get onboardingSkipTooltip => 'Sari peste';
}

const _fullMonths = [
  'Ianuarie',
  'Februarie',
  'Martie',
  'Aprilie',
  'Mai',
  'Iunie',
  'Iulie',
  'August',
  'Septembrie',
  'Octombrie',
  'Noiembrie',
  'Decembrie',
];
