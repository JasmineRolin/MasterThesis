module GenericMethods

export GenericMethod

#==
 Struct to describe destroy or repair method 
==#
struct GenericMethod
    name::String 
    method::Function
end


end