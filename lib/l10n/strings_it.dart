import 'app_strings.dart';

class StringsIt implements AppStrings {
  @override
  String get visionUnderline => 'Sottolineato';
  @override
  String get visionDivider => 'Linea separatrice';

  @override
  String get moodboardTitle => 'Moodboard';
  @override
  String get moodboardPageDescription =>
      'Raccogli immagini, video e frasi che rendono visibile la vita che desideri in quest’area. Aggiungi ciò che ti ispira e torna qui per mantenere viva la direzione.';
  @override
  String get moodboardAddLabel => 'Add';
  @override
  String get moodboardEmpty =>
      'Raccogli foto, video e frasi che danno forma alla tua visione.';
  @override
  String get moodboardQuote => 'Frase';
  @override
  String get moodboardQuoteDescription =>
      'Scrivi una frase breve da aggiungere al moodboard.';
  @override
  String get moodboardQuoteTextLabel => 'Frase';
  @override
  String get moodboardQuoteAuthorLabel => 'Autore';
  @override
  String get moodboardQuoteAuthorHint => 'Opzionale';
  @override
  String get moodboardQuoteStyleLabel => 'Scegli uno stile';
  @override
  String get moodboardQuoteStyleCelestial => 'Celeste';
  @override
  String get moodboardQuoteStyleAurora => 'Aurora';
  @override
  String get moodboardQuoteStyleEditorial => 'Editoriale';
  @override
  String get moodboardQuoteStyleConstellation => 'Costellazione';
  @override
  String get moodboardQuoteStyleMinimal => 'Essenziale';
  @override
  String get moodboardVideo => 'Video';
  @override
  String get moodboardEdit => 'Modifica';
  @override
  String get moodboardRemove => 'Rimuovi';
  @override
  String get moodboardRemoveConfirm => 'Rimuovere questo elemento?';
  @override
  String get moodboardRemoveDescription =>
      'L’elemento verrà rimosso definitivamente dal moodboard.';
  @override
  String get moodboardSaveError =>
      'Impossibile salvare. Verifica lo spazio disponibile e riprova.';
  @override
  String get moodboardMediaError =>
      'Contenuto non disponibile o formato non supportato.';
  @override
  String get moodboardPlay => 'Riproduci';
  @override
  String get moodboardPause => 'Pausa';
  @override
  String get areaSectionOpen => 'Apri e modifica';
  @override
  String get areaReflectionsTitle => 'Riflessioni';

