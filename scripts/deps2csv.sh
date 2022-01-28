#!/bin/bash
#      ^ ensure it is executed by the BASH and no other shell link to /bin/sh

# quick and dirty shell script to look up "cartridge.descriptor" files, parse then and 
# write the found dependencies to a CSV file

if [ "$#" -ne 2 ]
then
  echo "Usage: deps2csv.sh <start dir> <output csv file>"
  echo ""
  exit 1
fi

STARTDIR=$1
TARGET=$2
PROPERTY="cartridge.dependsOn"

echo "cartridge,dependencies" >> $TARGET
for DESC in $(find $STARTDIR -name 'cartridge.descriptor' -not -path "*/META-INF/*")
do
  # echo "$DESC"
  NAME=`sed -n -E "s/^cartridge\.name=(.*)$/\1/p" $DESC`
  DEPS=`sed -n -E "s/^$PROPERTY=(.*)/\1/p" $DESC | sed -E "s/;/:/g"`
  echo -e "$NAME,$DEPS" >> $TARGET
done
