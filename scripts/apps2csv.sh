#!/bin/bash
#      ^ ensure it is executed by the BASH and no other shell link to /bin/sh

# quick and dirty shell script to look up ".components" files, parse them and 
# write the found application-to-cartridge dependencies to a CSV file

echo "Usage: apps2csv.sh [<start dir> [<output csv file>]]"

if ! [ -x "$(command -v xmllint)" ]; then
  echo 'Error: xmllint (from package libxml2-utils) is required but not installed.' >&2
  exit 1
fi

STARTDIR=${1:-$ICM_BASE_DIR}
DEFAULTDIR="${EXPORT_DIR:-.}"
DEFAULTTARGET="$DEFAULTDIR/apps.csv"
TARGET="${2:-$DEFAULTTARGET}"

FILENAME=$(basename -- $TARGET)
DIR=$(dirname -- $TARGET)
EXTENSION="${FILENAME##*.}"
FILENAME="${FILENAME%.*}"
SUBPROVIDER_TARGET="$DIR/$FILENAME-sub.$EXTENSION"

echo "STARTDIR: $STARTDIR ; TARGET: $TARGET"

echo "assigner,application,dependencies,isOptional,isExtension" > $TARGET
echo "assigner,application,dependency" > $SUBPROVIDER_TARGET

for DESC in $(find $STARTDIR -name '*.component' -not -path "*/META-INF/*"); do
   # determin cartridge name from path
   ASSIGNER=$(grep -Po '(?<=/)\w+(?=/staticfiles)' <<< "$DESC")
   # find all CartridgeListProvider in component file
   LIST_PROVIDERS_XML="$(sed 's/xmlns=".*"//g' $DESC | xmllint --xpath //instance\[@with=\"CartridgeListProvider\"\] - 2>/dev/null)"

   if [ ! -z "$LIST_PROVIDERS_XML" ]; then
      LIST_PROVIDERS_XML="<apps>$LIST_PROVIDERS_XML</apps>"

      regCount=$(xmllint --xpath 'count(//instance[@with="CartridgeListProvider"])' - <<< "$LIST_PROVIDERS_XML")
      for ((i=1; i<=regCount; i++)); do
         LIST_PROVIDER_XML=$(xmllint --xpath '(//instance)['"$i"']' - <<< "$LIST_PROVIDERS_XML")
         APP=$(xmllint --xpath 'string(//@name)' - <<< "$LIST_PROVIDER_XML" 2>/dev/null | sed 's/^intershop\.//' | sed 's/\.Cartridges$//' )
         
         if [ ! -z "$APP" ]; then

            CARTRIDGES=$(xmllint --xpath '//instance/fulfill[@requirement="selectedCartridge"]/@value' - <<< "$LIST_PROVIDER_XML" 2>/dev/null | grep -Po '(?<=\")\w+(?=\")' | tr '\n' ':' | sed 's/:$/\n/')
            if [ ! -z "$CARTRIDGES" ]; then
               echo -e "$ASSIGNER,$APP,$CARTRIDGES,false,false" >> $TARGET
            fi
            OPTIONALS=$(xmllint --xpath '//instance/fulfill[@requirement="optionalCartridge"]/@value' - <<< "$LIST_PROVIDER_XML" 2>/dev/null | grep -Po '(?<=\")\w+(?=\")' | tr '\n' ':' | sed 's/:$/\n/')
            if [ ! -z "$OPTIONALS" ]; then
               echo -e "$ASSIGNER,$APP,$OPTIONALS,true,false" >> $TARGET
            fi
            SUB_PROVIDERS=$(xmllint --xpath '//instance/fulfill[@requirement="subProvider"]/@with' - <<< "$LIST_PROVIDER_XML" 2>/dev/null | grep -Po '(?<=\.).+(?=\")' | tr '\n' ':' | sed 's/:$/\n/')
            if [ ! -z "$SUB_PROVIDERS" ]; then
               echo -e "$ASSIGNER,$APP,$SUB_PROVIDERS" >> $SUBPROVIDER_TARGET
            fi
         fi
      done 
   fi

   EXT_LIST_XML="$(sed 's/xmlns=".*"//g' $DESC | xmllint --xpath '/components/fulfill[@requirement="selectedCartridge"][@of]' - 2>/dev/null)"
   if [ ! -z "$EXT_LIST_XML" ]; then
      EXT_LIST_XML="<ext>$EXT_LIST_XML</ext>"
      regCount=$(xmllint --xpath 'count(/ext/fulfill[@requirement="selectedCartridge"][@of])' - <<< "$EXT_LIST_XML")
      for ((i=1; i<=regCount; i++)); do
         EXT_XML=$(xmllint --xpath '(/ext/fulfill)['"$i"']' - <<< "$EXT_LIST_XML")
         EXT_APP=$(xmllint --xpath 'string(/fulfill/@of)' - <<< "$EXT_XML" 2>/dev/null | sed 's/^intershop\.//' | sed 's/\.Cartridges$//' )
         EXT_CARTRIDGE=$(xmllint --xpath 'string(/fulfill/@value)' - <<< "$EXT_XML" 2>/dev/null )
         if [ ! -z "$EXT_APP" ] && [ ! -z "$EXT_CARTRIDGE" ]; then
            echo -e "$ASSIGNER,$EXT_APP,$EXT_CARTRIDGE,false,true" >> $TARGET
         fi
      done
     
   fi
done