  @override
  String get carouselOneAtATime => 'Una alla volta';
  @override
  String get carouselFreeScroll => 'Scorrimento libero';
  @override
  String get visionUndo => 'Annulla modifica';
  @override
  String get viewAreaImageAction => 'Visualizza immagine';
  @override
  String get visionRedo => 'Ripristina modifica';
  @override
  String get visionWrite => 'Scrivi';
  @override
  String get visionPreview => 'Anteprima';
  @override
  String get visionHeading => 'Titolo';
  @override
  String get visionSection => 'Sezione';
  @override
  String get visionBold => 'Grassetto';
  @override
  String get visionItalic => 'Corsivo';
  @override
  String get visionBulletList => 'Elenco puntato';
  @override
  String get visionNumberedList => 'Elenco numerato';
  @override
  String get visionEditorHint =>
      'Dai spazio alla tua visione. Usa la barra per formattare il testo e una riga vuota per separare i paragrafi.';
  @override
  String get visionSaveError =>
      'Salvataggio non riuscito. Il testo è ancora qui: riprova.';
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
  String get reflectionQuestionsSectionLabel => 'Domande';
  @override
  String get reflectionQuestionsSubtitle =>
      'Rispondi quando qualcosa ti smuove davvero — puoi lasciarne alcune in bianco.';
  @override
  String get reflectionsPageDescription =>
      'Usa queste domande per fare chiarezza su quest’area della tua vita. Apri una domanda, scrivi ciò che emerge e indica quanto è stato difficile trovare la risposta.';
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
  String get menuSearchSection => 'Cielo';
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
  String get menuSearch => 'Cielo';
  @override
  String get menuStatistics => 'Statistiche';
  @override
  String get menuNightlightSection => 'Nightlight';
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
  String get skyViewModeTooltip => 'Vista';
  @override
  String get skyViewModeTitle => 'Vista';
  @override
  String get skyViewList => 'Lista';
  @override
  String get skyViewGrid => 'Griglia';
  @override
  String get skyViewCardSize => 'Dimensione Card';
  @override
  String get skyViewSizeCompact => 'Compatta';
  @override
  String get skyViewSizeMedium => 'Media';
  @override
  String get skyViewSizeLarge => 'Grande';
  @override
  String get skyViewSizeExtraLarge => 'Extra Grande';
  @override
  String get menuStatisticsDescription =>
      'La stella di oggi, il tuo calendario e i tuoi numeri complessivi.';
  @override
  String get menuFriendsDescription =>
      'Costellazioni condivise e vittorie festeggiate insieme — presto disponibile.';
  @override
  String get menuMetaphorDescription => 'Cosa significa ogni parola del cielo.';
  @override
  String get menuSettingsDescription =>
      'Lingua, promemoria e tutto ciò che riguarda il tuo account.';
  @override
  String get menuLabSection => 'Laboratorio';
  @override
  String get menuMoonLab => 'Moon Lab';
  @override
  String get menuMoonLabDescription =>
      "Sperimenta con l'aspetto e i livelli di Moon.";

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
  String get statsTitle => 'Statistiche';

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
  String get addStarForDayLabel => 'Aggiungi';

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
  String get noSearchResultsSupernovas =>
      'Nessuna supernova corrisponde alla ricerca.';
  @override
  String get noSearchResultsConstellations =>
      'Nessuna costellazione corrisponde alla ricerca.';
  @override
  String get noSearchResultsStars => 'Nessuna stella corrisponde alla ricerca.';
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
  String get filtersAction => 'Filtri';
  @override
  String get filterAreasAction => 'Filtra aree';
  @override
  String get areaFilterDefaultLabel => 'Aree';
  @override
  String activeAreasCount(int count) => count == 1 ? '1 area' : '$count aree';
  @override
  String resultsAreasWord(int count) => count == 1 ? 'area' : 'aree';
  @override
  String resultsConstellationsWord(int count) =>
      count == 1 ? 'costellazione' : 'costellazioni';
  @override
  String resultsStarsWord(int count) => count == 1 ? 'stella' : 'stelle';
  @override
  String get filterKindAction => 'Filtra tipi';
  @override
  String get filterKindSectionTitle => 'Tipo di stella';
  @override
  String get allKindsLabel => 'Tutto';
  @override
  String get kindFilterDefaultLabel => 'Tipi stella';
  @override
  String activeKindsCount(int count) =>
      count == 1 ? '1 tipo stella' : '$count tipi stella';
  @override
  String get applyFilterAction => 'Applica';
  @override
  String get filterDateRangeAction => 'Filtra per periodo';
  @override
  String get dateRangeFilterSectionTitle => 'Periodo';
  @override
  String get dateRangeUnitWeek => 'Settimana';
  @override
  String get dateRangeUnitMonth => 'Mese';
  @override
  String get dateRangeUnitYear => 'Anno';
  @override
  String get dateRangeStepBackAction => 'Periodo precedente';
  @override
  String get dateRangeStepForwardAction => 'Periodo successivo';
  @override
  String get dateRangeFromLabel => 'Da';
  @override
  String get dateRangeToLabel => 'A';
  @override
  String get clearFilterAction => 'Reset';
  @override
  String get clearSearchTooltip => 'Cancella ricerca';
  @override
  String get sortAction => 'Ordina risultati';
  @override
  String get sortButtonDefaultLabel => 'Ordina';
  @override
  String get sortSheetTitle => 'Ordina per';
  @override
  String get sortFieldDate => 'Data';
  @override
  String get sortFieldIntensity => 'Intensità';
  @override
  String get sortFieldName => 'Nome';
  @override
  String get sortDirectionAscending => 'Crescente';
  @override
  String get sortDirectionDescending => 'Decrescente';
  @override
  String get searchButtonLabel => 'Cerca';
  @override
  String get takeMeThereAction => 'Portami lì';
  @override
  String get creationSuccessOpenAction => 'Apri';
  @override
  String get creationSuccessFlyAction => 'Vola';
  @override
  String get searchCardMenuOpenAction => 'Apri menu della card';
  @override
  String get searchCardMenuCloseAction => 'Chiudi menu della card';
  @override
  String get searchCardOpenAction => 'Apri';
  @override
  String get actionFly => 'Vola';
  @override
  String get actionLight => 'Accendi';
  @override
  String get actionTurnOff => 'Spegni';
  @override
  String get actionReignite => 'Riaccendi';
  @override
  String get noDateShortLabel => 'Nessuna data';
  @override
  String get formerPulsarLabel => 'ex abitudine';
  @override
  String get searchScreenEyebrow => 'CERCA';
  @override
  String get areaVisionLabel => 'La tua visione per quest\'area';
  @override
  String get areaVisionHint =>
      'Che tipo di realtà vuoi per quest\'area? Verso cosa vuoi lavorare?';
  @override
  String get visionPageTitle => 'Vision';
  @override
  String get visionPageDescription =>
      'Definisci la realtà che desideri per quest’area della tua vita. Scrivi ciò verso cui vuoi muoverti e descrivilo con parole che possano guidare le tue scelte nel tempo.';
  @override
  String get editVisionAction => 'Modifica visione';
  @override
  String get areaVisionPlaceholderPhysical => '''
*Esempio di visione — da riscrivere con parole tue.*

# Abitare bene il mio corpo

Voglio sentirmi a casa nel mio corpo e avere energia per le cose che amo. Coltivo **forza, cura e riposo** con abitudini che posso mantenere anche nelle settimane difficili.

## Nella mia quotidianità

- Muovermi con piacere, rispettando i miei ritmi.
- Dare spazio al sonno e al recupero.
- Ascoltare i miei bisogni senza giudicarmi.

## Mi accorgo che sto crescendo quando…

Mi accorgo prima di quando ho bisogno di una pausa e vivo le mie giornate con più presenza.
''';
  @override
  String get areaVisionPlaceholderPsychological => '''
*Esempio di visione — da riscrivere con parole tue.*

# Essere dalla mia parte

Voglio conoscere meglio quello che provo e trattarmi con **rispetto e gentilezza**. Lascio spazio alle emozioni e imparo a scegliere come rispondere, anche quando non posso cambiare ciò che succede.

## Nella mia quotidianità

- Fermarmi per dare un nome a ciò che sento.
- Riconoscere i miei limiti e chiedere sostegno.
- Parlarmi come parlerei a una persona cara.

## Mi accorgo che sto crescendo quando…

Riesco a riprendermi dopo una giornata difficile senza trasformarla in un giudizio su di me.
''';
  @override
  String get areaVisionPlaceholderProfessional => '''
*Esempio di visione — da riscrivere con parole tue.*

# Un lavoro in cui riconoscermi

Voglio costruire un percorso che unisca **competenza, curiosità e utilità**. Mi dedico a progetti di cui comprendo il valore e lascio al lavoro un posto sostenibile nella mia vita.

## Nella mia quotidianità

- Approfondire le competenze che desidero usare.
- Cercare feedback e condividere ciò che imparo.
- Proteggere il tempo per la vita fuori dal lavoro.

## Mi accorgo che sto crescendo quando…

So raccontare cosa sto imparando e perché il mio contributo conta, oltre ai risultati raggiunti.
''';
  @override
  String get areaVisionPlaceholderFinancial => '''
*Esempio di visione — da riscrivere con parole tue.*

# Più serenità, più possibilità

Voglio avere un rapporto chiaro e consapevole con il denaro. Costruisco **sicurezza e libertà di scelta**, tenendo insieme i bisogni di oggi e ciò che desidero per il futuro.

## Nella mia quotidianità

- Conoscere le mie entrate e le mie spese.
- Dare priorità a ciò che per me ha valore.
- Mettere da parte risorse quando mi è possibile.

## Mi accorgo che sto crescendo quando…

Affronto le decisioni economiche con più chiarezza e meno evitamento.
''';
  @override
  String get areaVisionPlaceholderPersonal => '''
*Esempio di visione — da riscrivere con parole tue.*

# Una vita che mi somiglia

Voglio dare spazio a ciò che mi incuriosisce e diventare una persona di cui mi fido. Coltivo **creatività, autonomia e scoperta**, senza dover trasformare ogni interesse in una prestazione.

## Nella mia quotidianità

- Riservare tempo a un interesse solo per il piacere di farlo.
- Provare qualcosa di nuovo, accettando di essere principiante.
- Mantenere piccoli impegni presi con me.

## Mi accorgo che sto crescendo quando…

Nelle mie settimane riconosco scelte che sento davvero mie.
''';
  @override
  String get areaVisionPlaceholderSocial => '''
*Esempio di visione — da riscrivere con parole tue.*

# Relazioni in cui esserci davvero

Voglio costruire legami in cui poter essere me stesso e lasciare agli altri lo stesso spazio. Scelgo **ascolto, reciprocità e sincerità**, con il coraggio di esprimere anche bisogni e confini.

## Nella mia quotidianità

- Dedicare attenzione alle persone a cui tengo.
- Ascoltare senza preparare subito una risposta.
- Dire con chiarezza ciò che posso offrire e ciò di cui ho bisogno.

## Mi accorgo che sto crescendo quando…

Mi sento libero di chiedere vicinanza e di offrire presenza senza dimenticare me stesso.
''';
  @override
  String get areaVisionPlaceholderSpiritual => '''
*Esempio di visione — da riscrivere con parole tue.*

# Fare spazio a ciò che conta

Voglio sentirmi connesso alla vita e vivere in accordo con i miei valori. Cerco **significato, meraviglia e raccoglimento** nella forma che sento mia, lasciando aperte le domande.

## Nella mia quotidianità

- Ritagliare momenti di silenzio o contemplazione.
- Ritrovare contatto con la natura, una pratica o una comunità.
- Chiedermi se le mie scelte riflettono ciò in cui credo.

## Mi accorgo che sto crescendo quando…

Anche nei giorni ordinari trovo qualcosa che mi invita a fermarmi e a essere presente.
''';
  @override
  String get areaVisionPlaceholderPhilanthropic => '''
*Esempio di visione — da riscrivere con parole tue.*

# Lasciare qualcosa di buono

Voglio contribuire al benessere di persone e luoghi oltre la mia vita quotidiana. Offro **tempo, attenzione e competenze** in modo concreto e sostenibile, partendo dai bisogni di chi riceve.

## Nella mia quotidianità

- Ascoltare prima di decidere come aiutare.
- Scegliere una causa a cui dedicare continuità.
- Offrire ciò che posso, rispettando i miei limiti.

## Mi accorgo che sto crescendo quando…

Il mio contributo risponde a un bisogno reale e riesco a mantenerlo nel tempo.
''';
  @override
  String get areaCoverEnterAction => 'Gestisci';
  @override
  String get areaCoverVisionTitle => 'Visione';

