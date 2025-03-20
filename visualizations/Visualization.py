import dash
from dash import html, dcc, Input, Output, State
import dash_leaflet as dl
import requests

 # Bus icon (common for all buses)
bus_icon = {
    "iconUrl": "https://cdn-icons-png.flaticon.com/512/6955/6955518.png",  # Bus icon
    "iconSize": [40, 40],  # Icon size
    "iconAnchor": [20, 20],  # Center of the icon
}

# Icon URLs for depot, pickup, and delivery points
depot_icon_url = "https://cdn-icons-png.flaticon.com/512/1946/1946488.png"  # Depot icon
pickup_icon_url = "https://cdn-icons-png.flaticon.com/512/1946/1946412.png"  # Pin icon
delivery_icon_url = "https://cdn-icons-png.flaticon.com/512/684/684908.png"  # Package icon


# Function to fetch road-following routes from OSRM
def fetch_route_osrm(start, end):
    """Fetch a route from OSRM between start and end coordinates."""
    url = f"http://router.project-osrm.org/route/v1/driving/{start[1]},{start[0]};{end[1]},{end[0]}?overview=full&geometries=geojson"
    response = requests.get(url).json()
    coords = response["routes"][0]["geometry"]["coordinates"]
    # Convert to (lat, lon) format for Leaflet
    return [(lat, lon) for lon, lat in coords]



def generateRoutes(customers, depot, customerAssignment):
    # Initialize routes dictionary
    routes = {}

    # Iterate through each bus and its assigned customers
    for bus, assigned_customers in customerAssignment.items():
        # Start route from depot
        route = [depot]

        # Generate routes for assigned customers
        for i, customer in enumerate(assigned_customers):
            # Get pickup and delivery points
            pickup = customers[customer]["pickup"]
            delivery = customers[customer]["delivery"]

            # Add route from previous delivery (or depot if first customer) to pickup
            prev_location = route[-1]
            route += fetch_route_osrm(prev_location, pickup)

            # Add route from pickup to delivery
            route += fetch_route_osrm(pickup, delivery)

        # Store computed route
        routes[bus] = route

    return routes



