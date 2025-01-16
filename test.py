import dash
from dash import html, dcc, Input, Output, State
import dash_leaflet as dl
import requests

# Function to fetch road-following routes from OSRM
def fetch_route_osrm(start, end):
    """Fetch a route from OSRM between start and end coordinates."""
    url = f"http://router.project-osrm.org/route/v1/driving/{start[1]},{start[0]};{end[1]},{end[0]}?overview=full&geometries=geojson"
    response = requests.get(url).json()
    coords = response["routes"][0]["geometry"]["coordinates"]
    # Convert to (lat, lon) format for Leaflet
    return [(lat, lon) for lon, lat in coords]

# Depot location (shared starting point for all buses)
depot = [55.6761, 12.5683]

# Customers with pickup and delivery points
customers = {
    "1": {"pickup": [55.6761, 12.5683], "delivery": [55.680, 12.573]},
    "2": {"pickup": [55.678, 12.570], "delivery": [55.672, 12.560]},
    "3": {"pickup": [55.675, 12.566], "delivery": [55.674, 12.564]},
    "4": {"pickup": [55.677, 12.562], "delivery": [55.678, 12.570]},
    "5": {"pickup": [55.680, 12.567], "delivery": [55.681, 12.569]},
}

# Assigning multiple customers to one bus (bus_1)
bus_1_customers = ["1", "3", "5"]

# Generate routes for each bus
routes = {
    # Route for bus_1 with multiple customers
    "bus_1": (
        [depot]
        + sum(
            [
                fetch_route_osrm(
                    customers[bus_1_customers[i - 1]]["delivery"] if i > 0 else depot,
                    customers[customer]["pickup"],
                )
                + fetch_route_osrm(
                    customers[customer]["pickup"], customers[customer]["delivery"]
                )
                for i, customer in enumerate(bus_1_customers)
            ],
            [],
        )
    ),
    # Routes for other buses (one customer each)
    "bus_2": [depot] + fetch_route_osrm(customers["2"]["pickup"], customers["2"]["delivery"]),
    "bus_3": [depot] + fetch_route_osrm(customers["4"]["pickup"], customers["4"]["delivery"]),
}

# Generate slider frames for key points (depot, pickups, deliveries)
slider_frames = sorted(set(
    frame
    for route in routes.values()
    for frame in [0, len(route) - 1]  # Start and end of each route
))

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
if __name__ == "__main__":
    app.run_server(debug=True)