  @override
  String get dataSection => 'Strumenti di debug';
  @override
  String get seedSampleData => 'Genera dati di esempio';
  @override
  String seedSampleDataResult(int count) =>
      'Aggiunte $count stelle alle costellazioni di esempio.';
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
  String get backgroundTrackNightlight => 'Nightlight';
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
  String get skyTourWelcomeTitle => 'Benvenuto nel tuo cielo';
  @override
  String get skyTourWelcomeBody =>
      'Ogni area della tua vita ha la sua supernova, ogni progetto la sua '
      'costellazione, ogni vittoria e obiettivo la sua stella. È qui che '
      'vive tutto — diamo un\'occhiata veloce in giro.';
  @override
  String get skyTourWelcomeStartAction => 'Inizia';
  @override
  String get skyTourTapConstellationTitle => 'Tocca per volare lì';
  @override
  String get skyTourTapConstellationBody =>
      'Tocca una supernova, una costellazione o una stella per volare fino a lei. Prova con questa costellazione.';
  @override
  String get skyTourDoubleTapTitle => 'Doppio tocco per rimpicciolire';
  @override
  String get skyTourDoubleTapBody =>
      'Tocca due volte un punto vuoto del cielo per tornare indietro con '
      'lo zoom.';
  @override
  String get skyTourHoldTitle => 'Tieni premuto per sbirciare';
  @override
  String get skyTourHoldBody =>
      'Tieni premuta una costellazione per sbirciarla prima di decidere '
      'se volarci sopra.';
  @override
  String get skyTourTooltipTitle => 'Info diverse per ogni elemento';
  @override
  String get skyTourTooltipBody =>
      'Supernova, costellazione e stella mostrano info e opzioni diverse '
      'nel loro popup. Chiudilo — con la X, toccando altrove o '
      'spostandoti — per continuare.';
  @override
  String get skyTourMenuTitle => 'Apri il menu';
  @override
  String get skyTourMenuBody =>
      'Tieni premuta questa stella per creare qualcosa di nuovo o '
      'orientarti.';
  @override
  String get skyTourMenuCloseTitle => 'Chiudere questo menu';
  @override
  String get skyTourMenuCloseBody =>
      'Trascinalo verso il basso, tocca fuori da esso, oppure usa il '
      'tasto indietro — funzionano tutti e tre.';
  @override
  String get skyTourMenuCloseTryAction => 'Prova';
  @override
  String get skyTourQuickMenuTapTitle => 'Un accesso più rapido';
  @override
  String get skyTourQuickMenuTapBody =>
      'Un semplice tocco su questa stella — senza tenerlo premuto — apre '
      'un menu rapido invece di quello completo.';
  @override
  String get skyTourNightlightHintTitle => 'Nightlight';
  @override
  String get skyTourNightlightHintBody =>
      'Un posto per ritrovare luce quando ne hai bisogno.';
  @override
  String get skyTourSkyHintTitle => 'Cielo';
  @override
  String get skyTourSkyHintBody =>
      'Trova e aggiungi supernove, costellazioni e stelle.';
  @override
  String get starTourKindTitle => 'Tre tipi di stelle';
  @override
  String get starTourKindBody =>
      'Scegli tra Vittoria (già fatta), Obiettivo (ancora da fare, una stella spenta) e Abitudine (un pulsar che ripeti). Ognuno chiede dettagli diversi.';
  @override
  String get starTourIntensityTitle => 'Quanto è costato';
  @override
  String get starTourIntensityBody =>
      "Valuta lo sforzo, da 1 a 5 — non quanto grande sembra il "
      'risultato, quanto ti è davvero costato.';
  @override
  String get searchTourModeTitle => 'Tre livelli';
  @override
  String get searchTourModeBody =>
      'Passa tra Supernove (le tue aree di vita), Costellazioni (i tuoi progetti) e Stelle (i singoli sforzi).';
  @override
  String get searchTourFilterButtonTitle => 'Vista, filtri e ordine';
  @override
  String get searchTourFilterButtonBody =>
      'Passa da griglia a elenco, restringi per area, tipo o data e cambia l\'ordine.';
  @override
  String get lightYourSkyTourIntroTitle =>
      'Tre modi per accendere il tuo cielo';
  @override
  String get lightYourSkyTourIntroBody =>
      'Le supernove sono le tue aree di vita e le loro visioni. Le costellazioni sono progetti: forme che le tue stelle riempiono. Le stelle sono singoli sforzi: una vittoria, un obiettivo o un\'abitudine.';
  @override
  String get constellationTourCanvasTitle => 'Dagli una forma';
  @override
  String get constellationTourCanvasBody =>
      'Ogni progetto ha bisogno di una forma che le sue stelle riempiranno. Tocca l\'anteprima o Disegna per crearne una tua, scegline una dalla libreria o ricomincia.';
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
  String get supernovaTourReflectionTitle => 'Domande di riflessione';
  @override
  String get supernovaTourReflectionBody =>
      "Alcuni spunti per quest'area — rispondi quando ti va.";
  @override
  String get replayToursAction => 'Rivedi';
  @override
  String get replayToursResult =>
      'Tutorial azzerati — riapri ogni schermata per rivederli';
  @override
  String get tutorialsButtonTooltip => 'Tutorial';
  @override
  String get tutorialsManagementTitle => 'Tutorial';
  @override
  String get tutorialsEnabledLabel => 'Mostra i tutorial';
  @override
  String get tutorialsEnabledDescription =>
      'I suggerimenti guidati compaiono la prima volta che apri una schermata che li prevede.';
  @override
  String get tutorialsScreenIntro =>
      'Non ricordi come funziona qualcosa, o vuoi mostrarlo a un amico? Rivedi qui qualsiasi tutorial.';
  @override
  String get tutorialDemoProjectName => 'Rimettermi in forma';
  @override
  String get tutorialDemoStarTitle => 'La mia prima corsa da 5 km';
  @override
  String get tutorialDemoStarDescription =>
      'Ho tagliato il traguardo senza fermarmi. Più lento di come speravo, ma ce l\'ho fatta.';
  @override
  String get resetToursAction => 'Azzera Tutti i Tutorial';
  @override
  String get tutorialsOpenAction => 'Apri i Tutorial';
  @override
  String get tutorialReplayConfirmTitle => 'Rivederlo?';
  @override
  String get tutorialReplayConfirmBody =>
      'Vuoi rivedere il tutorial live per questa funzionalità? Ti porto nel posto giusto e, alla fine, torni qui.';
  @override
  String get tutorialReplayConfirmAction => 'Sì, Mostramelo';
  @override
  String get tutorialEntrySkyNavigationTitle => 'Navigare nel Cosmo';
  @override
  String get tutorialEntrySkyNavigationBody =>
      'Muoviti nel cielo, fai zoom e apri il menu.';
  @override
  String get tutorialEntryLightYourSkyTitle => 'Accendi il Tuo Cielo';
  @override
  String get tutorialEntryLightYourSkyBody =>
      'Supernove, costellazioni e stelle: cosa puoi creare.';
  @override
  String get tutorialEntryStarFormTitle => 'Registrare una Stella';
  @override
  String get tutorialEntryStarFormBody =>
      'Vittorie, obiettivi e abitudini: scegliere il tipo giusto.';
  @override
  String get tutorialEntryShapeEditorTitle => 'Disegnare una Forma';
  @override
  String get tutorialEntryShapeEditorBody =>
      "Posiziona, collega e sposta le stelle nell'editor di forme.";
  @override
  String get tutorialEntryConstellationFormTitle => 'Creare una Costellazione';
  @override
  String get tutorialEntryConstellationFormBody =>
      "Scegli un'area e dai una forma al tuo progetto.";
  @override
  String get tutorialEntrySearchStarsTitle => 'Sfogliare il Cielo';
  @override
  String get tutorialEntrySearchStarsBody =>
      'Cerca, filtra e passa tra i tre livelli.';
  @override
  String get tutorialEntrySupernovaVisionTitle => 'Le Visioni delle Aree';
  @override
  String get tutorialEntrySupernovaVisionBody =>
      'Rifletti su ogni area e scrivi la tua visione.';
  @override
  String get tutorialEntryStarReaderTitle => 'Leggere una Stella';
  @override
  String get tutorialEntryStarReaderBody =>
      'Sfoglia le tue stelle e scopri cosa puoi farci.';
  @override
  String get quickSettingsButtonTooltip => 'Impostazioni rapide';
  @override
  String get quickSettingsEyebrow => 'IMPOSTAZIONI RAPIDE';
  @override
  String get quickSettingsTitle => 'Impostazioni rapide';
  @override
  String get quickSettingsAudioSection => 'Audio';
  @override
  String get quickSettingsOpenSoundLabAction => 'Sound Lab';
  @override
  String get uiSandboxButtonTooltip => 'Sandbox UI';
  @override
  String get uiSandboxTitle => 'Sandbox UI';
  @override
  String get uiSandboxIntro =>
      'Un audit consultabile delle varianti attuali e degli standard candidati. Gli esempi sono interattivi ma non modificano mai i dati reali.';
  @override
  String get uiSandboxFiltersTitle => 'Filtri audit';
  @override
  String get uiSandboxViewportTitle => 'Esempi responsive';
  @override
  String get uiSandboxViewportBody =>
      'Cambia la larghezza del viewport e prova gli stati isolati qui sotto.';
  @override
  String get uiSandboxMatrixTitle => 'Matrice dell’audit';
  @override
  String uiSandboxMatrixBody(int count) =>
      '$count elementi corrispondenti. Espandine uno per vedere evidenze, opzioni e raccomandazione.';
  @override
  String uiSandboxVariantsCount(int count) => '$count varianti attuali';
  @override
  String uiSandboxCandidatesCount(int count) => '$count candidati';
  @override
  String uiSandboxCategoriesCount(int count) => '$count categorie';
  @override
  String get uiSandboxCategoryLabel => 'Categoria';
  @override
  String get uiSandboxAllLabel => 'Tutte';
  @override
  String get uiSandboxAllStatesLabel => 'Tutte le decisioni';
  @override
  String get uiSandboxExistingLabel => 'Variante attuale';
  @override
  String get uiSandboxCandidateLabel => 'Standard candidato';
  @override
  String get uiSandboxReviewStatus => 'Da valutare';
  @override
  String get uiSandboxKeepStatus => 'Mantenere';
  @override
  String get uiSandboxReplaceStatus => 'Sostituire';
  @override
  String get uiSandboxExceptionStatus => 'Eccezione approvata';
  @override
  String get uiSandboxOriginsLabel => 'Origini';
  @override
  String get uiSandboxStatesLabel => 'Stati verificati';
  @override
  String get uiSandboxDifferencesLabel => 'Differenze';
  @override
  String get uiSandboxRationaleLabel => 'Possibile motivazione';
  @override
  String get uiSandboxRisksLabel => 'Rischi UX e accessibilità';
  @override
  String get uiSandboxOptionsLabel => 'Opzioni';
  @override
  String get uiSandboxRecommendationLabel => 'Raccomandazione candidata';
  @override
  String get uiSandboxResetFiltersAction => 'Azzera filtri';
  @override
  String get uiSandboxTypographyCategory => 'Tipografia';
  @override
  String get uiSandboxActionsCategory => 'Pulsanti e azioni';
  @override
  String get uiSandboxFieldsCategory => 'Campi';
  @override
  String get uiSandboxSelectionCategory => 'Controlli di selezione';
  @override
  String get uiSandboxSurfacesCategory => 'Card e superfici';
  @override
  String get uiSandboxOverlaysCategory => 'Dialog e sheet';
  @override
  String get uiSandboxNavigationCategory => 'Navigazione';
  @override
  String get uiSandboxFeedbackCategory => 'Feedback';
  @override
  String get uiSandboxSpacingCategory => 'Spaziatura e forme';
  @override
  String get uiSandboxColorCategory => 'Colori e stati';
  @override
  String get uiSandboxIconsCategory => 'Icone';
  @override
  String get uiSandboxMotionCategory => 'Movimento';
  @override
  String get uiSandboxTypographySpecimen => 'Varianti tipografiche';
  @override
  String get uiSandboxActionsSpecimen => 'Varianti e stati delle azioni';
  @override
  String get uiSandboxFieldsSpecimen => 'Stati dei campi';
  @override
  String get uiSandboxSelectionSpecimen => 'Stati di selezione';
  @override
  String get uiSandboxSurfacesSpecimen => 'Principio del tema gold';
  @override
  String get uiSandboxOverlaysSpecimen => 'Pattern modali isolati';
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
  String get nameYourConstellationTitle =>
      'Dai Un Nome Alla Tua Forma Di Stelle';
  @override
  String get nameYourConstellationDescription =>
      'Scegli un nome breve per riconoscerla nel cielo.';
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
  String get shapeLibraryTitle => 'Forma Costellazione';
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
  String get editSelectedShapeAction => 'Modifica';

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
  String get galaxyLabel => 'Galassia';
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
  String get chooseIconTitle => 'Icona';
  @override
  String get pickerConfirmAction => 'OK';
  @override
  String get closeAction => 'Chiudi';
  @override
  String get displaySettingsTitle => 'Visualizzazione';
  @override
  String get displaySettingsDescription =>
      'Scegli quali controlli mostrare nel cielo.';
  @override
  String get createProject => 'Crea costellazione';
  @override
  String get newProject => 'Nuova costellazione';
  @override
  String get newAction => 'Nuova';

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
  String get litDetailsHint =>
      'Es. Le gambe mi facevano male, ma ce l\'ho fatta';
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
  String get mainPhotoLabel => 'Foto Principale';
  @override
  String get addPhotoHint => 'Aggiungi una foto';
  @override
  String get photoSourceTitle => 'Aggiungi Foto';
  @override
  String get takePhotoOption => 'Scatta';
  @override
  String get choosePhotoOption => 'Carica';
  @override
  String get photoPickError =>
      'Non è stato possibile ottenere la foto. Riprova?';
  @override
  String get extrasHint =>
      'Aggiungi una nota vocale, foto, un video o un link per ricordare questa vittoria.';
  @override
  String get extraVoiceNote => 'Nota Vocale';
  @override
  String get extraPhoto => 'Foto';
  @override
  String get extraLink => 'Link';
  @override
  String get resetExtraAction => 'Azzera';
  @override
  String get addExtraAction => 'Aggiungi';
  @override
  String mediaMaxDuration(String duration) => 'Max $duration';
  @override
  String get recordVoiceTitle => 'Registra Una Nota Vocale';
  @override
  String get recordStart => 'Registra';
  @override
  String get recordStop => 'Stop';
  @override
  String get recordKeep => 'Conserva';
  @override
  String get micPermissionDenied =>
      "L'accesso al microfono è disattivato. Attivalo nelle impostazioni del telefono per registrare.";
  @override
  String get linkTitle => 'Aggiungi Un Link';
  @override
  String get linkUrlHint => 'https://esempio.it';
  @override
  String get linkLabelHint => 'Etichetta (facoltativa)';
  @override
  String get linkInvalid => 'Questo non sembra un link valido.';
  @override
  String get linkAdd => 'Aggiungi';
  @override
  String get mediaError => 'Impossibile aggiungerlo. Riprovare?';
  @override
  String get linkOpenError => 'Impossibile aprire il link.';
  @override
  String get removeExtraTooltip => 'Rimuovi';
  @override
  String mediaLimitReached(int max) => 'Puoi aggiungere fino a $max extra.';
  @override
  String voiceNoteLabel(String duration) => 'Nota vocale · $duration';
  @override
  String get voiceNotesLabel => 'Note Vocali';
  @override
  String get extraPhotosLabel => 'Foto Secondarie';
  @override
  String get videosLabel => 'Video';
  @override
  String get linksLabel => 'Link';
  @override
  String get addVoiceNoteHint => 'Registra una nota vocale';
  @override
  String get addExtraPhotosHint => 'Aggiungi foto';
  @override
  String get addVideoHint => 'Aggiungi un video';
  @override
  String get addLinkHint => 'Aggiungi un link';
  @override
  String get cropPhotoTitle => 'Modifica la foto';
  @override
  String get cropPhotoConfirm => 'Fatto';
  @override
  String get cropPhotoHint =>
      'Pizzica e trascina per adattare la foto alla cornice';
  @override
  String get saveChanges => 'Salva';
  @override
  String get lightThisStar => 'Salva';
  @override
  String get placeThisStarAction => 'Salva';
  @override
  String get cannotSaveTitle => 'Dati mancanti';
  @override
  String get cannotSaveMissingInfo =>
      'Completa i campi obbligatori indicati prima di salvare.';
  @override
  String get constellationFullTitle => 'Costellazione piena';
  @override
  String get constellationFullCreateNew => 'Crea';
  @override
  String constellationFullStars(int max) =>
      'Questa costellazione ha già tutte le sue $max stelle. Ne creiamo una nuova nella stessa area per continuare?';
  @override
  String constellationFullPulsars(int max) =>
      'Questa costellazione ha già tutte le sue $max pulsar. Ne creiamo una nuova nella stessa area per continuare?';
  @override
  String get gotIt => 'OK';
  @override
  String get deleteStarConfirmTitle => 'Eliminare questa stella?';
  @override
  String get deleteStarConfirmBody =>
      'La stella diventerà un fallimento: uscirà da qui, ma resterà al suo posto nel cielo e potrai riaccenderla in seguito.';
  @override
  String get deletePulsarConfirmTitle => 'Eliminare questa abitudine?';
  @override
  String get deletePulsarConfirmBody =>
      'L\'abitudine diventerà un fallimento: smette di pulsare, ma resta al suo posto nel cielo e potrai riaccenderla come abitudine in seguito.';
  @override
  String get deleteStarAction => 'Elimina';
  @override
  String get discardChangesConfirmTitle => 'Scartare le modifiche?';
  @override
  String get discardChangesConfirmBody => 'Perderai le modifiche effettuate.';
  @override
  String get discardChangesAction => 'Scarta';

