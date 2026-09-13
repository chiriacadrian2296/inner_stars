import 'app_strings.dart';

class StringsIt implements AppStrings {
  const StringsIt();

  @override
  String get languageCode => 'it';

  @override
  String get areaPhysical => 'Fisica';
  @override
  String get areaPsychological => 'Psicologica';
  @override
  String get areaProfessional => 'Professionale';
  @override
  String get areaFinancial => 'Finanziaria';
  @override
  String get areaPersonal => 'Personale';
  @override
  String get areaSocial => 'Sociale';
  @override
  String get areaSpiritual => 'Spirituale';
  @override
  String get areaPhilanthropic => 'Filantropica';
  @override
  String get areaPhysicalDescription =>
      'Il tuo corpo — movimento, forza e la salute che sostiene tutto il resto.';
  @override
  String get areaPsychologicalDescription =>
      'La tua mente — lucidità, resilienza ed equilibrio emotivo.';
  @override
  String get areaProfessionalDescription =>
      'Il tuo lavoro — carriera, competenze e ciò che stai costruendo.';
  @override
  String get areaFinancialDescription =>
      'Il tuo denaro — risparmio, guadagno e sicurezza a lungo termine.';
  @override
  String get areaPersonalDescription =>
      'La tua crescita — abitudini, disciplina e miglioramento personale.';
  @override
  String get areaSocialDescription =>
      'Le tue persone — amici, famiglia e connessioni vere.';
  @override
  String get areaSpiritualDescription =>
      'La tua vita interiore — significato, quiete e ciò in cui credi.';
  @override
  String get areaPhilanthropicDescription =>
      'Il tuo impatto — dare, servire e la vita degli altri.';

  @override
  List<String> get reflectionQuestionsPhysical => const [
    'Come ti senti nel tuo corpo in questo periodo?',
    'Cosa fai regolarmente per prenderti cura della tua salute?',
    "Qual è un'abitudine fisica che vorresti costruire, e cosa te lo impedisce?",
    'Quando ti senti più energico durante la giornata? Cosa lo provoca?',
  ];
  @override
  List<String> get reflectionQuestionsPsychological => const [
    'Cosa ti pesa di più mentalmente in questo momento?',
    'Come gestisci lo stress quando arriva?',
    'Quale pensiero ricorrente vorresti lasciar andare?',
    'Cosa ti fa sentire calmo e centrato?',
  ];
  @override
  List<String> get reflectionQuestionsProfessional => const [
    'Ti senti realizzato nel lavoro che fai? Perché?',
    'Qual è la prossima competenza che vuoi sviluppare?',
    'Cosa renderebbe il tuo lavoro più significativo?',
    'Dove ti vedi professionalmente tra un anno?',
  ];
  @override
  List<String> get reflectionQuestionsFinancial => const [
    'Che rapporto hai con il denaro?',
    'Cosa ti preoccupa di più riguardo alle tue finanze?',
    'Qual è un obiettivo finanziario concreto per i prossimi mesi?',
    'Cosa significherebbe per te la sicurezza economica?',
  ];
  @override
  List<String> get reflectionQuestionsPersonal => const [
    'Cosa stai imparando su te stesso ultimamente?',
    'Quale valore ti guida di più nelle scelte che fai?',
    'Cosa vorresti smettere di rimandare?',
    'Di cosa sei orgoglioso, anche se piccolo?',
  ];
  @override
  List<String> get reflectionQuestionsSocial => const [
    'Con chi vorresti passare più tempo?',
    'Come ti prendi cura delle tue relazioni più importanti?',
    "C'è una relazione che ha bisogno di attenzione in questo momento?",
    'Cosa cerchi davvero nelle persone che ti circondano?',
  ];
  @override
  List<String> get reflectionQuestionsSpiritual => const [
    'Cosa dà senso alle tue giornate?',
    'In quali momenti ti senti connesso a qualcosa di più grande di te?',
    'Come coltivi la pace interiore?',
    'Cosa significa per te vivere in modo autentico?',
  ];
  @override
  List<String> get reflectionQuestionsPhilanthropic => const [
    'In che modo contribuisci a qualcosa più grande di te?',
    'Chi hai aiutato di recente, e come ti ha fatto sentire?',
    'Quale causa ti sta a cuore, e perché?',
    'Cosa potresti dare — tempo, competenze, energie — che non stai ancora dando?',
  ];
  @override
  String get reflectionQuestionsSectionLabel => 'Domande di riflessione';
  @override
  String get reflectionQuestionsSubtitle =>
      'Rispondi quando qualcosa ti smuove davvero — puoi lasciarne alcune in bianco.';
  @override
  String get reflectionAnswerHint => 'Scrivi qui la tua risposta...';
  @override
  String get reflectionDifficultyLabel =>
      'Quanto è stato difficile trovare questa risposta?';
  @override
  String get reflectionAnsweredCountLabel => 'risposte';

  @override
  String get openMenuAction => 'Menu';
  @override
  String get menuButtonHoldHint => 'Tieni premuto per aprire';
  @override
  String get menuSearchSection => 'Cerca';
  @override
  String get menuActivitySection => 'Attività';
  @override
  String get menuLightYourSky => 'Accendi Il Tuo Cielo';
  @override
  String get menuLightAStar => 'Stelle';
  @override
  String get menuNewConstellation => 'Costellazioni';
  @override
  String get lightYourSkyChooserSupernovaOption => 'Supernove';
  @override
  String get menuShootingStars => 'Stelle Cadenti';
  @override
  String get menuDataSection => 'Dati';
  @override
  String get menuSearch => 'Cerca Stelle';
  @override
  String get menuStatistics => 'Statistiche';
  @override
  String get menuCrisisSection => 'Crisi';
  @override
  String get menuFindYourLight => 'Trova La Tua Luce';
  @override
  String get menuChallengesSection => 'Sfide';
  @override
  String get socialSection => 'Social';
  @override
  String get menuFriends => 'Amici';
  @override
  String get menuSettings => 'Impostazioni';
  @override
  String get menuInfoSection => 'Info';
  @override
  String get menuMetaphor => 'Metafora';
  @override
  String get menuOnboarding => 'Onboarding';

