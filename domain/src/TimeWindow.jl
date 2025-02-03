module TimeWindows

using Dates

export TimeWindow,duration

struct TimeWindow
    startTime::DateTime
    endTime::DateTime

    function TimeWindow(startTime::DateTime,endTime::DateTime)
        if Dates.value(endTime - startTime) < 0
            throw(ArgumentError("End time window should be after start"))
        else
            return new(startTime,endTime)
        end
    end
end


#==
 Duration of time window in seconds
==#
function duration(tw::TimeWindow)::Integer
    return (tw.endTime - tw.startTime)/Second(1)
end


end