  @override
  String get targetDateLabel => 'Data obbiettivo';
  @override
  String get selectATargetDateHint => 'Seleziona una data';

  @override
  String goalTargetLabel(String date) => 'Obbiettivo per il $date';

  @override
  String starSlotLabel(int slot) => 'Stella n. $slot';

  @override
  String pulsarNumberLabel(int number) => 'Abitudine n. $number';
  @override
  String get markAchievedAction => 'Segna come raggiunta';
  @override
  String get markAchievedSheetTitle => 'Quanto ti è costato raggiungerla?';
  @override
  String get markAchievedConfirm => 'Salva';
  @override
  String get undoAchievedAction => 'Segna come non raggiunta';
  @override
  String get deadStarBody =>
      'Questa stella è stata cancellata. Puoi riaccenderla come una stella nuova, nello stesso punto del cielo.';
  @override
  String get deadPulsarBody =>
      'Questa abitudine è stata eliminata. Puoi riaccenderla come una nuova abitudine, nello stesso punto del cielo — la vecchia serie resta indietro.';
  @override
  String get reigniteAction => 'Riaccendi';

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
  String get habitCheckAction => 'Spunta';
  @override
  String get habitUncheckAction => 'Togli Spunta';
  @override
  String get habitStillToDoLabel => 'Ancora da fare';
  @override
  String get habitDoneTodayLabel => 'Fatto per oggi';
  @override
  String get undoHabitTodayAction => 'Annulla';
  @override
  String get habitTodayLabel => 'Oggi';
  @override
  String get cardBadgeVoice => 'Note vocali';
  @override
  String get cardBadgePhotos => 'Foto';
  @override
  String get cardBadgeVideos => 'Video';
  @override
  String get cardBadgeLinks => 'Link';
  @override
  String get cardBadgeLitStars => 'Stelle accese';
  @override
  String get cardBadgeGoals => 'Obiettivi';
  @override
  String get cardBadgeEmptySlots => 'Posti vuoti';
  @override
  String get cardBadgePulsarsToday => 'Abitudini accese oggi';
  @override
  String get cardBadgeHabits => 'Abitudini';
  @override
  String get cardBadgeDeadStars => 'Stelle morte';
  @override
  String get cardBadgeConstellations => 'Costellazioni';
  @override
  String habitProgressToday(int done, int target) => '$done/$target oggi';
  @override
  String habitProgressThisWeek(int done, int target) =>
      '$done/$target questa settimana';
  @override
  String habitThisWeekCaption(bool doneToday) => doneToday
      ? 'Questa settimana · oggi fatto'
      : 'Questa settimana · oggi non ancora';
  @override
  String get habitStatsSectionTitle => 'Pulsar';
  @override
  String get starsStatsSectionTitle => 'Stelle';
  @override
  String get habitStatsActiveLabel => 'Attive';
  @override
  String get habitStatsOnTrackLabel => 'In carreggiata';
  @override
  String get habitStatsConsistencyLabel => 'Costanza';
  @override
  String get habitStatsLongestLabel => 'Record personale';
  @override
  String get habitStatsTotalLabel => 'Completamenti totali';
  @override
  String get habitStatsTrendLabel => 'Ritmo recente';
  @override
  String get habitStatsWeekdaysLabel => 'La tua settimana';
  @override
  String get habitStatsBestDayLabel => 'Giorno più forte';
  @override
  String get habitStatsSupportDayLabel => 'Giorno da sostenere';
  @override
  String get habitStatsNotEnoughData =>
      'Serve ancora un po’ di storia per vedere questo ritmo.';
  @override
  String get habitStatsArchiveAction => 'Archivio';
  @override
  String get habitStatsArchiveTitle => 'Pulsar passate';
  @override
  String get habitStatsArchiveEmpty => 'Non ci sono ancora pulsar passate.';
  @override
  String habitStatsDays(int count) => count == 1 ? '1 giorno' : '$count giorni';
  @override
  String habitStatsWeeks(int count) =>
      count == 1 ? '1 settimana' : '$count settimane';

