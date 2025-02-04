
module TimeUtils

using Dates 

export minutesSinceMidnight

#==
 Methods that finds minutes since midnight 
 Input should be in format HH:MM:ss,  H:MM or HH:MM
==#
function minutesSinceMidnight(timeStr::String)::Int
    # Strip leading/trailing spaces
    timeStr = strip(timeStr)
    
    # Split the time into components (either 2 or 3 parts)
    timeParts = split(timeStr, ":")
    
    # Parse the components (Hours, Minutes, and optionally Seconds)
    if length(timeParts) == 2
        # If there are two components (HH:MM), assume seconds as 0
        h, m = parse(Int, timeParts[1]), parse(Int, timeParts[2])
        s = 0
    elseif length(timeParts) == 3
        # If there are three components (HH:MM:SS), parse all
        h, m, s = parse(Int, timeParts[1]), parse(Int, timeParts[2]), parse(Int, timeParts[3])
    else
        throw(ArgumentError("Invalid time format"))
    end

    # Convert time to minutes since midnight
    totalMinutes = h * 60 + m + s / 60
    return totalMinutes
end





end 