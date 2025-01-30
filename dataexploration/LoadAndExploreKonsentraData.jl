using XLSX
using DataFrames

# Open file 
df = DataFrame(XLSX.readtable("Data/Konsentra/Data.xlsx", "Data"))
df[!,"Age"] = Int8.(df[!,"Age"])

# How many requests are for adults? 
ageLimit = 18 
nAgeAboveLimit = sum(df[!,"Age"] >= ageLimit)