  @override
  String activePulsarsBadge(int count) =>
      count == 1 ? '1 abitudine attiva' : '$count abitudini attive';

  @override
  String get starKindNascentName => 'Opportunità';
  @override
  String get starKindNascentPlural => 'Opportunità';
  @override
  String get starKindNascentMeaning => 'Non ancora configurata';

  @override
  String get starKindNascentExample =>
      'Un punto di una costellazione appena creata: disegnato, ma non ancora deciso.';
  @override
  String get starKindLitName => 'Vittoria';
  @override
  String get starKindLitPlural => 'Vittorie';
  @override
  String get starKindLitMeaning => 'Fatta';
  @override
  String get starKindLitExample =>
      'Ho retto il colloquio anche se ero terrorizzato.';
  @override
  String get starKindUnlitName => 'Obiettivo';
  @override
  String get starKindUnlitPlural => 'Obiettivi';
  @override
  String get starKindUnlitMeaning => 'Da fare';
  @override
  String get starKindUnlitExample => 'Correre i miei primi 10 km.';
  @override
  String get starKindPulsarName => 'Abitudine';
  @override
  String get starKindPulsarPlural => 'Abitudini';
  @override
  String get starKindPulsarMeaning => 'In corso';
  @override
  String get starKindPulsarExample =>
      'Dieci minuti di stretching, ogni giorno.';
  @override
  String get starKindDeadName => 'Fallimento';
  @override
  String get starKindDeadPlural => 'Fallimenti';
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
  String get chooseSupernovasToInclude => 'Scegli le supernove da includere';
  @override
  String get allAreasLabel => 'Tutto';
  @override
  String get admireAllAreasLabel => 'Tutte';
  @override
  String get pickAtLeastOneArea =>
      'Scegli almeno una supernova per continuare.';
  @override
  String get noStarsInSelection =>
      'Nessuna stella ancora accesa nelle supernove scelte.';
  @override
  String get viewYourStars => 'Visualizza';