  @override
  String get menuLightYourSkyDescription =>
      'Arricchisci il tuo cielo con nuove fonti di luce.';
  @override
  String get menuShootingStarsDescription =>
      'Un desiderio a tempo — presto disponibile.';
  @override
  String get menuFindYourLightDescription =>
      "Per quando sei nel buio e hai bisogno di un po' di luce.";
  @override
  String get menuSearchDescription =>
      'Trova qualsiasi stella, costellazione o supernova.';
  @override
  String get menuStatisticsDescription =>
      'La stella di oggi, il tuo calendario e i tuoi numeri complessivi.';
  @override
  String get menuFriendsDescription =>
      'Costellazioni condivise e vittorie festeggiate insieme — presto disponibile.';
  @override
  String get menuMetaphorDescription =>
      'Cosa significa ogni parola del cielo.';
  @override
  String get menuSettingsDescription =>
      'Lingua, promemoria e tutto ciò che riguarda il tuo account.';

  @override
  String get comingSoonBadge => 'PRESTO DISPONIBILE';
  @override
  String get shootingStarsBody =>
      "Un desiderio che esprimi nell'istante in cui la vedi — da rincorrere "
      'prima che si spenga. Le stelle cadenti sono ancora in lavorazione: '
      'presto potrai darti una piccola sfida a tempo e coglierla nel cielo '
      'prima che la finestra si chiuda.';
  @override
  String get friendsBody =>
      'Costellazioni in comune, messaggi e festeggiare insieme le vittorie '
      "dell'altro — il lato social del cielo arriverà presto.";

  @override
  String get profileSection => 'Profilo & Account';
  @override
  String get profilePlaceholderBody =>
      'Accesso, la tua foto profilo, una breve descrizione di te e la tua '
      'lista amici troveranno posto qui.';
  @override
  String get customizationSection => 'Personalizzazione';
  @override
  String get customizationPlaceholderBody =>
      "Presto potrai scegliere tu font e stile grafico — per ora è l'app a "
      'sceglierli per te.';
  @override
  String get passkeySection => 'Passkey';
  @override
  String get passkeyPlaceholderBody =>
      "L'accesso senza password tramite passkey è in arrivo.";
  @override
  String get socialPlaceholderBody =>
      'Le impostazioni su come appari agli amici troveranno posto qui non '
      "appena il lato social dell'app esisterà.";

  @override
  String get statsEyebrow => 'I TUOI NUMERI';
  @override
  String get statsTitle => 'Statistiche';

  @override
  String get homeEyebrow => 'I TUOI PROGRESSI';
  @override
  String get homeTitle => 'La tua dashboard';
  @override
  String get homeSubtitle =>
      'Ogni stella è una vittoria, accesa quando ne avevi bisogno.';
  @override
  String get admireYourStars => 'Ammira le tue stelle';
  @override
  String get todayStarSectionLabel => 'Stella di oggi';
  @override
  String get litTodayTitle => 'Complimenti, hai acceso una stella oggi!';
  @override
  String get litTodayTitleHighlight => 'stella';
  @override
  String get litTodaySubtitle => '- hai portato nuova luce nella tua vita -';
  @override
  String get litTodaySubtitleHighlight => 'luce';
  @override
  String get notLitTodayLabel => 'Nessuna stella accesa oggi, per ora';
  @override
  String get notLitTodayHighlight => 'stella';
  @override
  String get lightStarCta => 'Accendine una';
  @override
  String get totalStarsLabel => 'Stelle totali';
  @override
  String get streaksSectionLabel => 'Serie';
  @override
  String get currentStreakLabel => 'Serie attuale';
  @override
  String get longestStreakLabel => 'Serie record';
  @override
  String get activityLabel => 'Attività';
  @override
  String get dayDetailEmpty => 'Nessuna stella accesa in questo giorno.';
  @override
  String get addStarForDayLabel => 'Aggiungi una stella per questo giorno';

  @override
  String get firstStarLabel => 'Prima stella';
  @override
  String get mostRecentStarLabel => 'Stella più recente';
  @override
  String get combinedIntensityLabel => 'Intensità complessiva';
  @override
  String get starsByAreaLabel => 'Per supernova';
  @override
  String get streakFromLabel => 'Da';
  @override
  String get streakToLabel => 'A';
  @override
  String get todayLabel => 'Oggi';
  @override
  String get starsLoggedLabel => 'Stelle registrate';
  @override
  @override
  String get noCurrentStreakBody =>
      'Nessuna serie in corso al momento. Accendi una stella oggi per iniziarne una.';

  @override
  String get searchHint => 'Cerca per titolo o descrizione';
  @override
  String get noSearchResults => 'Nessuna stella corrisponde alla ricerca.';
  @override
  String get skyEmptyConstellations => 'Ancora nessuna costellazione.';
  @override
  String get skyEmptyStars => 'Ancora nessuna stella.';
  @override
  String intensityCount(int value) => '$value intensità';
  @override
  String createdOnLabel(String date) => 'Creata il $date';
  @override
  String lastStarLabel(String date) => 'Ultima stella $date';
  @override
  String get constellationsModeLabel => 'Costellazioni';
  @override
  String get listModeLabel => 'Stelle';
  @override
  String get skyModeSupernovas => 'Supernove';
  @override
  String get filterAreasAction => 'Filtra aree';
  @override
  String get applyAreaFilterAction => 'Applica filtro';
  @override
  String get filterKindSectionTitle => 'Tipo di stella';
  @override
  String get allKindsLabel => 'Tutti i tipi';
  @override
  String get searchButtonLabel => 'Cerca';
  @override
  String get takeMeThereAction => 'Portami lì';
  @override
  String get searchScreenEyebrow => 'CERCA';
  @override
  String get areaVisionLabel => 'La tua visione per quest\'area';
  @override
  String get areaVisionHint =>
      'Che tipo di realtà vuoi per quest\'area? Verso cosa vuoi lavorare?';
  @override
  String get editVisionAction => 'Modifica visione';
  @override
  String get areaConstellationsStatLabel => 'Costellazioni';
  @override
  String get areaStarsStatLabel => 'Stelle';
  @override
  String get areaIntensityStatLabel => 'Intensità';