def visualizeRoutes(customers,depot,routes):
    # Generate slider frames for key points (depot, pickups, deliveries)
    slider_frames = sorted(set(
        frame
        for route in routes.values()
        for frame in [0, len(route) - 1]  # Start and end of each route
    ))

    # Layout
    app = dash.Dash(__name__)
    app.layout = html.Div([
        html.H1("Buses Starting from Depot with Pickup and Delivery Points"),
        dl.Map(
            center=[55.6761, 12.5683], zoom=12,
            children=[
                dl.TileLayer(),  # Add OpenStreetMap tiles
                # Add depot marker
                dl.Marker(
                    position=depot,
                    children=[dl.Popup("Depot")],
                    icon={
                        "iconUrl": depot_icon_url,
                        "iconSize": [30, 30],
                        "iconAnchor": [15, 30],
                    },
                ),
                # Add route lines for each bus
                *[
                    dl.Polyline(
                        positions=route,
                        color="blue" if bus == "bus_1" else "green" if bus == "bus_2" else "orange",
                        weight=4,
                        opacity=0.7,
                    )
                    for bus, route in routes.items()
                ],
                # Add pickup points
                *[
                    dl.Marker(
                        position=data["pickup"],
                        children=[dl.Popup(f"Pickup {customer}")],
                        icon={
                            "iconUrl": pickup_icon_url,
                            "iconSize": [30, 30],
                            "iconAnchor": [15, 30],
                        },
                    )
                    for customer, data in customers.items()
                ],
                # Add delivery points
                *[
                    dl.Marker(
                        position=data["delivery"],
                        children=[dl.Popup(f"Delivery {customer}")],
                        icon={
                            "iconUrl": delivery_icon_url,
                            "iconSize": [30, 30],
                            "iconAnchor": [15, 30],
                        },
                    )
                    for customer, data in customers.items()
                ],
                # Add bus markers (LayerGroup to update dynamically)
                dl.LayerGroup(id="bus-markers"),
            ],
            style={"height": "600px", "width": "100%"},
        ),
        dcc.Slider(
            id="time-slider",
            min=0,
            max=len(slider_frames) - 1,
            step=1,
            value=0,
            marks={i: f"Event {i+1}" for i in range(len(slider_frames))},
        ),
        html.Div([
            html.Button("Play", id="play-button", n_clicks=0, style={"margin-right": "10px"}),
            html.Button("Pause", id="pause-button", n_clicks=0),
        ], style={"margin": "20px 0"}),
        dcc.Interval(id="interval", interval=1000, n_intervals=0, disabled=True),  # Animation timer
    ])

    # Callback to update bus positions
    @app.callback(
        Output("bus-markers", "children"),
        Input("time-slider", "value"),
    )

    def update_bus_positions(frame):
        # Get the frame index from slider_frames
        actual_frame = slider_frames[frame]
        # Update the bus markers based on the frame
        bus_markers = []
        for bus, route in routes.items():
            if actual_frame < len(route):
                bus_position = route[actual_frame]
                bus_markers.append(
                    dl.Marker(
                        position=bus_position,
                        icon=bus_icon,
                        children=[dl.Popup(f"{bus}")],
                    )
                )
        return bus_markers


    # Callback to control the play/pause functionality
    @app.callback(
        Output("interval", "disabled"),
        [Input("play-button", "n_clicks"), Input("pause-button", "n_clicks")],
        State("interval", "disabled"),
    )
    def control_play_pause(play_clicks, pause_clicks, disabled):
        ctx = dash.callback_context
        if not ctx.triggered:
            return disabled
        trigger_id = ctx.triggered[0]["prop_id"].split(".")[0]
        if trigger_id == "play-button":
            return False  # Enable the interval
        elif trigger_id == "pause-button":
            return True  # Disable the interval
        return disabled


    # Callback to update the slider value based on the interval
    @app.callback(
        Output("time-slider", "value"),
        [Input("interval", "n_intervals")],
        [State("time-slider", "value"), State("time-slider", "max")],
    )
    def update_slider_on_interval(n_intervals, current_value, max_value):
        if current_value < max_value:
            return current_value + 1
        return 0  # Reset to the beginning when reaching the end


    # Run the app
    #if __name__ == "__main__":
    app.run_server(debug=True)


def visualizePickupsAndDeliveries(customers, depots):
    # Calculate the average coordinates of the delivery points to center the map
    delivery_points = [data["delivery"] for data in customers.values()]
    avg_lat = sum([point[0] for point in delivery_points]) / len(delivery_points)
    avg_lon = sum([point[1] for point in delivery_points]) / len(delivery_points)
    center = [avg_lat, avg_lon]  # Center map on the average of delivery points

    # Layout
    app = dash.Dash(__name__)
    app.layout = html.Div([
        html.H1("Pickup and Delivery Points"),
        dl.Map(
            center=center,  # Center map on the delivery points
            zoom=12,
            children=[
                dl.TileLayer(),  # Add OpenStreetMap tiles
                # Add depot marker
                *[dl.Marker(
                    position=data["loc"],
                    children=[dl.Popup("Depot {depot}")],
                    icon={
                        "iconUrl": depot_icon_url,
                        "iconSize": [30, 30],
                        "iconAnchor": [15, 30],
                    },
                )
                 for depot,data in depots.items()
                ],
                # Add pickup points
                *[
                    dl.Marker(
                        position=data["pickup"],
                        children=[dl.Popup(f"Pickup {customer}")],
                        icon={
                            "iconUrl": pickup_icon_url,
                            "iconSize": [30, 30],
                            "iconAnchor": [15, 30],
                        },
                    )
                    for customer, data in customers.items()
                ],
                # Add delivery points
                *[
                    dl.Marker(
                        position=data["delivery"],
                        children=[dl.Popup(f"Delivery {customer}")],
                        icon={
                            "iconUrl": delivery_icon_url,
                            "iconSize": [30, 30],
                            "iconAnchor": [15, 30],
                        },
                    )
                    for customer, data in customers.items()
                 ],
            ],
            style={"height": "600px", "width": "100%"},
        ),
    ])

    # Run the app
    app.run_server(debug=True)