  @override
  String get nightlightGateQuestionPrefix => 'Prima di cominciare, sei ';
  @override
  String get nightlightGateQuestionOkWord => 'a posto';
  @override
  String get nightlightGateQuestionMiddle => ' o in modalità ';
  @override
  String get nightlightGateQuestionCrisisWord => 'crisi';
  @override
  String get nightlightGateQuestionSuffix => '?';
  @override
  String get nightlightGateOkPrefix => 'Sto ';
  @override
  String get nightlightGateOkWord => 'bene';
  @override
  String get nightlightGateCrisisPrefix => 'Sono in ';
  @override
  String get nightlightGateCrisisWord => 'crisi';
  @override
  String get nightlightExplainedTitle => 'Calm Down';
  @override
  String get nightlightExplainedSchemeAgitated => 'Agitato';
  @override
  String get nightlightExplainedSchemeBreathe => 'Respira';
  @override
  String get nightlightExplainedSchemeClarity => 'Vedi Chiaro';
  @override
  String get nightlightExplainedBody =>
      'Prima di vedere le vittorie, fermiamoci un momento a *respirare* '
      'per calmarci. Segui le istruzioni sullo schermo.';
  @override
  String get nightlightExplainedContinue => 'Continua';
  @override
  String get nightlightBreathingGetReady => 'Preparati';
  @override
  String get nightlightBreathingInhale => 'Inspira';
  @override
  String get nightlightBreathingExhale => 'Espira';
  @override
  String get nightlightBreathingSkip => 'Continua';
  @override
  String nightlightBreathingCycleLabel(int current, int total) =>
      'Ciclo $current di $total';
  @override
  String nightlightBreathingCyclesUntilSkip(int remaining) => remaining == 1
      ? 'Potrai continuare tra 1 ciclo'
      : 'Potrai continuare tra $remaining cicli';
  @override
  String get nightlightBreathingCheckInTitle => 'Come ti senti ora?';
  @override
  String get nightlightBreathingCheckInBody =>
      'Spero che ora tu stia meglio. Se non sei ancora a posto, puoi '
      'rifare l\'esercizio. Se ti senti a posto, puoi andare avanti.';
  @override
  String get nightlightBreathingCheckInRedo => 'Rifai';
  @override
  String get nightlightBreathingCheckInProceed => 'Procedi';

