using DelimitedFiles
using Statistics
using JSON
using Flux
using XLSX: readdata
using Random
using DataFrames
using ScikitLearn

@sk_import svm: SVC;
@sk_import tree: DecisionTreeClassifier;
@sk_import neighbors: KNeighborsClassifier;

Random.seed!(1234);

dataset1 = JSON.parsefile("datasets\\Cerveza.json");
dataset2 = JSON.parsefile("datasets\\Cerveza2.json");
dataset = merge(dataset1,dataset2);

wl=[];
il1=[];
il2=[];
il3=[];
il4=[];
al1=[];
al2=[];
al3=[];
al4=[];
rl1=[];
rl2=[];
rl3=[];
rl4=[];
ol=[];
range = 52:116;
range1 = 52:68;
range2 = 68:84;
range3 = 84:100;
range4 = 100:116;

for d in values(dataset)
    push!(wl,get(d,"Wavelength",0)[range]);
    push!(al1,get(d,"Absorbance",0)[range1]);
    push!(al2,get(d,"Absorbance",0)[range2]);
    push!(al3,get(d,"Absorbance",0)[range3]);
    push!(al4,get(d,"Absorbance",0)[range4]);
    push!(rl1,get(d,"Reflectance",0)[range1]);
    push!(rl2,get(d,"Reflectance",0)[range2]);
    push!(rl3,get(d,"Reflectance",0)[range3]);
    push!(rl4,get(d,"Reflectance",0)[range4]);
    push!(il1,get(d,"Intensity",0)[range1]);
    push!(il2,get(d,"Intensity",0)[range2]);
    push!(il3,get(d,"Intensity",0)[range3]);
    push!(il4,get(d,"Intensity",0)[range4]);
    push!(ol,d["Labels"]["Graduacion"]);
end

inputsMatrix = zeros(264,3);
for i in 1:size(il,1)
	inputsMatrix[i,1] = mean([minimum(il1[i]),minimum(il2[i]),minimum(il3[i]),minimum(il4[i])]);
	inputsMatrix[i,2] = mean([minimum(rl1[i]),minimum(rl2[i]),minimum(rl3[i]),minimum(rl4[i])]);
	inputsMatrix[i,3] = mean([minimum(al1[i]),minimum(al2[i]),minimum(al3[i]),minimum(al4[i])]);
end

normalizeMinMax!(inputsMatrix);
outputsMatrix = alcoholoneHotEncoding(parse.(Float64,ol),5.5);

inputsMatrix = [(inputsMatrix[:,1] .* inputsMatrix[:,2]) inputsMatrix[:,3]];

k=10;

modelCrossValidation("RRNNAA",(inputsMatrix,outputsMatrix),k)
modelCrossValidation("SVC",(inputsMatrix,outputsMatrix),k)
modelCrossValidation("TREE",(inputsMatrix,outputsMatrix),k)
modelCrossValidation("KNN",(inputsMatrix,outputsMatrix),k)