  @override
  String get dataSection => 'Strumenti di debug';
  @override
  String get seedSampleData => 'Genera dati di esempio';
  @override
  String seedSampleDataResult(int count) =>
      'Aggiunte $count stelle a ogni costellazione di esempio.';
  @override
  String get resetAllData => 'Azzera tutti i dati';
  @override
  String get resetAllDataConfirmTitle => 'Azzerare tutti i dati?';
  @override
  String get resetAllDataConfirmBody =>
      'Questa azione elimina definitivamente ogni stella e costellazione. Non può essere annullata.';
  @override
  String get cancel => 'Annulla';
  @override
  String get deleteEverything => 'Elimina tutto';
  @override
  String get allDataCleared => 'Tutti i dati sono stati eliminati.';
  @override
  String get archiveEmpty =>
      'Il tuo archivio è ancora vuoto. Accendi la tua prima stella, anche piccola.';

  @override
  String get soundLabEyebrow => 'AUDIO';
  @override
  String get soundLabTitle => 'Laboratorio audio';
  @override
  String get soundLabSubtitle =>
      'Traccia di sottofondo, suoni al tocco/pressione, e gli swoosh dello spostamento nel cielo — tutti gli esperimenti sonori vivono qui.';
  @override
  String get soundLabButtonTooltip => 'Laboratorio audio';
  @override
  String get soundLabResetAction => 'Ripristina predefiniti';
  @override
  String get backgroundTrackLabel => 'Traccia di sottofondo';
  @override
  String get pauseBackgroundTrackAction => 'Metti in pausa';
  @override
  String get playBackgroundTrackAction => 'Riproduci';
  @override
  String get tapSoundLabel => 'Suono al tocco';
  @override
  String get holdSoundLabel => 'Suono alla pressione prolungata';
  @override
  String get whooshInLabel => 'Swoosh in avvicinamento';
  @override
  String get whooshOutLabel => 'Swoosh in allontanamento';
  @override
  String get backgroundTrackObservingTheStar => 'Osservando la stella';
  @override
  String get backgroundTrackHeavenlyLoop => 'Deriva celeste';
  @override
  String get backgroundTrackOutThere => 'Là fuori';
  @override
  String get backgroundTrackAmbientRelaxing => 'Ambiente rilassante';
  @override
  String get backgroundTrackBackgroundSpace => 'Meditazione cosmica';
  @override
  String get skySoundPluckSoft => 'Pizzicato lieve';
  @override
  String get skySoundPluckBright => 'Pizzicato brillante';
  @override
  String get skySoundGlassLow => 'Cristallo grave';
  @override
  String get skySoundGlassHigh => 'Cristallo acuto';
  @override
  String get skySoundGlassChime => 'Campanello di cristallo';
  @override
  String get skySoundGlassBell => 'Campana di cristallo';
  @override
  String get skySoundGlassShine => 'Bagliore di cristallo';
  @override
  String get skySoundGlassTwinkle => 'Scintillio di cristallo';
  @override
  String get skySoundBong => 'Campana';
  @override
  String get skySoundConfirmation => 'Conferma';
  @override
  String get skySoundChimeSoft => 'Campanellino lieve';
  @override
  String get skySoundChimeWarm => 'Ding caldo';
  @override
  String get skySoundChimeBright => 'Ding brillante';
  @override
  String get skySoundSelect => 'Selezione';
  @override
  String get skySoundBlip => 'Blip';
  @override
  String get skySoundStarBlip => 'Blip stellare';
  @override
  String get skySoundShimmer => 'Scintillio';
  @override
  String get skySoundTick => 'Tic';
  @override
  String get skySoundToggle => 'Interruttore';
  @override
  String get skySoundClick => 'Click';
  @override
  String get skySoundCosmicDing => 'Ding cosmico';
  @override
  String get skySoundCosmicBlink => 'Blink cosmico';
  @override
  String get skySoundCosmicBeep => 'Beep cosmico';
  @override
  String get skyWhooshA => 'Swoosh leggero';
  @override
  String get skyWhooshB => 'Swoosh pesante';
  @override
  String get skyWhooshC => 'Swoosh rapido';
  @override
  String get skyWhooshD => 'Swoosh arioso';
  @override
  String get skyWhooshE => 'Swoosh veloce';
  @override
  String get skyWhooshF => 'Swoosh morbido';
  @override
  String get tourSkipAction => 'Salta';
  @override
  String get tourBackAction => 'Indietro';
  @override
  String get tourNextAction => 'Avanti';
  @override
  String get tourDoneAction => 'Fatto';
  @override
  String tourProgressLabel(int step, int length) => '$step di $length';
  @override
  String get skyTourLookAroundTitle => 'Guardati intorno';
  @override
  String get skyTourLookAroundBody =>
      'Trascina per muoverti, pizzica per zoomare, e tocca qualsiasi '
      'stella, costellazione o supernova per volare lì.';
  @override
  String get skyTourMenuTitle => 'Apri il menu';
  @override
  String get skyTourMenuBody =>
      'Tieni premuta questa stella per creare qualcosa di nuovo o '
      'orientarti.';
  @override
  String get skyTourSoundLabTitle => 'Laboratorio audio';
  @override
  String get skyTourSoundLabBody =>
      'Scegli qui i suoni e la musica del tuo cielo.';
  @override
  String get starTourKindTitle => 'Gli obiettivi sono stelle non ancora accese';
  @override
  String get starTourKindBody =>
      'Tocca qui per fissare un obiettivo — resta nel tuo cielo, spento, '
      'finché non lo raggiungi.';
  @override
  String get starTourTitleFieldTitle => 'Dai un nome al tuo obiettivo';
  @override
  String get starTourTitleFieldBody => 'Cosa vuoi raggiungere?';
  @override
  String get starTourDetailsFieldTitle => 'Aggiungi dettagli';
  @override
  String get starTourDetailsFieldBody =>
      'Racconta di più se ti aiuta — questa parte è facoltativa.';
  @override
  String get starTourDateFieldTitle => 'Quando è successo';
  @override
  String get starTourDateFieldBody =>
      'La data e l\'ora in cui questa vittoria è avvenuta davvero.';
  @override
  String get starTourTargetDateFieldTitle => 'Una data obiettivo';
  @override
  String get starTourTargetDateFieldBody =>
      'Facoltativo — entro quando vuoi raggiungerlo, se già lo sai.';
  @override
  String get starTourIntensityTitle => 'Quanto è costato';
  @override
  String get starTourIntensityBody =>
      "Valuta lo sforzo, da 1 a 5 — non quanto grande sembra il "
      'risultato, quanto ti è davvero costato.';
  @override
  String get starTourPhotoTitle => 'Aggiungi una foto';
  @override
  String get starTourPhotoBody =>
      "Facoltativo — un'immagine del momento, ritagliata per il tuo cielo.";
  @override
  String get starTourSaveTitle => 'Mettilo nel tuo cielo';
  @override
  String get starTourSaveBody =>
      'Quando sei pronto, salvalo — resterà lì, spento, finché non lo '
      'raggiungi.';
  @override
  String get searchTourModeTitle => 'Tre modi di guardare';
  @override
  String get searchTourModeBody =>
      'Passa tra Supernove, Costellazioni e Stelle.';
  @override
  String get searchTourFieldTitle => 'Cerca';
  @override
  String get searchTourFieldBody => 'Digita per filtrare per nome.';
  @override
  String get searchTourFilterButtonTitle => 'Filtra per area';
  @override
  String get searchTourFilterButtonBody =>
      'Restringi la vista solo alle aree che ti interessano ora.';
  @override
  String get searchTourAllAreasTitle => 'Tutte le aree';
  @override
  String get searchTourAllAreasBody =>
      'Disattivalo per creare invece una tua selezione.';
  @override
  String get searchTourAllKindsTitle => 'Filtra per tipo';
  @override
  String get searchTourAllKindsBody =>
      'Mostra solo stelle accese, obiettivi, pulsar o stelle spente.';
  @override
  String get searchTourApplyTitle => 'Applica';
  @override
  String get searchTourApplyBody => 'Salva il filtro e vedi i risultati.';
  @override
  String get lightYourSkyTourSupernovaTitle => 'Supernove';
  @override
  String get lightYourSkyTourSupernovaBody =>
      "Rivedi e modifica la visione di una delle tue aree di vita.";
  @override
  String get lightYourSkyTourConstellationTitle => 'Costellazioni';
  @override
  String get lightYourSkyTourConstellationBody =>
      'Avvia un nuovo progetto — una forma che le tue stelle riempiranno.';
  @override
  String get lightYourSkyTourStarTitle => 'Stelle';
  @override
  String get lightYourSkyTourStarBody =>
      'Registra uno sforzo: una vittoria, un obiettivo o una nuova abitudine.';
  @override
  String get constellationTourAreaTitle => "Scegli un'area";
  @override
  String get constellationTourAreaBody =>
      'Per quale parte della tua vita è questo progetto?';
  @override
  String get constellationTourNameTitle => 'Dagli un nome';
  @override
  String get constellationTourNameBody => 'Come si chiama questo progetto?';
  @override
  String get constellationTourDescriptionTitle => 'Aggiungi una descrizione';
  @override
  String get constellationTourDescriptionBody =>
      'Facoltativo — racconta di più su a cosa serve.';
  @override
  String get constellationTourShapeTitle => 'Dagli una forma';
  @override
  String get constellationTourShapeBody =>
      'Disegnane una tua, o scegline una dalla libreria — ogni progetto '
      'ha bisogno di una forma che le sue stelle riempiranno.';
  @override
  String get constellationTourSaveTitle => 'Crealo';
  @override
  String get constellationTourSaveBody => 'Salva la tua nuova costellazione.';
  @override
  String get supernovaTourListTitle => 'Le tue otto aree';
  @override
  String get supernovaTourListBody =>
      'Toccane una per vedere, e modificare, la visione che hai scritto.';
  @override
  String get supernovaTourEditTitle => 'Modifica la tua visione';
  @override
  String get supernovaTourEditBody =>
      'Scrivi qui la realtà che vuoi — puoi sempre tornare e rivederla.';
  @override
  String get replayToursAction => 'Rivedi i tutorial';
  @override
  String get replayToursResult =>
      'Tutorial azzerati — riapri ogni schermata per rivederli';
  @override
  String get volumeSectionLabel => 'Volume';
  @override
  String get backgroundVolumeLabel => 'Sottofondo';
  @override
  String get tapVolumeLabel => 'Tocco';
  @override
  String get holdVolumeLabel => 'Pressione prolungata';
  @override
  String get whooshVolumeLabel => 'Spostamento';