  @override
  String get newConstellationOption => 'Nuova costellazione';

  @override
  String get visionsEyebrow => 'IL QUADRO PIÙ GRANDE';
  @override
  String get visionsTitle => 'Le Tue Visioni';
  @override
  String get areasTitle => 'Aree';
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
  String get shareContentError =>
      'Non è stato possibile condividere questo contenuto. Riprova?';
  @override
  String get sharePreviewTitle => 'Anteprima condivisione';
  @override
  String get shareChooseLayout => 'Scegli una composizione';
  @override
  String get shareLayoutImmersive => 'Editoriale';
  @override
  String get shareLayoutFramed => 'Fotografica';
  @override
  String get shareLayoutPostcard => 'Frase';
  @override
  String get shareNowAction => 'Condividi';
  @override
  String get starReaderTourIntroTitle => 'Spostarsi tra le stelle';
  @override
  String get starReaderTourIntroBody =>
      'Scorri di lato per andare alla stella precedente o successiva. Su una stella con foto, tocca un punto vuoto per vedere solo la foto.';
  @override
  String get starReaderTourDockTitle => 'Tutto quello che puoi fare';
  @override
  String get starReaderTourDockBody =>
      'Questi pulsanti cambiano con la stella: accenderla, condividerla, modificarla, eliminarla o riportarla in vita.';

