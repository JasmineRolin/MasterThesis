module TimeWindows

export TimeWindow,duration, copyTimewindow

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
function duration(tw::TimeWindow)::Int
    return tw.endTime - tw.startTime
end


function copyTimewindow(tw::TimeWindow)
    return TimeWindow(tw.startTime, tw.endTime)
end

end