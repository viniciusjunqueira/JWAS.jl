function make_matrices_hybrid(pedfile,genofile,phenofile;center=false)
  num  =SSBR.Numbers(0,0,0,0,0,0,0)
  geno =misc.make_genotypes(genofile,center=center);#single-step, center with imputed M
  ped,amats =calc_Ai(pedfile,geno,num);
  mmats = make_MMats(geno,num,amats,ped);
  yvecs = make_yVecs(phenofile,ped,num);
  jvecs = make_JVecs(num,amats);
  zmats =make_ZMats(ped,yvecs,num);
  xmats, wmats = make_XWMats(jvecs,zmats,mmats,num)
  return ped,geno,HybridMatrices(zmats,amats,yvecs,jvecs,
                             xmats,wmats,mmats,num)
end

function calc_Ai(pedfile,geno::misc.Genotypes,num::Numbers)
    ped         = PedModule.mkPed(pedfile)
    num.pedn    = PedModule.genoSet!(geno.obsID,ped)
    Ai          = PedModule.AInverse(ped)
    num.ped     = size(Ai,2)   #num.ped=num.pedn+num.pedg
    num.pedg    = num.ped-num.pedn
    Ai_nn       = Ai[1:num.pedn,1:num.pedn]
    Ai_ng       = Ai[1:num.pedn,(num.pedn+1):num.ped]
    return ped,AiMats(Ai,Ai_nn,Ai_ng)
end

function make_MMats(geno::misc.Genotypes,num::Numbers,a_mats::AiMats,ped::PedModule.Pedigree)
    #Mg = Array(Float64,geno.nObs,geno.nMarkers)
     Mg = Array{Float64}(geno.nObs,geno.nMarkers)

    num.markers  = geno.nMarkers
    #reorder genotypes to get Mg with same order as Ai_gg
    for i in 1:geno.nObs
      id = geno.obsID[i]
      row = ped.idMap[id].seqID - num.pedn
      Mg[row,:] = geno.genotypes[i,:]
    end
    Mn = a_mats.nn\(-a_mats.ng*Mg)
    M  = [Mn;Mg];
    return MMats(M,Mn,Mg)
end

#allow replicated ID
function make_yVecs(file,ped::PedModule.Pedigree,num::Numbers;header=false)
    myfile = open(file)
    #get number of columns
    row1   = split(readline(myfile))
    ncol   = length(row1)
    etv    = Array{DataType}(ncol)
    fill!(etv,Float64)
    etv[1]=String
    close(myfile)

    df = readtable(file, eltypes=etv, separator = ' ',header=header)

    nob   = size(df,1)
    ntrait= size(df,2)-1

    IDs       = convert(Array,df[:,1])
    isnongeno = [ID in ped.setNG for ID in IDs] #true/false

    dfn =  df[isnongeno,:]
    dfg =  df[.!isnongeno,:]

    yn    = convert(Array,dfn[:,2],0.0) #convert only work with dataarray no dataframe
    yg    = convert(Array,dfg[:,2],0.0) #replace NA with 0.0
    for i = 3:(ntrait+1)
        yn = [yn convert(Array,dfn[:,i],0.0)]
        yg = [yg convert(Array,dfg[:,i],0.0)]
    end

    y          = [yn;yg]          #order of y is nongeno then gen
    ids        = [IDs[isnongeno];
                  IDs[.!isnongeno]] #order of ids is same to order of y

    num.y, num.yn, num.yg = size(df,1), size(yn,1), size(yg,1)

    return YVecs(y,yn,yg,ids)
end




function make_JVecs(num::Numbers,a_mats::AiMats)
    Jg = -ones(num.pedg,1)
    Jn = a_mats.nn\(-a_mats.ng*Jg)
    J  = [Jn;
          Jg]
    return JVecs(J,Jn,Jg)
end

function make_ZMats(ped,yvecs::YVecs,num::Numbers)
    Z    =spzeros(num.y,num.ped)
    rowi =1
    for i in yvecs.ids     #go through y
      colj         = ped.idMap[i].seqID #get the position of this id in reordered A
      Z[rowi,colj] = 1
      rowi        += 1
    end

    Z_n= Z[:,1:num.pedn]
    Z_g= Z[:,(num.pedn+1):num.ped]
    Zn = Z[1:num.yn,1:num.pedn]
    Zg = Z[(num.yn+1):num.y,(num.pedn+1):num.ped]
    return ZMats(Z,Zn,Zg,Z_n,Z_g)
end

function make_XWMats(jvecs,zmats,mmats,num::Numbers)#now fixed effects: μ
    Xn  = hcat(ones(num.yn), zmats.n*jvecs.n)
    Xg  = hcat(ones(num.yg), zmats.g*jvecs.g)
    X   =[Xn;
          Xg]

    Wn = zmats.n*mmats.n
    Wg = zmats.g*mmats.g
    W  = [Wn;Wg];
    return XMats(X,Xn,Xg),WMats(W,Wn,Wg)
end

export make_matrices_hybrid
