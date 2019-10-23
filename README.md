# noisedata-backend
A simple backend for accessing noisedata from noise-planet.org

# Import script - scripts/import-noisedata-to-postgis.bash

A script to import the noiseplanet zipfiles to postgis. This will run for a long time (eg 2 days) - the duplicate removal is slow.

You need to install GDAL 2+, for the ogr2ogr tool - it seems to be packaged in at least Fedora 30 and Ubuntu 18.

Also export both these variables

export POSTGRES_CREDENTIALS="host=noisedata.postgis-example.com port=5432 user='markus' password='secret' dbname='noisedata'"
export POSTGRES_URI="postgres://markus:secret@localhost:5432/noisedata"

This script will download ~1,5 GB zips, extract them, clean them up and import to postgres.

# REST API - flask-api/flask-app.py

This is still WIP. But install requirements.txt and run with python3.
The one endpoint will give you the closest point and the data associated with it
in the database - based on the coordinates that you give it.


