<!-- TOC -->

- [Uno script bash per creare il feed RSS delle News della Regione Siciliana](#uno-script-bash-per-creare-il-feed-rss-delle-news-della-regione-siciliana)
    - [Note sullo script](#note-sullo-script)
    - [Nota sulle pagine sorgente](#nota-sulle-pagine-sorgente)
    - [Nota sul file RSS di output](#nota-sul-file-rss-di-output)
    - [Requisiti](#requisiti)

<!-- /TOC -->

# Uno script bash per creare il feed RSS delle News della Regione Siciliana

La **Regione Siciliana** **non** **ha** un **feed** **RSS** per le proprie **News**. Queste sono pubblicate in diverse pagine:

- l'[**Archivio delle notizie**](http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_Servizi/PIR_News?_piref857_3677299_857_3677298_3677298.strutsAction=/news.do&stepNews=archivio);
- la [**Regione informa**](http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma);
- il [**Presidente**](http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio).

L'**URL** del **feed** **RSS** è [http://feeds.feedburner.com/RegioneSicilianaNewsNonUfficiale](http://feeds.feedburner.com/RegioneSicilianaNewsNonUfficiale).

## Note sullo script

Lo script si occupa di:

- estrarre titolo, data e URL delle notizie, dalle tre fonti soprastanti;
- se nel titolo è presente la fonte (ad esempio `[Dipartimento dell'ambiente]`), la rimuove e la inserisce nel campo `sorgente`;
- se nel titolo è presente la data (ad esempio `08-FEB-2019 - Servizio II - Decreto Dirigente Generale n. 240 del ...`), la rimuove e la inserisce nel capo `data`;
- converte le date dal formato di origine (`09-FEB-2019`) in formato RSS (`Sat, 09 Feb 2019 02:00:00 +0100`);
- mette insieme i dati delle tre sorgenti e li ordina per data decrescente;
- crea il feed RSS;
- crea un archivio delle notizie in formato TSV.

**Nota bene**:

- non è presente alcun controllo di errore. Né per sorgente non disponibile, né per una modifica nella struttura delle pagine di _input_;
- la descrizione degli elementi del feed RSS è la copia del titolo.

## Nota sulle pagine sorgente

- il server non risponde dichiarando l'_encoding_. Quindi per interpretare correttamente la risposta e non avere problemi ad esempio con i caratteri accentati, bisogna forzarne la definizione. Si tratta di `ISO-8859-1`;
- in alcune pagine ci sono degli errori di validazione HTML. Ne è stata forzata la correzione, altrimenti l'estrazione di dati potrebbe andare in errore.

## Nota sul file RSS di output

È stata inserita la "sorgente" di ogni notizia, all'interno del tag `category`. Nell'esempio di sotto è `Dipartimento dell'ambiente`. Quindi sarà possibile mappare/filtrare le news in base all'origine.

```xml
<item>
      <title>[Dipartimento dell'ambiente] Convocazione prima Conferenza di Servizi del 14 febbraio 2019 per il rilascio del Provvedimento Autorizzatorio Unico Regionale, ex art. 27-bis D.Lgs. 152/2016 e ss.mm.ii..</title>
      ...
      ...
      <category domain="http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/RSSspecs#source">Dipartimento dell'ambiente</category>
</item>
```

## Requisiti

- xmlstarlet http://xmlstar.sourceforge.net/
- xq https://yq.readthedocs.io/en/latest/
- tidy http://tidy.sourceforge.net/
- scrape-cli https://github.com/aborruso/scrape-cli
- mlr http://johnkerl.org/miller/doc/
- dateutils https://github.com/hroptatyr/dateutils

Per usare `scrape-cli`, fare il _download_ dell'eseguibile con `wget -O "scrapeCli" "https://github.com/aborruso/scrape-cli/releases/download/v1.0/scrape"`, poi dargli il permesso di esecuzione e spostarlo in una cartella presente nel PATH del sistema operativo.
