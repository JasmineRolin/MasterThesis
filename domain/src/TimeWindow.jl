module TimeWindows

export TimeWindow,duration

struct TimeWindow
    startTime::Int
    endTime::Int

    function TimeWindow(startTime::Int,endTime::Int)
        if endTime <= startTime
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
    return tw.endTime - tw.startTime
end


end