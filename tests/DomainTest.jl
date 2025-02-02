using Test 
using Dates
using domain 

#==
 Test all domain modules
==#

#==
 Test Location 
==#
@testset "Location test" begin
    location = Location("test",1,1)

    # Tests
    @test typeof(location) == Location
    @test location.name == "test"
end


#==
 Test time window  
==#
@testset "TimeWindow test" begin
    tw = TimeWindow(DateTime(2025,01,01,14,45),DateTime(2025,01,01,15,45))

    # Tests
    @test typeof(tw) == TimeWindow
    @test duration(tw) == 60*60
end

#==
TODO: add test of request
==#