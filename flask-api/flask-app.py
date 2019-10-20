import datetime
import json
import logging
import os
import sys
import time

from flask import Flask
from flask_restful import Resource, Api

import psycopg2

app = Flask(__name__)
api = Api(app)

_LOG_FORMAT = "%(asctime)s\t%(levelname)s\t%(module)s\t%(message)s"
_DEBUG = False

_CONNECT_RETRY_SECONDS = 15
_REQUIRED_ENV_VARS = ['POSTGRES_URI']


def test_postgres_connection():
    """ Initialize a postgres connection. """
    logging.info("Testing Postgres connection ...")

    db_conn = None
    while db_conn is None:
        try:
            db_conn = psycopg2.connect(os.environ['POSTGRES_URI'])
            cursor = db_conn.cursor()
            cursor.execute("SELECT version();")
            pg_version = cursor.fetchone()
            logging.info("Connected to %s.", pg_version)
        except psycopg2.Error as pg_error:
            logging.error("Cannot connect to Postgres: '%s'. Retrying in %d seconds.", pg_error, _CONNECT_RETRY_SECONDS)
            time.sleep(_CONNECT_RETRY_SECONDS)
        finally:
            if db_conn:
                db_conn.close()

class DateEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime.date):
            return str(obj)
        return json.JSONEncoder.default(self, obj)

def get_closest_noisedata_by_coordinates(latitude, longitude):
    with psycopg2.connect(os.environ['POSTGRES_URI']) as pg_conn:
        with pg_conn.cursor() as cursor:
            sql = """SELECT time_iso8601,
                            noise_level,
                            ST_AsText(Geography(ST_Transform(ST_Force2D(wkb_geometry),4326))) as geo_coords, 
                            ST_Distance(Geography(ST_Transform(wkb_geometry,4326)), ST_GeographyFromText('POINT(%s %s)')) as distance
                       FROM noisedata
                       WHERE noisedata.time_iso8601 > (current_date - interval '6 months')
                       ORDER BY distance ASC
                       LIMIT 1;""" 
            cursor.execute(sql, (longitude, latitude,))
            result = cursor.fetchone()
            logging.info("Query result: %s", result)
            return json.dumps(result, cls=DateEncoder)

class NoisedataByCoordinates(Resource):
    """ Something like GET /api/v1/noise/60.165249,24.936056 should return the noisedata from the closest location """
    def get(self, coordinates_string):
        # WARNING: Add checks here
        latitude, longitude = coordinates_string.split(",")
        latitude, longitude = (round(float(latitude), 5), round(float(longitude), 5))

        return {
                  'asking for'  : coordinates_string,
                  'floats'	: "{} {}".format(latitude, longitude),
                  'result'      : get_closest_noisedata_by_coordinates(latitude, longitude)
               }

api.add_resource(NoisedataByCoordinates, '/api/v1/noise/<string:coordinates_string>')

if __name__ == '__main__':

    for env_var in _REQUIRED_ENV_VARS:
        if not env_var in os.environ:
            logging.error("You are missing required environment variable '%s'. Exiting.", env_var)
            sys.exit(1)

    test_postgres_connection()
    app.run(debug=True)

