# Studio splash — proposta, non integrazione

Anteprima locale: dalla radice del repository avviare un server statico e aprire
`/tool/splash-preview/`. Riutilizza logo e font della landing senza modificarla.
Le tre animazioni e il cielo di destinazione sono prototipi; i tempi del menu
sono simulazioni e non risultati di un benchmark.

## Direzione scelta per l’esplorazione

**Respiro del cielo**: mantiene gli aloni blu e oro della landing e aggiunge
un bagliore dorato che segue la sagoma esatta del logo SVG. Nel prototipo
l’intensità cresce fino al tempo di prontezza simulato, poi logo, scritte e
aloni di apertura sfumano insieme. Il movimento ridotto usa un bagliore statico.
Nell’app la crescita dovrà accompagnare l’attesa senza fingere una percentuale
di avanzamento; il segnale reale di prontezza avvia la dissolvenza.

## Alternative iniziali

**Scintilla**: logo originale già riconoscibile, accensione morbida dell’oro,
nome e dissolvenza sul cielo pronto. Respiro del cielo riprende gli aloni della
landing; Una forma dalle stelle aggiunge una piccola sequenza narrativa.
Nessuna proposta richiede video, immagini aggiuntive o una libreria animazioni.
Il peso e la fluidità della futura versione Flutter vanno misurati sul telefono.

## Piano di integrazione dopo la scelta

1. Coordinare sfondo e logo statici dello splash nativo con il primo frame
   Flutter. L’animazione parte quando Flutter può disegnare.
2. Sostituire lo sfondo vuoto di `InnerStarsApp` con il componente leggero.
   Tenere lo stesso overlay durante il montaggio della destinazione, evitando
   che il logo riparta al termine del caricamento dei repository.
3. Preparare Galaxy dietro lo splash e definire un segnale reale di prontezza:
   dati/layout e risorse grafiche necessarie pronti, primo frame disegnato.
   Un semplice timer o il solo completamento di `_load()` non bastano.
4. Al segnale, dissolvenza di circa 300–500 ms; nessuna durata minima imposta.
   Negli avvii veloci l’animazione si abbrevia. Nell’attesa lunga mantenere una
   luce discreta, senza riavviare tutta la sequenza. Gestire errore e recupero.
5. Conservare il percorso del blocco biometrico: se attivo, rivelare la schermata
   di sblocco prima di rendere visibile il contenuto personale. Coordinare
   tutorial, notifiche e audio con la fine dello splash.
6. Rispettare la preferenza di movimento ridotto e provare avvio freddo/caldo,
   caricamento lento, errore, blocco app e apertura da notifica. Misurare tempo
   al primo frame, tempo a Galaxy utilizzabile e frame persi su build profile.

La pagina non modifica il bootstrap dell’app né le modifiche in corso alla landing.