  @override
  String starsCount(int count) => count == 1 ? '1 stella' : '$count stelle';
  @override
  String areaEmptyProjects(String areaName) =>
      'Ancora nessuna costellazione in $areaName. Iniziane una per accendere le prime stelle qui.';
  @override
  String get noProjectsYet =>
      'Ancora nessuna costellazione. Iniziane una per accendere le prime stelle.';

  @override
  String get constellationShapeMissing =>
      'La forma di questa costellazione non è stata trovata.';

  @override
  String get drawYourOwnConstellation => 'Disegna La Tua Forma Di Stelle';
  @override
  String get constellationEditorTitle => 'Disegna La Tua Forma Di Stelle';
  @override
  String get constellationEditorEditTitle => 'Modifica La Tua Forma Di Stelle';
  @override
  String constellationEditorDisconnectedWarning(int count) =>
      '$count stell${count == 1 ? 'a scollegata' : 'e scollegate'}';
  @override
  String constellationEditorStarCount(int count, int max) =>
      'Usate $count/$max stelle';
  @override
  String get undoAction => 'Annulla';
  @override
  String get redoAction => 'Ripeti';
  @override
  String get deletePointAction => 'Elimina';
  @override
  String get saveConstellationAction => 'Salva';
  @override
  String get nameYourConstellationTitle => 'Dai Un Nome Alla Tua Forma Di Stelle';
  @override
  String get constellationNameHint => 'Es. Il mio percorso';
  @override
  String get constellationEditorGridToggleLabel => 'Griglia';
  @override
  String get constellationEditorMirrorToggleLabel => 'Specchio';
  @override
  String get constellationEditorMirrorAxisVerticalLabel => 'Verticale';
  @override
  String get constellationEditorMirrorAxisHorizontalLabel => 'Orizzontale';
  @override
  String get constellationEditorHelpAction => 'Come funziona';
  @override
  String get constellationEditorHelpTitle => 'Come funziona';
  @override
  String get constellationEditorHelpAddPoint =>
      'Tocca uno spazio vuoto per aggiungere una stella';
  @override
  String get constellationEditorHelpConnectPoint =>
      'Tocca una stella, poi toccane un\'altra per collegarle con un segmento';
  @override
  String get constellationEditorHelpDisarmPoint =>
      'Tocca di nuovo la stessa stella per deselezionarla senza collegare';
  @override
  String get constellationEditorHelpMovePoint =>
      'Premi e trascina una stella per spostarla';
  @override
  String get constellationEditorHelpDeletePoint =>
      'Seleziona una stella, poi tocca l\'icona elimina per rimuoverla';
  @override
  String get constellationEditorHelpMirrorToggle =>
      'Attiva la modalità specchio per aggiungere, spostare ed eliminare stelle su entrambi i lati contemporaneamente';
  @override
  String get constellationEditorHelpMirrorAxis =>
      'Cambia l\'asse per specchiare a sinistra/destra o in alto/basso';
  @override
  String get constellationEditorHelpDontShowAgain => 'Non mostrarlo più';
  @override
  String get constellationEditorHelpClose => 'Ho capito';
  @override
  String get chooseShapeLabel => 'Forma della costellazione';
  @override
  String get shapeLibraryTitle => 'Libreria Di Forme';
  @override
  String get pickFromLibraryShort => 'Forme';
  @override
  String get drawShapeShort => 'Disegna';
  @override
  String get resetShapeShort => 'Reset';
  @override
  String get shapeSearchHint => 'Cerca una forma';
  @override
  String get shapeLibraryTabLabel => 'Libreria';
  @override
  String get yourShapesTabLabel => 'Le tue forme';
  @override
  String get noCustomShapesYetHint => 'Non hai ancora disegnato nessuna forma';
  @override
  String get editSelectedShapeAction => 'Modifica questa forma';

