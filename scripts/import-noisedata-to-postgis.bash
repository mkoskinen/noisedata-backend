#!/bin/bash
#
# This is a quick proof of concept. Please read it thorugh before running.
# Please also conserve the noisedata bandwidth as well as you can.
#
# Author: Markus Koskinen
# License: BSD
#
# Enable PostGIS in pg and export postgres credentials in format as follows (we need both for now):
#
# export POSTGRES_CREDENTIALS="host=noisedata.postgis-example.com port=5432 user='markus' password='secret' dbname='noisedata'"
# export POSTGRES_URI="postgres://markus:secret@localhost:5432/noisedata"

function time_fun()
{
  /bin/time -f '%E real,%U user,%S sys' $*
}

# remove duplicates and over 1y old entries from the tmp_table then copy data to the main table
function tmp_table_cleanup_and_copy()
{
  echo "Deleting over 1y old data from temporary table ..."
  time_fun psql $POSTGRES_URI -c "DELETE FROM tmp_noisedata WHERE time_iso8601 < (current_date - interval '12 months');"
  echo "Deleting non-latest duplicate coordinate entries from temporary table ..."
  time_fun psql $POSTGRES_URI -c "DELETE FROM tmp_noisedata tmp1 using tmp_noisedata tmp2 WHERE tmp1.time_iso8601 < tmp2.time_iso8601 AND tmp1.wkb_geometry = tmp2.wkb_geometry;"
  echo "Initial noisedata table create. This not elegant and will error often."
  psql $POSTGRES_URI -c "CREATE TABLE IF NOT EXISTS noisedata AS SELECT * FROM tmp_noisedata;"
  echo "Copy tmp_noisedata to noisedata ..."
  psql $POSTGRES_URI -c "INSERT INTO noisedata(time_iso8601,time_epoch,time_gps_iso8601,time_gps_epoch,noise_level,accuracy,wkb_geometry) SELECT time_iso8601,time_epoch,time_gps_iso8601,time_gps_epoch,noise_level,accuracy,wkb_geometry FROM tmp_noisedata;"
  echo "Dropping tmp table and vacuuming ..."
  psql $POSTGRES_URI -c "DROP TABLE tmp_noisedata;"
  psql $POSTGRES_URI -c "VACUUM;"
}

# export all the points.geojson files in workdir to PostGIS
function points_gis_export_loop()
{
  SAVEIFS=$IFS
  IFS=$(echo -en "\n\b")

  for pointsfile in $(ls -1 ./workdir/*points.geojson)
  do
    echo "Handling pointsfile: ${pointsfile}"

    # Insert geojsons to PostGIS   
    time_fun ogr2ogr -f PostgreSQL PG:"${POSTGRES_CREDENTIALS}" "${pointsfile}" -nln tmp_noisedata
    tmp_table_cleanup_and_copy
    rm "${pointsfile}"
  done
  IFS=$SAVEIFS
}

# Handle the zip files in ./data.noise-planet.org/noisecapture/, extract one zip at a time to ./workdir/
function zip_extraction_loop()
{
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
    # Let's see if we can rely on wget's -N and not have redundant downloads
    #rm "${zfile}"
  done

  IFS=$SAVEIFS
}

# Check for ogr2ogr
which ogr2ogr > /dev/null
if [ $? -ne 0 ]; then
  echo "Error: Missing ogr2ogr binary, please install it first."
fi

# Clean up old directories, drop old database.
echo "Clean up working directories ..."
rm -rf ./workdir/
mkdir ./workdir
echo "Dropping old noisedata ..."
psql $POSTGRES_URI -c "DROP TABLE IF EXISTS noisedata;"
psql $POSTGRES_URI -c "DROP TABLE IF EXISTS tmp_noisedata;"

echo "Initialize main table ..."
# Import a small file to init the main table (assuming run location)
ogr2ogr -f PostgreSQL PG:"${POSTGRES_CREDENTIALS}" data/Algeria_Oran_Arzew.points.geojson -nln noisedata

# Get the zipfiles
# rm -rf ./data.noise-planet.org
# -N newer only, -c continue interrupted - check this works
wget -c -N -r -np -R "index.html*" https://data.noise-planet.org/noisecapture/

echo $$ :: import start :: $(date) >> startstop.log

zip_extraction_loop

echo $$ :: import end :: $(date) >> startstop.log
