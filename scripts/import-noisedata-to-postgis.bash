#!/bin/bash
#
# This is a quick proof of concept. Please read it thorugh before running.
#
# Author: Markus Koskinen
#
# Enable PostGIS in pg and export postgres credentials in format as follows:
# POSTGRES_CREDENTIALS="host=noisedata.postgis-example.com port=5432 user='postgres' password='secret' dbname='noisedata'"

# export all the points.geojson files in workdir to PostGIS
function points_gis_export_loop()
{
  SAVEIFS=$IFS
  IFS=$(echo -en "\n\b")

  for pointsfile in $(ls -1 ./workdir/*points.geojson)
  do
    echo "Handling pointsfile: ${pointsfile}"

    # Insert geojsons to PostGIS   
    ogr2ogr -f PostgreSQL PG:"${POSTGRES_CREDENTIALS}" "${pointsfile}" -nln noisedata
    rm "${pointsfile}"
  done
  IFS=$SAVEIFS
}

# Clean up old directories
rm -rf ./workdir/
mkdir ./workdir

# Get the zipfiles
rm -rf ./data.noise-planet.org
wget -r -np -R "index.html*" https://data.noise-planet.org/noisecapture/

# They will endup in a subdir ./data.noise-planet.org/noisecapture/

# From there lets extract one zip at a time to ./workdir/

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

for zfile in $(ls -1 ./data.noise-planet.org/noisecapture/*.zip)
do
  echo "Handling zipfile: ${zfile}"
  unzip "${zfile}" "*points*" -d ./workdir/

  # Insert
  if [ $? -eq 0 ]; then
    points_gis_export_loop
  fi
  rm "${zfile}"
done

IFS=$SAVEIFS