  @override
  String get fieldLegendTitle => 'Info';
  @override
  String get requiredFieldLegend => 'Obbligatorio';
  @override
  String get optionalFieldLegend => 'Facoltativo';

  @override
  String get newProjectEyebrow => 'NUOVA COSTELLAZIONE';
  @override
  String get newProjectQuestion => 'Di che costellazione si tratta?';
  @override
  String get areaLabel => 'Supernova';
  @override
  String get nameLabel => 'Nome';
  @override
  String get newProjectNameHint => 'Es. Correre una maratona';
  @override
  String get projectDescriptionLabel => 'Descrizione';
  @override
  String get projectDescriptionHint =>
      'Es. Allenarmi tre volte a settimana fino ad arrivare a 42K';
  @override
  String get iconLabel => 'Icona';
  @override
  String get chooseIconTitle => 'Scegli Un\'Icona';
  @override
  String get pickerConfirmAction => 'OK';
  @override
  String get closeAction => 'Chiudi';
  @override
  String get createProject => 'Crea costellazione';
  @override
  String get newProject => 'Nuova costellazione';

  @override
  String get newStarEyebrow => 'NUOVA STELLA';
  @override
  String get editStarEyebrow => 'MODIFICA STELLA';
  @override
  String get configureStarEyebrow => 'CONFIGURA QUESTA STELLA';
  @override
  String get litStarQuestion => 'Cosa hai superato?';
  @override
  String get unlitStarQuestion => 'Cosa vuoi raggiungere?';
  @override
  String get pulsarQuestion =>
      'Cosa vuoi continuare a fare, giorno dopo giorno?';
  @override
  String get projectLabel => 'Costellazione';
  @override
  String get selectAProject => 'Seleziona una costellazione';
  @override
  String get selectASupernova => 'Seleziona una supernova';
  @override
  String get dateLabel => 'Data';
  @override
  String get selectADateHint => 'Seleziona una data';
  @override
  String get timeLabel => 'Ora';
  @override
  String get selectATimeHint => 'Seleziona un orario';
  @override
  String get titleFieldLabel => 'Titolo';
  @override
  String get litTitleHint => 'Es. Ho corso la mia prima 5K';
  @override
  String get unlitTitleHint => 'Es. Correre una 5K';
  @override
  String get pulsarTitleHint => 'Es. Andare a correre';
  @override
  String get litDetailsHint => 'Es. Le gambe mi facevano male, ma ce l\'ho fatta';
  @override
  String get unlitDetailsHint =>
      'Es. Iscriviti a una gara e allenati per affrontarla';
  @override
  String get pulsarDetailsHint => 'Es. Ogni mattina prima del lavoro';
  @override
  String get detailsLabel => 'Dettagli';
  @override
  String get intensityLabel => 'Intensità';
  @override
  String get photoLabel => 'Foto';
  @override
  String get addPhotoHint => 'Aggiungi una foto';
  @override
  String get takePhotoOption => 'Scatta una foto';
  @override
  String get choosePhotoOption => 'Scegli dalla libreria';
  @override
  String get photoPickError =>
      'Non è stato possibile ottenere la foto. Riprova?';
  @override
  String get cropPhotoTitle => 'Modifica la foto';
  @override
  String get cropPhotoConfirm => 'Fatto';
  @override
  String get cropPhotoHint =>
      'Pizzica e trascina per adattare la foto alla cornice';
  @override
  String get saveChanges => 'Salva modifiche';
  @override
  String get lightThisStar => 'Accendi questa stella';
  @override
  String get placeThisStarAction => 'Mettila nel cielo';
  @override
  String get cannotSaveMissingInfo =>
      'Impossibile salvare: mancano delle informazioni';
  @override
  String get gotIt => 'Ho capito';
  @override
  String get deleteStarConfirmTitle => 'Eliminare questa stella?';
  @override
  String get deleteStarConfirmBody =>
      'La stella diventerà una stella spenta: uscirà da qui, ma resterà al suo posto nel cielo e potrai riaccenderla in seguito.';
  @override
  String get deletePulsarConfirmTitle => 'Eliminare questo pulsar?';
  @override
  String get deletePulsarConfirmBody =>
      'Il pulsar diventerà una stella spenta: smette di pulsare, ma resta al suo posto nel cielo e potrai riaccenderlo come pulsar in seguito.';
  @override
  String get deleteStarAction => 'Elimina';
  @override
  String get discardChangesConfirmTitle => 'Scartare le modifiche?';
  @override
  String get discardChangesConfirmBody =>
      'Perderai le modifiche fatte a questa stella.';
  @override
  String get discardChangesAction => 'Scarta modifiche';

