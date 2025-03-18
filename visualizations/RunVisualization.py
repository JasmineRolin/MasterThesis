import pandas as pd
import Visualization as V


# Read data 
file_path = "/Users/jasminerolin/Documents/GitHub/MasterThesis/Data/Konsentra/TransformedData_Data.csv" #Data/Konsentra/TransformedData_Data.csv"
df = pd.read_csv(file_path)

# Initialize an empty dictionary for the customers
customers = {}

# Loop over the rows of the dataframe and populate the customers dictionary
for idx, row in df.iterrows():
    # Extract client-specific data (pickup and delivery)
    customer_id = row['id']  # You can use BookingID or ClientID depending on your needs
    pickup_coords = [row['pickup_latitude'], row['pickup_longitude']]
    delivery_coords = [row['dropoff_latitude'], row['dropoff_longitude']]

    # If the customer is not already in the dictionary, initialize them
    if str(customer_id) not in customers:
        customers[str(customer_id)] = {"pickup": pickup_coords, "delivery": delivery_coords}
    else:
        # Update with new delivery coordinates (if needed)
        customers[str(customer_id)]["pickup"] = pickup_coords
        customers[str(customer_id)]["delivery"] = delivery_coords


# Assign customers to busses
customerAssignment = {}

# # Depot location (shared starting point for all buses)
# Initialize an empty dictionary for the customers
depots = {}

file_path = "/Users/jasminerolin/Documents/GitHub/MasterThesis/Data/Konsentra/Vehicles_0.5.csv" #Data/Konsentra/Vehicles.csv"
df = pd.read_csv(file_path)

# Loop over the rows of the dataframe and populate the customers dictionary
for idx, row in df.iterrows():
    # Extract client-specific data (pickup and delivery)
    vehicle_id = int(row['id'])  # You can use BookingID or ClientID depending on your needs
    coords = [row['depot_latitude'], row['depot_longitude']]

    # Update with new delivery coordinates (if needed)
    depots[str(vehicle_id)] = {"loc":coords}

#depot = depots["1"]["loc"]

# Generate routes 
#routes = V.generateRoutes(customers,depot,customerAssignment)

# Run visualization 
# V.visualizeRoutes(customers,depot,routes)
V.visualizePickupsAndDeliveries(customers,depots)