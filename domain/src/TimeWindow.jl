module TimeWindows

export TimeWindow,duration

mutable struct TimeWindow
    startTime::Int
    endTime::Int

    function TimeWindow(startTime::Int,endTime::Int)
        if endTime < startTime
            throw(ArgumentError(string("End time window should be after start: start=",startTime," end=",endTime)))
        else
            return new(startTime,endTime)
        end
    end
end


#==
 Duration of time window in seconds
==#
function duration(tw::TimeWindow)::Integer
    return tw.endTime - tw.startTime
end


end