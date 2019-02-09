#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

### requisiti ###

<<requisiti
- xmlstarlet http://xmlstar.sourceforge.net/
- xq https://yq.readthedocs.io/en/latest/
- tidy http://tidy.sourceforge.net/
- scrape-cli https://github.com/aborruso/scrape-cli
- mlr http://johnkerl.org/miller/doc/
requisiti

### note ###

<<note
- il server nelle risposta http non definisce l'encoding, quindi è necessario forzarne la dichiarazione
- ci sono degli errori html. Se non si correggono i motori di scraping possono andare in errore
- vengono estratte da titolo data e diparimento
note

rm "$folder"/listaNotizie.tsv
urlBase="http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_Servizi/PIR_News?_piref857_3677299_857_3677298_3677298.strutsAction=%2Fnews.do&stepNews=archivio"
urlMese=$(curl "$urlBase" | scrape -be '//div[@class="titolomappapage" and contains(string(), "2019")]/following-sibling::ul[1]//a' | xq -r '.html.body.a["@href"]')

curl -L "$urlMese" | iconv -f ISO-8859-1 -t UTF-8 | tidy -q --show-warnings no --drop-proprietary-attributes y --show-errors 0 --force-output y --wrap 70001 |
    scrape -be '//div[@class="boxbiancoLiv2"]' | perl -pe 's| *class=".*?" *||' | sed -r 's|<p>&#160;</p>||g;s/&#160;//g;s|<br />||g' |
    xq -r '.html.body.div[]|[.h2.a["@href"],.h2.a["#text"]]|@tsv' >"$folder"/listaNotizie.tsv

mlr -I --nidx --fs "\t" clean-whitespace then filter -x -S '$2==""' "$folder"/listaNotizie.tsv

mlr -I --nidx --fs "\t" put '$riferimento=gsub(regextract_or_else($2,"[[].+[]]$",""),"[][]","")' "$folder"/listaNotizie.tsv

mlr --nidx --fs "\t" put '$data=regextract_or_else($2,"[0-9]{1,}-[a-zA-Z]{1,}-[0-9]{1,}","")' then cut -f data "$folder"/listaNotizie.tsv |
    xargs -I _ dateconv --from-locale it_IT -i "%d-%b-%Y" -f "%a, %d %b %Y 02:00:00 +0100" _ >"$folder"/listaNotizieDate.tsv

paste -d "\t" "$folder"/listaNotizie.tsv "$folder"/listaNotizieDate.tsv >"$folder"/finale.tsv

# rimuovi dal titolo le date
mlr -I --nidx --fs "\t" put '$2=gsub($2,"^(.{2}-.{3}-.{4}) +- ","")' "$folder"/finale.tsv 

# estrai "Archivio La Regione Informa" da http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_ArchivioLaRegioneInforma" | iconv -f ISO-8859-1 -t UTF-8 | \
tidy -q --show-warnings no --drop-proprietary-attributes y --show-errors 0 --force-output y --wrap 70001 | scrape -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]'  | perl -pe 's| *class=".*?" *||' | xq -r '.html.body.tr[]|[.td.div.div.div.div.div[1].a["@href"],.td.div.div.div.div.div[1].a.span,"La Regione Informa",.td.div.div.div.div.div[0].strong]|@tsv' | sed 's/\\n/ /g' >"$folder"/regioneInforma.tsv

# estrai "Il Presidente" http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio
# dateconv  -i "%d-%b-%Y %H:%M AM" -f "%a, %d %b %Y %H:%M:00 +0100" "30-JAN-2019 12:00 AM"
curl -sL "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/PIR_IlPresidente/PIR_Archivio" | iconv -f ISO-8859-1 -t UTF-8 | \
tidy -q --show-warnings no --drop-proprietary-attributes y --show-errors 0 --force-output y --wrap 70001 | scrape -be '//table[@id]//tr[.//div[@class="dataslidearchivio" and contains(string(), "-2019 ")]]'  | perl -pe 's| *class=".*?" *||;s|</span>||;s|<span>||' | xq -r '.html.body.tr[]|[.td.div.div.div.div.div[1].a["@href"],.td.div.div.div.div.div[1].a["#text"],"Il Presidente",.td.div.div.div.div.div[0].strong]|@tsv'  | sed 's/\\n/ /g' >"$folder"/ilPresidente.tsv

