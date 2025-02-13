module Activities

using ..TimeWindows, ..Locations, ..Enums

export Activity

struct Activity 
    id::Int 
    requestId::Int 
    activityType::ActivityType
    mobilityType::MobilityType
    location::Location 
    timeWindow::TimeWindow
end


end