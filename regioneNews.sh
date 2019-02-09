#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

### note ###

<<note
- il server nelle risposta http non definisce l'encoding, quindi è necessario forzarne la dichiarazione
- ci sono degli errori html. Se non si correggono i motori di scraping possono andare in errore
- vengono estratte da titolo data e diparimento
note

rm ./listaNotizie.tsv
urlBase="http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_Servizi/PIR_News?_piref857_3677299_857_3677298_3677298.strutsAction=%2Fnews.do&stepNews=archivio"
urlMese=$(curl "$urlBase" | scrape -be '//div[@class="titolomappapage" and contains(string(), "2019")]/following-sibling::ul[1]//a' | xq -r '.html.body.a["@href"]')
curl -L "$urlMese" | iconv -f ISO-8859-1 -t UTF-8 | tidy -q --show-warnings no --drop-proprietary-attributes y --show-errors 0 --force-output y --wrap 70001 |
    scrape -be '//div[@class="boxbiancoLiv2"]' | perl -pe 's| *class=".*?" *||' | sed -r 's|<p>&#160;</p>||g;s/&#160;//g;s|<br />||g' |
    xq -r '.html.body.div[]|[.h2.a["@href"],.h2.a["#text"]]|@tsv' >./listaNotizie.tsv

mlr -I --nidx --fs "\t" clean-whitespace then filter -x -S '$2==""' ./listaNotizie.tsv

mlr -I --nidx --fs "\t" put '$riferimento=gsub(regextract_or_else($2,"[[].+[]]$",""),"[][]","")' listaNotizie.tsv

mlr --nidx --fs "\t" put '$data=regextract_or_else($2,"[0-9]{1,}-[a-zA-Z]{1,}-[0-9]{1,}","")' then cut -f data ./listaNotizie.tsv |
    xargs -I _ dateconv --from-locale it_IT -i "%d-%b-%Y" -f "%a, %d %b %Y 02:00:00 +0100" _ >./listaNotizieDate.tsv

paste -d "\t" listaNotizie.tsv listaNotizieDate.tsv >finale.tsv

# aggiungere ArchivioLaRegioneInforma da http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma
# dateconv  -i "%d-%b-%Y %H:%M AM" -f "%a, %d %b %Y %H:%M:00 +0100" "30-JAN-2019 12:00 AM"
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma" | iconv -f ISO-8859-1 -t UTF-8 | tidyhtml | scrape -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]'  | perl -pe 's| *class=".*?" *||' | xq -r '.html.body.tr[]|[.td.div.div.div.div.div[1].a.span,.td.div.div.div.div.div[1].a["@href"],.td.div.div.div.div.div[0].strong]|@tsv' | sed 's/\\n/ /g' >regioneInfotma.tsv

# aggiungere presidente http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio
# dateconv  -i "%d-%b-%Y %H:%M AM" -f "%a, %d %b %Y %H:%M:00 +0100" "30-JAN-2019 12:00 AM"
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio" | iconv -f ISO-8859-1 -t UTF-8 | tidyhtml | scrape -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]'  | perl -pe 's| *class=".*?" *||;s|</span>||;s|<span>||' | xq -r '.html.body.tr[]|[.td.div.div.div.div.div[1].a["#text"],.td.div.div.div.div.div[1].a["@href"],.td.div.div.div.div.div[0].strong]|@tsv'  | sed 's/\\n/ /g' >ilPresidente.tsv

