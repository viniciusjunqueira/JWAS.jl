using Distributions
using DataFrames
using ProgressMeter
using .PedModule

include("types.jl")
include("printout.jl")
include("solver.jl")
include("random_effects.jl")
include("build_MME.jl")
include("residual.jl")
include("MCMC/MCMC.jl")
include("markers/markers.jl")
include("variance.jl")
include("Pi.jl")

include("pipeline/LOOCV.jl")
include("pipeline/adjust_phenotype.jl")

export build_model,set_covariate,set_random
export add_markers,get_pedigree
export outputMCMCsamples,solve,runMCMC
export showMME

export adjust_phenotypes,LOOCV
