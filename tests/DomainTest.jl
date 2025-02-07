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
    tw = TimeWindow(8*60,8*60+45)

    # Tests
    @test typeof(tw) == TimeWindow
    @test duration(tw) == 45
end

#==
TODO: add test of request
==#