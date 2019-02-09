#!/bin/bash

# per le date usare dconv --from-locale it_IT -i "%d-%b-%Y" "05-LUG-2019"

#mlr --n2x --ifs "\t" put '$data=regextract($2,"[0-9]{1,}-[a-zA-Z]{1,}-[0-9]{1,}")' listaNotizie.tsv

#mlr --inidx --ifs ',' --ocsv put -S 'counter=1; for (k,v in $*) {if (v =~ "[A-Z]" && v !=~ "Yea" && counter < 13) {$[k]=counter;counter += 1;}}' \

#mlr --n2x --ifs "\t" put 'for (k,v in $*) {$2=='$(echo "ciao")'}'

set -x

<<commento
# scarica elenco strutture
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_LaStrutturaRegionale" |
    scrape -be '//a[contains(@href, "http://pti.regione.sicilia.it/portal/page/portal/")]' |
    xq -r '.html.body.a[]|[."@href",.span?["#text"]?]|@csv' |
    mlr --icsv --otsv --implicit-csv-header --headerless-csv-output clean-whitespace >./listaPortali.csv

rm ./listaPagineNews.tsv

# scarica lista di pagine con news
while IFS=$'\t' read -r -a myArray; do
    #echo "${myArray[0]}"
    urlNews=$(curl -L ""${myArray[0]}"" | scrape -be '//h2[contains(string(), "Altre News")]/a' | xq -r '.html.body.a["@href"]')
    echo -e "${myArray[1]}\t$urlNews" >>./listaPagineNews.tsv
done <./listaPortali.csv

mlr -I --nidx --fs "\t" filter -x -S '$2=="null"' ./listaPagineNews.tsv


rm ./listaPagineNewsMese.tsv

# scarica elenco pagine news ultimo mese del 2019
while IFS=$'\t' read -r -a myArray; do
    #echo "${myArray[0]}"
    urlNewsMese=$(curl -L ""${myArray[1]}"" | scrape -be '//div[@class="titolomappapage" and contains(string(), "2019")]/following-sibling::ul[1]//a' | xq -r '.html.body.a["@href"]')
    echo -e "${myArray[0]}\t$urlNewsMese" >>./listaPagineNewsMese.tsv
done <./listaPagineNews.tsv


# scarica notizie
while IFS=$'\t' read -r -a myArray; do
    #echo "${myArray[0]}"
    curl -L ""${myArray[1]}"" | scrape -be '//div[@class="boxbiancoLiv2"]' | sed -r 's/class=".+?"//g;s|<p>&#160;</p>||g;s/&#160;//g' | xq -r '.html.body.div[]|[.h2.a["@href"],.h2.a["#text"],.p?]|@tsv' >>./listaNotizie.tsv
done <./listaPagineNewsMese.tsv

mlr -I --nidx --fs "\t" clean-whitespace then filter -x -S '$2=="Altre News"' ./listaNotizie.tsv
commento

### note ###

<<note
- il server nelle risposta http non definisce l'encoding, quindi è necessario forzarne la lettura
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

# aggiungere titoli e URL da http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma" | iconv -f ISO-8859-1 -t UTF-8 | tidyhtml | scrape -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]'  | perl -pe 's| *class=".*?" *||' | xq .

# aggiungere presidente http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio
# curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio" | iconv -f ISO-8859-1 -t UTF-8 | tidyhtml | scrape -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]'  | perl -pe 's| *class=".*?" *||;s|</span>||;s|<span>||' | xq .

