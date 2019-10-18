from flask import Flask
from flask_restful import Resource, Api

app = Flask(__name__)
api = Api(app)

class NoisedataByCoordinates(Resource):
    """ Something like GET /api/v1/noise/60.165249,24.936056 should return the noisedata from the closest location """
    def get(self, coordinates_string):
        return {'asking for': coordinates_string}

api.add_resource(NoisedataByCoordinates, '/api/v1/noise/<string:coordinates_string>')

if __name__ == '__main__':
    app.run(debug=True)

