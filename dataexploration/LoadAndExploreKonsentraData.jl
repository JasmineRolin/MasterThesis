using XLSX
using DataFrames
using Plots
using Dates
using utils

# Open file 
df = DataFrame(XLSX.readtable("Data/Konsentra/Data.xlsx", "Data"))
df[!,"Age"] = Int8.(df[!,"Age"]) # convert age to int 

df[!,"ReqTime"] = minutesSinceMidnight.(string.(df[!,"ReqTime"]))


# Stats 
nRequests = nrow(df)


#==
 Information about age of customers
==#
# How many requests are for adults? 
ageLimit = 18 
nAboveAgeLimit = sum(df[!,"Age"] .>= ageLimit)

# Display 
display = DataFrame(
    rows = ["No. requests","No. request above age $ageLimit"],
    results = [nRequests,nAboveAgeLimit]
)

println(display)

# Create histogram of ages
ageHistogram = plot(histogram(df[!,"Age"], bins=10, color=:skyblue, xlabel="Age", ylabel="Count", title="Age Distribution"))


#==
 Information about pickups 
==# 
# Create histogram of request times for pick up activities 
pickupTimeHistogram = plot(histogram(df[!,"ReqTime"], bins=10, color=:skyblue, xlabel="Minutes since midnigth", ylabel="Count", title="Minutes since midnigth"))


#==
 Display
==#