  @override
  String get targetDateLabel => 'Data obbiettivo';
  @override
  String get selectATargetDateHint => 'Seleziona una data';

  @override
  String goalTargetLabel(String date) => 'Obbiettivo per il $date';
  @override
  String get markAchievedAction => 'Segna come raggiunta';
  @override
  String get markAchievedSheetTitle => 'Quanto ti è costato raggiungerla?';
  @override
  String get markAchievedConfirm => 'Accendi questa stella';
  @override
  String get undoAchievedAction => 'Segna come non raggiunta';
  @override
  String get deadStarBody =>
      'Questa stella è stata cancellata. Puoi riaccenderla come una stella nuova, nello stesso punto del cielo.';
  @override
  String get deadPulsarBody =>
      'Questo pulsar è stato eliminato. Puoi riaccenderlo come un pulsar nuovo, nello stesso punto del cielo — la vecchia serie resta indietro.';
  @override
  String get reigniteAction => 'Riaccendi questa stella';

  @override
  String get habitFrequencyLabel => 'Frequenza';
  @override
  String get habitFrequencyDaily => 'Ogni giorno';
  @override
  String get habitFrequencyWeekly => 'Ogni settimana';
  @override
  String habitFrequencySummaryDaily(int times) =>
      times == 1 ? 'Una volta al giorno' : '$times volte al giorno';
  @override
  String habitFrequencySummaryWeekly(int times) => times == 1
      ? 'Una volta alla settimana'
      : '$times volte alla settimana, in $times giorni diversi';
  @override
  String get customReminderToggleLabel => 'Orario promemoria personalizzato';

  @override
  String get habitCurrentStreakLabel => 'Serie attuale';
  @override
  String get markHabitDoneAction => 'Segna oggi come fatto';
  @override
  String get habitDoneTodayLabel => 'Fatto oggi';
  @override
  String get undoHabitTodayAction => 'Annulla';
  @override
  String habitProgressToday(int done, int target) => '$done/$target oggi';
  @override
  String habitProgressThisWeek(int done, int target) =>
      '$done/$target questa settimana';

  @override
  String unlitStarsBadge(int count) => count == 1
      ? '1 stella non accesa'
      : '$count stelle non accese';
  @override
  String activePulsarsBadge(int count) =>
      count == 1 ? '1 pulsar attivo' : '$count pulsar attivi';

  @override
  String get starKindNascentName => 'Stella nascente';
  @override
  String get starKindNascentPlural => 'Stelle nascenti';
  @override
  String get starKindNascentMeaning => 'Non ancora configurata';
  @override
  String get starKindNascentExample =>
      'Un punto di una costellazione appena creata: disegnato, ma non ancora deciso.';
  @override
  String get starKindLitName => 'Stella accesa';
  @override
  String get starKindLitPlural => 'Stelle accese';
  @override
  String get starKindLitMeaning => 'Vittoria — fatta';
  @override
  String get starKindLitExample =>
      'Ho retto il colloquio anche se ero terrorizzato.';
  @override
  String get starKindUnlitName => 'Stella non accesa';
  @override
  String get starKindUnlitPlural => 'Stelle non accese';
  @override
  String get starKindUnlitMeaning => 'Obiettivo — da fare';
  @override
  String get starKindUnlitExample => 'Correre i miei primi 10 km.';
  @override
  String get starKindPulsarName => 'Pulsar';
  @override
  String get starKindPulsarPlural => 'Pulsar';
  @override
  String get starKindPulsarMeaning => 'Abitudine — in corso';
  @override
  String get starKindPulsarExample => 'Dieci minuti di stretching, ogni giorno.';
  @override
  String get starKindDeadName => 'Stella spenta';
  @override
  String get starKindDeadPlural => 'Stelle spente';
  @override
  String get starKindDeadMeaning => 'Eliminata — si può riaccendere';
  @override
  String get starKindDeadExample =>
      'Un obiettivo a cui hai rinunciato: è ancora lì, puoi riaccenderlo.';

