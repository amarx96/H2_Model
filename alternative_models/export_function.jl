### some helper functions ###
# read the csv files
readcsv(x; dir=@__DIR__) = CSV.read(joinpath(dir, x), DataFrame, stringtype=String)
# readin function for parameters; this makes handling easier
readin(x::AbstractDataFrame; default=0,dims=1) = DefaultDict(default,Dict((dims > 1 ? Tuple(row[y] for y in 1:dims) : row[1]) => row[dims+1] for row in eachrow(x)))
readin(x::AbstractString; dir=@__DIR__, kwargs...) = readin(readcsv(x, dir=dir); kwargs...)


# generate result csv files from result data
function process_dataframes()
    # Create the DataFrames from Containers.rowtable
    df_qFuelSold = DataFrame(Containers.rowtable(value, qFuelSold; header = [:Supplier,:Industry,:Fuel,:Destination,:Origin,:Year,:Value]))
    df_qProcess= DataFrame(Containers.rowtable(value, qProcess; header = [:Industry,:Process,:Output, :Location, :Year, :Value]))

    df_qProcessFuelDemand = DataFrame(Containers.rowtable(value, qProcessFuelDemand; header = [:Industry, :Process, :Input, :Output, :Location, :Year, :Value]))
    df_qCO2ExMarket= DataFrame(Containers.rowtable(value, qCO2ExMarket; header = [:Industry,:Location,:Year,:Value]))
    
    df_qAccCapacity= DataFrame(Containers.rowtable(value, qAccCapacity; header = [:Industry,:Process, :Location, :Year, :Value]))
    df_qNewCapacity= DataFrame(Containers.rowtable(value, qNewCapacity; header = [:Industry,:Process, :Location, :Year, :Value]))

    
    df_qAccCapacity= DataFrame(Containers.rowtable(value, qAccCapacity; header = [:Industry,:Process, :Location, :Year, :Value]))
    df_qNewCapacity= DataFrame(Containers.rowtable(value, qNewCapacity; header = [:Industry,:Process, :Location, :Year, :Value]))
    
    df_qFuelImports= DataFrame(Containers.rowtable(value, qFuelImports; header = [:Industry,:Supplier,:Fuel, :Destination,:Origin,:Mode,:Year, :Value]))
    df_qFuelExports= DataFrame(Containers.rowtable(value, qFuelExports; header = [:Supplier,:Industry,:Fuel, :Origin,:Destination,:Mode,:Year, :Value]))
    df_qExportNewCapacity= DataFrame(Containers.rowtable(value, qExportNewCapacity; header = [:Supplier,:Industry,:Fuel,:Origin,:Destination,:Mode,:Year, :Value]))
    df_qExportAccCapacity= DataFrame(Containers.rowtable(value, qExportAccCapacity; header = [:Supplier,:Industry,:Fuel,:Origin,:Destination,:Mode,:Year, :Value]))
    
end

function write_result_csvs()
    results_filepath = mkpath("C:\\Users\\alex-\\Desktop\\09_11_Rechenkern\\_code\\results")


    # write results to results directory in csv files
    CSV.write(joinpath(results_filepath, "df_qFuelSold.csv"), qFuelSold)
    CSV.write(joinpath(results_filepath, "qProcess.csv"), df_qProcess)
    CSV.write(joinpath(results_filepath, "qProcessFuelDemand.csv"), df_qProcessFuelDemand)
    CSV.write(joinpath(results_filepath, "df_qCO2ExMarket.csv"), df_qCO2ExMarket)

    CSV.write(joinpath(results_filepath, "df_qAccCapacity.csv"), df_qAccCapacity)
    CSV.write(joinpath(results_filepath, "df_qNewCapacity.csv"), df_qNewCapacity)

    CSV.write(joinpath(results_filepath, "df_qFuelImports.csv"), df_qFuelImports)
    CSV.write(joinpath(results_filepath, "df_qFuelExports.csv"), df_qFuelExports)
    CSV.write(joinpath(results_filepath, "df_qFuelExports.csv"), df_qExportNewCapacity)
    CSV.write(joinpath(results_filepath, "df_qFuelExports.csv"), qExportAccCapacity)


    print("Successfully wrote CSVs to the result folder :)")
end