import pandas as pd
import Visualization as V


# Read data 
file_path = "Data/Konsentra/Data.xlsx"
df = pd.read_excel(file_path, engine='openpyxl')

# Initialize an empty dictionary for the customers
customers = {}

# Loop over the rows of the dataframe and populate the customers dictionary
for idx, row in df.iterrows():
    if row["Age"] >= 18:
        # Extract client-specific data (pickup and delivery)
        customer_id = row['ClientID']  # You can use BookingID or ClientID depending on your needs
        pickup_coords = [row['From LAT'], row['From LON']]
        delivery_coords = [row['To LAT'], row['To LON']]

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
depot = [55.6761, 12.5683]

# Generate routes 
routes = V.generateRoutes(customers,depot,customerAssignment)

# Run visualization 
# V.visualizeRoutes(customers,depot,routes)
V.visualizePickupsAndDeliveries(customers,depot)