# fai il merge di presidente e regione informa e creo file Altro
mlr --nidx --fs "\t" cat "$folder"/ilPresidente.tsv "$folder"/regioneInforma.tsv then clean-whitespace>"$folder"/tmpAltro.tsv

# crea da Altro file con le date in formato RSS
mlr --nidx --fs "\t" cut -f 4 "$folder"/tmpAltro.tsv | xargs -I _ dateconv  -i "%d-%b-%Y %H:%M AM" -f "%a, %d %b %Y %H:%M:00 +0100" _ >"$folder"/tmpAltroDate.tsv

# rimuovi da Altro il campo data esistente
mlr -I --nidx --fs "\t" cut -x -f 4 "$folder"/tmpAltro.tsv

# aggiungi ad Alto le date in formato RSS
paste -d "\t" "$folder"/tmpAltro.tsv "$folder"/tmpAltroDate.tsv >"$folder"/altroDate.tsv

# fai il merge di Altro con l'archivio News
mlr --nidx --fs "\t" cat "$folder"/altroDate.tsv "$folder"/finale.tsv >"$folder"/tmpRSS.tsv

# estrai date in formato YYYYMMDD
mlr --nidx --fs "\t" cut -f 4 "$folder"/tmpRSS.tsv | xargs -I _ dateconv  -i "%a, %d %b %Y %H:%M:00 +0100" -f "%Y%m%d" _ >"$folder"/RSSdate.tsv

# aggiungi date in formato YYYYMMDD al file di insieme
paste -d "\t" "$folder"/tmpRSS.tsv "$folder"/RSSdate.tsv >"$folder"/RSS.tsv

# ordina il file di insieme per data descrescente
mlr -I --nidx --fs "\t" sort -nr 5 "$folder"/RSS.tsv

### RSS ###

### anagrafica RSS
titolo="Regione Siciliana News | Non ufficiale"
descrizione="Un RSS per seguire le news pubblicate sul sito della Regione Siciliana"
selflink="http://dev.ondata.it/projs/regioneSicilianaNewsRSS/feed.xml"
#docs="URL del repo da inserire"
### anagrafica RSS


rm "$folder"/feed.xml
cp "$folder"/risorse/feedTemplate.xml "$folder"/feed.xml

# aggiungo i dati di anafrafica al feed
xmlstarlet ed -L --subnode "//channel" --type elem -n title -v "$titolo" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n description -v "$descrizione" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n link -v "$selflink" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n "atom:link" -v "" -i "//*[name()='atom:link']" -t "attr" -n "rel" -v "self" -i "//*[name()='atom:link']" -t "attr" -n "href" -v "$selflink" -i "//*[name()='atom:link']" -t "attr" -n "type" -v "application/rss+xml" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n webMaster -v "andrea.borruso@ondata.it (Andrea Borruso)" "$folder"/feed.xml
#xmlstarlet ed -L --subnode "//channel" --type elem -n docs -v "$docs" "$folder"/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n creativeCommons:license -v "http://creativecommons.org/licenses/by-sa/4.0/" "$folder"/feed.xml

# leggo in loop i dati del file CSV e li uso per creare nuovi item nel file XML
newcounter=0
while IFS=$'\t' read -r URL title source pubDateRSS datetime; do
	newcounter=$(expr $newcounter + 1)
	xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
		--subnode "//item[$newcounter]" --type elem -n title -v "$title" \
		--subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
		--subnode "//item[$newcounter]" --type elem -n pubDate -v "$pubDateRSS" \
		--subnode "//item[$newcounter]" --type elem -n description -v "$title" \
		--subnode "//item[$newcounter]" --type elem -n guid -v "$guid" \
		--subnode "//item[$newcounter]" --type elem -n category -v "$source" -i "//item[$newcounter]/category[1]" -t "attr" -n "domain" -v "http://pti.regione.sicilia.it/portal/page/portal/PIR_PORTALE/RSSspecs#source" \
		"$folder"/feed.xml
done <"$folder"/RSS.tsv
