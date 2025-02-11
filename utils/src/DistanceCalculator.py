# Functions to fetch routes, distance and travel times from OSM #

import requests

# Method to fetch route, distance and travel time 
def fetch_route_osrm(start, end):
    """Fetch route, distance, and duration from OSRM."""
    url = f"http://router.project-osrm.org/route/v1/driving/{start[1]},{start[0]};{end[1]},{end[0]}?overview=full&geometries=geojson"
    response = requests.get(url).json()

    route = [(lat, lon) for lon, lat in response["routes"][0]["geometry"]["coordinates"]]
    distance_m = response["routes"][0]["distance"]  # Distance in meters
    duration_min = response["routes"][0]["duration"] / 60  # travel time in minutes 

    return route, distance_m, duration_min


# Method to fetch distance and travel time 
def fetch_distance_travel_time_osrm(start, end):
    """Fetch route, distance, and duration from OSRM."""
    url = f"http://router.project-osrm.org/route/v1/driving/{start[1]},{start[0]};{end[1]},{end[0]}?overview=full&geometries=geojson"
    response = requests.get(url).json()

    distance_m = response["routes"][0]["distance"]  # Distance in meters
    duration_min = response["routes"][0]["duration"] / 60  # travel time in minutes 

    return distance_m, duration_min
