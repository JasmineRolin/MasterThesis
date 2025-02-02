# Function to run all tests in the specified directory
function run_all_tests_in_directory(test_dir::String)
    test_files = filter(x -> endswith(x, ".jl"), readdir(test_dir))  # Only find .jl files
    included_files = Set()  # Keep track of already included files
    
    for file in test_files
        file_path = joinpath(test_dir, file)
        
        # If the file has not been included already, include it
        if !(file_path in included_files)
            println("Running test: $file_path")
            include(file_path)
            push!(included_files, file_path)  # Mark this file as included
        else
            println("Skipping already included test: $file_path")
        end
    end
end

# Run all tests from the "tests" directory
run_all_tests_in_directory(joinpath(pwd(), "tests"))
