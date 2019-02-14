#!/bin/bash

### Nota: i dati sono raccolti in modo "pulito" dal 12 febbraio 2019

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/process

source "$folder"/config

# se non c'è il file per archiviare i feed, crealo
if [[ ! -e "$folder"/data/RSSarchive.tsv ]]; then
	mkdir -p "$folder"/data
	touch "$folder"/data/RSSarchive.tsv
fi

rm "$folder"/listaNotizie.tsv
# URL di partenza
urlBase="http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_Servizi/PIR_News?_piref857_3677299_857_3677298_3677298.strutsAction=%2Fnews.do&stepNews=archivio"
# estrai l'URL della pagina dell'ultimo mese
urlMese=$(curl "$urlBase" | scrapeCli -be '//div[@class="titolomappapage" and contains(string(), "2019")]/following-sibling::ul[1]//a' | xq -r '.html.body.a["@href"]')

# estrai i dati dall'archivio notizie
curl -L "$urlMese" | iconv -f ISO-8859-1 -t UTF-8 | tidy -q --show-warnings no --drop-proprietary-attributes y --show-errors 0 --force-output y --wrap 70001 |
	scrapeCli -be '//div[@class="boxbiancoLiv2"]' | perl -pe 's| *class=".*?" *||g;s|</?em>||g' | sed -r 's|<p>&#160;</p>||g;s/&#160;//g;s|<br />||g' |
	xq -r '.html.body.div[]|[.h2.a["@href"],.h2.a["#text"]]|@tsv' >"$folder"/process/listaNotizie.tsv

mlr -I --nidx --fs "\t" clean-whitespace then filter -x -S '$2==""' "$folder"/process/listaNotizie.tsv

mlr -I --nidx --fs "\t" put '$riferimento=gsub(regextract_or_else($2,"[[].+[]]$",""),"[][]","")' "$folder"/process/listaNotizie.tsv

mlr --nidx --fs "\t" put '$data=regextract_or_else($2,"[0-9]{1,}-[a-zA-Z]{1,}-[0-9]{1,}","")' \
	then cut -f data "$folder"/process/listaNotizie.tsv |
	xargs -I _ dateconv --from-locale it_IT -i "%d-%b-%Y" -f "%a, %d %b %Y 02:00:00 +0100" _ >"$folder"/process/listaNotizieDate.tsv

paste -d "\t" "$folder"/process/listaNotizie.tsv "$folder"/process/listaNotizieDate.tsv >"$folder"/process/finale.tsv

# rimuovi dal titolo le date
mlr -I --nidx --fs "\t" put '$2=gsub($2,"^(.{2}-.{3}-.{4}) +- ","")' "$folder"/process/finale.tsv

# se la fonte non è definita, inserire "Archivio"
mlr -I --nidx --fs "\t" put 'if ($3==""){$3="Archivio"}' "$folder"/process/finale.tsv

# estrai "Archivio La Regione Informa" da http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma" | iconv -f ISO-8859-1 -t UTF-8 |
	tidy -q --show-warnings no --drop-proprietary-attributes y --show-errors 0 --force-output y --wrap 70001 |
	scrapeCli -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]' | perl -pe 's| *class=".+?" *||g' |
	xq -r '.html.body.tr[]|[.td.div.div.div.div.div[1].a["@href"],.td.div.div.div.div.div[1].a.span,"La Regione informa",.td.div.div.div.div.div[0].strong]|@tsv' |
	sed 's/\\n/ /g' >"$folder"/process/regioneInforma.tsv

# estrai "Il Presidente" http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio" | iconv -f ISO-8859-1 -t UTF-8 |
	tidy -q --show-warnings no --drop-proprietary-attributes y --show-errors 0 --force-output y --wrap 70001 |
	scrapeCli -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]' |
	perl -pe 's| *class=".+?" *||g;s|</span>||g;s|<span>||g' |
	xq -r '.html.body.tr[]|[.td.div.div.div.div.div[1].a["@href"],.td.div.div.div.div.div[1].a["#text"],"Il Presidente",.td.div.div.div.div.div[0].strong]|@tsv' |
	sed 's/\\n/ /g' >"$folder"/process/ilPresidente.tsv

# fai il merge di presidente e regione informa e crea file Altro
mlr --nidx --fs "\t" cat "$folder"/process/ilPresidente.tsv "$folder"/process/regioneInforma.tsv then clean-whitespace >"$folder"/process/tmpAltro.tsv

# crea da Altro, file con le date in formato RSS
mlr --nidx --fs "\t" cut -f 4 "$folder"/process/tmpAltro.tsv | xargs -I _ dateconv -i "%d-%b-%Y %H:%M AM" -f "%a, %d %b %Y %H:%M:00 +0100" _ >"$folder"/process/tmpAltroDate.tsv

# rimuovi da Altro il campo data esistente
mlr -I --nidx --fs "\t" cut -x -f 4 "$folder"/process/tmpAltro.tsv

# aggiungi ad Altro le date in formato RSS
paste -d "\t" "$folder"/process/tmpAltro.tsv "$folder"/process/tmpAltroDate.tsv >"$folder"/process/altroDate.tsv