  @override
  String get photoBadgeLabel => 'Foto';
  @override
  String get targetDateBadgeLabel => 'Obiettivo';
  @override
  String get deadDateBadgeLabel => 'Spenta';
  @override
  String get streakBadgeLabel => 'Serie';
  @override
  String get noPhotoLabel => 'Nessuna foto';
  @override
  String get noTargetDateLabel => 'Nessuna data obiettivo';
  @override
  String get noDeadDateLabel => 'Nessuna data';

  @override
  String get admireTagline =>
      'Per quando sei nel buio e hai bisogno di un po\' di luce.';
  @override
  String get allAreasLabel => 'Tutte le supernove';
  @override
  String get pickAtLeastOneArea =>
      'Scegli almeno una supernova per continuare.';
  @override
  String get noStarsInSelection =>
      'Nessuna stella ancora accesa nelle supernove scelte.';
  @override
  String get viewYourStars => 'Guarda le tue stelle';

  @override
  String get newConstellationOption => 'Nuova costellazione';

  @override
  String get visionsEyebrow => 'IL QUADRO PIÙ GRANDE';
  @override
  String get visionsTitle => 'Le Tue Visioni';
  @override
  String get visionsSubtitle =>
      'Una visione per ogni supernova — la realtà che vuoi in quell\'area '
      'della tua vita. Torna a rileggerle e riscrivile mentre cambi.';
  @override
  String get visionEmptyLabel => 'Nessuna visione scritta';

  @override
  String get guideEyebrow => 'COME FUNZIONA IL TUO CIELO';
  @override
  String get guideTitle => 'La Metafora';
  @override
  String get guideIntroBody =>
      'Qui dentro tutto è un unico cielo, letto a tre grandezze: le aree '
      'della tua vita bruciano come supernove, i progetti che orbitano '
      'attorno a esse sono costellazioni, e ogni sforzo che fai è una '
      'stella.';
  @override
  String get examplesLabel => 'Esempi';
  @override
  String get guideAreaTitle => 'Supernova';
  @override
  String get guideAreaMeaning => "Un'area della tua vita";
  @override
  String get guideAreaBody =>
      "La cosa più grande del tuo cielo, e l'unica fissa: 8 aree, sempre le "
      'stesse. Una supernova custodisce la tua visione — la realtà che '
      'vuoi in quella parte della vita. Tutto il resto si dispone attorno '
      'a quella a cui appartiene.';
  @override
  String get guideAreaExamples =>
      'Fisica · Professionale · Sociale — ognuna con la visione che scrivi '
      'per lei: «un corpo di cui mi fido, tutto l\'anno».';
  @override
  String get guideConstellationTitle => 'Costellazione';
  @override
  String get guideConstellationMeaning => 'Un progetto della tua vita';
  @override
  String get guideConstellationBody =>
      'Una forma che disegni tu, in orbita attorno a una supernova. '
      'Raccoglie tutti gli sforzi che riguardano la stessa cosa. La sua '
      'forma esiste dal primo '
      'giorno — le stelle lungo di essa nascono soltanto come stelle '
      'nascenti, in attesa di te.';
  @override
  String get guideConstellationExamples =>
      'Tornare in forma · Costruire questa app · Essere un amico migliore';
  @override
  String get guideStarTitle => 'Stella';
  @override
  String get guideStarMeaning => 'Uno sforzo — passato, presente o futuro';
  @override
  String get guideStarBody =>
      "La cosa più piccola del tuo cielo, e l'unica che fai tu. Una stella "
      'è sempre uno sforzo; il suo tipo dice dove quello sforzo si trova '
      'nel tempo e se in questo momento sta bruciando.';
  @override
  String get guideStarExamples =>
      'Mi sono allenato anche se non ne avevo voglia · Correre 10 km · '
      'Dieci minuti di stretching, ogni giorno';
  @override
  String get guideKindsTitle => 'I cinque tipi di stella';
  @override
  String get guideKindsBody =>
      "L'oro è luce: lo sforzo sta bruciando. Il blu è assenza di luce: in "
      'questo momento non stai dando nulla. Il bianco è uno spazio ancora '
      'tuo da riempire.';
  @override
  String get guideIntensityTitle => 'Intensità';
  @override
  String get guideIntensityBody =>
      "Ogni stella che brucia porta un'intensità, da 1 a 5 — quanto ti è "
      'costato davvero lo sforzo, non quanto sembra grande da fuori. Una '
      "stella accesa conserva l'intensità che le è servita; un pulsar "
      'porta quella che ti costa ogni giorno.';

  @override
  List<String> get upliftingQuotes => const [
    'Non devi vedere tutta la scala, basta il primo gradino.',
    'Anche i piccoli passi ti portano avanti.',
    'Hai superato ogni giorno difficile finora. Un record perfetto.',
    'Riposare non significa arrendersi.',
    'Puoi essere un lavoro in corso e meritare amore, allo stesso tempo.',
    'Questo sentimento è reale, ma non è per sempre.',
    'Non devi avere tutte le risposte per continuare ad andare avanti.',
    'Progresso, non perfezione.',
    "Certi giorni basta essere ancora qui. E conta.",
    'Hai superato il 100% dei tuoi giorni peggiori, finora.',
    'Sii paziente con te stesso. In natura nulla fiorisce tutto l\'anno.',
    'Va bene non stare bene — solo non restarci da solo.',
    'Un respiro alla volta. È tutto ciò che questo momento ti chiede.',
    'Sei più forte di quanto pensi e più amato di quanto sai.',
    'Anche la notte più buia finisce, e il sole sorge di nuovo.',
    "Guarire non è un percorso lineare, ed è normale.",
  ];