  @override
  String get starQuickLookViewAction => 'Visualizza';
  @override
  String get starQuickLookEditAction => 'Modifica';
  @override
  String get starQuickLookShareAction => 'Condividi';

  @override
  String get constellationQuickLookAddStarAction => '+ Stella';

  @override
  String get areaQuickLookReflectionsAction => 'Riflessioni';

  @override
  String get areaQuickLookNewConstellationAction => '+ Costellazione';
  @override
  String get nascentStarQuickLookConfigureAction => 'Configura';
  @override
  String constellationTooltipLitCount(int lit, int total) =>
      '$lit/$total vittorie';
  @override
  String get creationSuccessEyebrow => 'Complimenti!';
  @override
  String get creationSuccessLitMessage =>
      'Una stella si è accesa nel tuo cielo.';
  @override
  String get creationSuccessUnlitMessage =>
      'Un nuovo obiettivo è stato fissato nel tuo cielo.';
  @override
  String get creationSuccessPulsarMessage =>
      'Una nuova abitudine ha iniziato a pulsare nel tuo cielo.';
  @override
  String get creationSuccessConstellationMessage =>
      'Una nuova costellazione è stata aggiunta al tuo cielo.';
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
  String get skySupernovaeSection => 'Supernove';
  @override
  String get skySupernovaeToggleLabel => 'Mostra le supernove sopra le artwork';
  @override
  String get skyArtworkSection => 'Artwork';
  @override
  String get skyArtworkOpacityLabel => 'Opacità';
  @override
  String get skySupernovaScaleLabel => 'Dimensione supernove';
  @override
  String get skySupernovaIntensityLabel => 'Luminosità supernove';
  @override
  String get skyArtworkBlendLabel => 'Modalità di Fusione';
  @override
  String get skyArtworkResetDefaultsLabel => 'Ripristina predefiniti';
  @override
  String get skyArtworkControlsTooltip => 'Controlli artwork';
  @override
  String get skyArtworkScaleLabel => 'Dimensione';
  @override
  String get skyArtworkColorLabel => 'Colore';
  @override
  String get skyArtworkSaturationLabel => 'Saturazione';
  @override
  String get skyArtworkLightnessLabel => 'Luminosità';
  @override
  String get skyArtworkLayerLabel => 'Livello';
  @override
  String get skyArtworkLayerBehindSky => 'Dietro il cielo';
  @override
  String get skyArtworkLayerBehindSupernovae => 'Dietro le supernove';
  @override
  String get skyArtworkLayerAboveStars => 'Sopra le stelle';

  @override
  String get appLockSection => 'Blocco app';
  @override
  String get appLockToggleLabel => 'Attiva il blocco app';
  @override
  String get appLockBiometricToggleLabel => "Usa l'impronta digitale";
  @override
  String get appLockChangePinLabel => 'Cambia PIN';
  @override
  String get appLockSetPinTitle => 'Imposta un PIN';
  @override
  String get appLockConfirmPinTitle => 'Conferma il PIN';
  @override
  String get appLockEnterCurrentPinTitle => 'Inserisci il PIN attuale';
  @override
  String get appLockPinMismatchError => 'I PIN non coincidono, riprova.';
  @override
  String get appLockWrongPinError => 'PIN errato, riprova.';
  @override
  String get appLockBiometricReason => 'Sblocca Inner Stars';
  @override
  String get appLockUnlockTitle => 'Inserisci il PIN';
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
  String get downloadApkBannerBody =>
      'Stai usando la versione web. Per l\'app Android vera e propria, con '
      'notifiche e tutto il resto, scarica il file APK.';
  @override
  String get downloadApkAction => 'Scarica';
  @override
  String get downloadApkPromptTitle => 'Vuoi l\'app vera?';
  @override
  String get downloadApkPromptContinueAction => 'Continua';

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
      'Inner Stars trasforma le cose che realizzi nel tuo cielo notturno '
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
  @override
  String get dateInputInvalidValues => 'Valori non validi';
  @override
  String get dateInputInvalidDay => 'Controlla il giorno evidenziato.';
  @override
  String get dateInputInvalidMonth =>
      'Il mese deve essere compreso tra 1 e 12.';
  @override
  String dateInputInvalidYear(int firstYear, int lastYear) =>
      'L’anno deve essere compreso tra $firstYear e $lastYear.';
  @override
  String get dateInputOutsideRange =>
      'Questa data non rientra nell’intervallo consentito.';
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