# fai il merge di Altro con l'archivio News
mlr --nidx --fs "\t" cat "$folder"/process/altroDate.tsv "$folder"/process/finale.tsv >"$folder"/process/tmpRSS.tsv

# estrai date in formato YYYYMMDD
mlr --nidx --fs "\t" cut -f 4 "$folder"/process/tmpRSS.tsv | xargs -I _ dateconv -i "%a, %d %b %Y %H:%M:00 +0100" -f "%Y%m%d" _ >"$folder"/process/RSSdate.tsv

# aggiungi date in formato YYYYMMDD al file di insieme
paste -d "\t" "$folder"/process/tmpRSS.tsv "$folder"/process/RSSdate.tsv >"$folder"/process/RSS.tsv

# ordina il file di insieme per data descrescente
mlr -I --nidx --fs "\t" sort -nr 5 "$folder"/process/RSS.tsv

# se nell'URL è presente il carattere "&", sostituiscilo con "&amp;"
mlr -I --nidx --fs "\t" put '$1=gsub($1,"&","&amp;")' "$folder"/process/RSS.tsv

# rimuovi la source dal titolo, quando messa a fine titolo
mlr -I --nidx --fs "\t" put '$2=gsub($2," +[[].+[]]$","")' "$folder"/process/RSS.tsv

# inserisci la source, nel titolo a inizio cella 
mlr -I --nidx --fs "\t" put 'if ($3!=""){$2="[".$3."] ".$2}' "$folder"/process/RSS.tsv

# rimuovi eventuali duplicati
mlr -I --nidx --fs "\t" uniq -a "$folder"/process/RSS.tsv

# crea archivio notizie
cp "$folder"/data/RSSarchive.tsv "$folder"/data/tmp_RSSarchive.tsv
mlr --nidx --fs "\t" cat then uniq -a "$folder"/process/RSS.tsv "$folder"/data/tmp_RSSarchive.tsv >"$folder"/data/RSSarchive.tsv

### RSS ###

### anagrafica RSS
titolo="Regione Siciliana News | Non ufficiale"
descrizione="Un RSS per seguire le news pubblicate sul sito della Regione Siciliana"
selflink="http://dev.ondata.it/projs/opendatasicilia/regioneSicilianaNewsRSS/feed.xml"
docs="https://github.com/aborruso/regioneSiciliaNewsRSS"
### anagrafica RSS

rm "$folder"/feed.xml
cp "$folder"/risorse/feedTemplate.xml "$folder"/feed.xml

# aggiungi i dati di anafrafica al feed
xmlstarlet ed -L --subnode "//channel" --type elem -n title -v "$titolo" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n description -v "$descrizione" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n link -v "$selflink" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n "atom:link" -v "" -i "//*[name()='atom:link']" -t "attr" -n "rel" -v "self" -i "//*[name()='atom:link']" -t "attr" -n "href" -v "$selflink" -i "//*[name()='atom:link']" -t "attr" -n "type" -v "application/rss+xml" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n webMaster -v "andrea.borruso@ondata.it (Andrea Borruso)" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n docs -v "$docs" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n creativeCommons:license -v "http://creativecommons.org/licenses/by-sa/4.0/" "$folder"/feed.xml

cp "$folder"/process/RSS.tsv "$folder"/RSS.tsv

# leggi in loop i dati del file TSV e usali per creare nuovi item nel file XML
newcounter=0
while IFS=$'\t' read -r URL title source pubDateRSS datetime; do
	newcounter=$(expr $newcounter + 1)
	xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
		--subnode "//item[$newcounter]" --type elem -n title -v "$title" \
		--subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
		--subnode "//item[$newcounter]" --type elem -n pubDate -v "$pubDateRSS" \
		--subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
		--subnode "//item[$newcounter]" --type elem -n category -v "$source" -i "//item[$newcounter]/category[1]" -t "attr" -n "domain" -v "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/RSSspecs#source" \
		"$folder"/feed.xml
done <"$folder"/RSS.tsv

# pubblica online il feed
cat "$folder"/feed.xml >"$web"/feed.xml

# pubblica sul repo

mlr --itsvlite --ocsv label URL,titolo,sorgente,pubDate,ISODate then reorder -f titolo,sorgente,pubDate,ISODate,URL "$folder"/data/RSSarchive.tsv >"$folder"/data/RSSarchive.csv

## trasformo in base64 il file che voglio uploadare
var=$(base64 "$folder"/data/RSSarchive.csv);

## faccio l'upload su github
curl -i -X PUT https://api.github.com/repos/aborruso/regioneSiciliaNewsRSS/contents/RSSarchive.csv -H 'Authorization: token '"$token"'' -d @- <<CURL_DATA
{"path": "$folder/data/RSSarchive.csv", "message": "Aggiorna archivio notizie", "content": "$var", "branch": "master","sha": $(curl -X GET https://api.github.com/repos/aborruso/regioneSiciliaNewsRSS/contents/RSSarchive.csv | jq '.sha')}
CURL_DATA