  @override
  String indexOfCount(int index, int total) => '$index di $total';
  @override
  String get shareStarLabel => 'Condividi questa Stella';
  @override
  String get shareStarError =>
      'Non è stato possibile condividere questa stella. Riprova?';

  @override
  String get starQuickLookViewAction => 'Visualizza';
  @override
  String get starQuickLookEditAction => 'Modifica';
  @override
  String get starQuickLookShareAction => 'Condividi';
  @override
  String constellationTooltipLitCount(int lit, int total) =>
      '$lit/$total stelle accese';
  @override
  String areaTooltipStarCount(int count) =>
      '$count stell${count == 1 ? 'a accesa' : 'e accese'}';

  @override
  String get settingsEyebrow => 'IMPOSTAZIONI';
  @override
  String get settingsTitle => 'Impostazioni';
  @override
  String get languageSection => 'Lingua';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageItalian => 'Italiano';
  @override
  String get languageRomanian => 'Română';
  @override
  String get reminderSection => 'Promemoria giornaliero';
  @override
  String get reminderToggleLabel => 'Ricordami di accendere una stella';
  @override
  String get reminderTimeLabel => 'Orario del promemoria';

  @override
  String get skyGridSection => 'Griglia del cielo';
  @override
  String get skyGridToggleLabel => 'Mostra la griglia di coordinate sul cielo';
  @override
  String get notificationPermissionDenied =>
      'Le notifiche sono disattivate per questa app nelle impostazioni del telefono.';
  @override
  String get testNotificationButton => 'Invia notifica di prova';
  @override
  String get reminderNotificationTitle => 'Accendi una stella';

  @override
  List<String> get reminderNotificationBodies => const [
    "Cosa ti ha aiutato a superare oggi, anche solo un po'?",
    'Anche il passo più piccolo accende una stella.',
    "Un attimo — cos'è andato bene oggi?",
    'Il tuo cielo aspetta la stella di stasera.',
    'Hai superato qualcosa oggi? Scrivilo.',
  ];
  @override
  String get aboutSection => 'Informazioni';
  @override
  String aboutVersion(String version) => 'Versione $version';
  @override
  String get aboutTagline =>
      'Un\'app di crescita personale per registrare i momenti che hai superato.';

  @override
  List<String> get monthAbbreviations => const [
    'Gen',
    'Feb',
    'Mar',
    'Apr',
    'Mag',
    'Giu',
    'Lug',
    'Ago',
    'Set',
    'Ott',
    'Nov',
    'Dic',
  ];

  @override
  List<String> get weekdayAbbreviations => const [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  @override
  String monthTitle(DateTime month) =>
      '${_fullMonths[month.month - 1]} ${month.year}';

  @override
  String get onboardingIntroTitle => 'Benvenuto nel tuo Cielo';
  @override
  String get onboardingIntroBody =>
      'Victory Stars trasforma le cose che realizzi nel tuo cielo notturno '
      'personale — un posto dove guardare indietro a tutto ciò che hai '
      'attraversato.';
  @override
  String get onboardingNascentTitle => 'Una costellazione nasce già intera';
  @override
  String get onboardingNascentBody =>
      'Appena la disegni, la sua forma è già lì: le linee, e una stella '
      'nascente su ogni punto. Toccane una per decidere cosa diventa.';
  @override
  String get onboardingLitTitle => 'Uno sforzo fatto è una stella accesa';
  @override
  String get onboardingLitBody =>
      'Nel momento in cui superi qualcosa che contava, accendi una '
      'stella. Resta lì — la prova di ciò che hai fatto, ogni volta che '
      'vuoi rivederla.';
  @override
  String get onboardingPulsarTitle => 'Le abitudini pulsano come pulsar';
  @override
  String get onboardingPulsarBody =>
      'Qualcosa che continui a fare giorno dopo giorno è un pulsar — oro '
      'finché mantieni il ritmo, blu nel momento in cui lo perdi.';
  @override
  String get onboardingUnlitTitle =>
      'Gli obiettivi sono stelle non ancora accese';
  @override
  String get onboardingUnlitBody =>
      'Fissa un obiettivo e ti aspetta nel cielo, spento. Raggiungilo e si '
      'accende come le altre stelle — oppure lascialo andare, e diventerà '
      'una stella spenta. In ogni caso, resta parte del tuo cielo.';
  @override
  String get onboardingConstellationsTitle => 'Raggruppale in costellazioni';
  @override
  String get onboardingConstellationsBody =>
      'Stelle e pulsar che riguardano la stessa cosa — un progetto, una '
      'relazione, qualsiasi cosa — appartengono a una costellazione che '
      'nomini tu.';
  @override
  String get onboardingAreasTitle => 'Le costellazioni orbitano le supernove';
  @override
  String get onboardingAreasBody =>
      'Ogni costellazione orbita attorno a una delle 8 supernove — le aree '
      'fisse della tua vita, dalla fisica alla sociale alla spirituale. '
      'Insieme, sono il tuo Cielo.';
  @override
  String get onboardingOutroTitle => 'Pronto ad accendere la tua prima stella?';
  @override
  String get onboardingOutroBody =>
      'Apri il menu del Cielo quando vuoi: da lì accendi una stella, '
      'disegni una costellazione o rileggi le tue visioni.';
  @override
  String get onboardingNextAction => 'Avanti';
  @override
  String get onboardingGetStartedAction => 'Inizia';
  @override
  String get onboardingSkipTooltip => 'Salta';
}

const _fullMonths = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];
