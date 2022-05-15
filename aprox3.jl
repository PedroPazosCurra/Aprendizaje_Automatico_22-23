using DelimitedFiles
using Statistics
using JSON
using Flux
using XLSX: readdata
using Random
using DataFrames
using ScikitLearn

Random.seed!(1234);

dataset1 = JSON.parsefile("datasets\\Cerveza.json");
dataset2 = JSON.parsefile("datasets\\Cerveza2.json");
dataset = merge(dataset1,dataset2);

wl=[];
il=[];
al=[];
rl=[];
ol=[];

range = 52:114;

for d in values(dataset)
    push!(wl,get(d,"Wavelength",0)[range]);
    push!(al,get(d,"Absorbance",0)[range]);
    push!(rl,get(d,"Reflectance",0)[range]);
    push!(il,get(d,"Intensity",0)[range]);
    push!(ol,d["Labels"]["Graduacion"]);
end

inputsMatrix = zeros(264,3);
for i in 1:size(il,1)
	inputsMatrix[i,1] = std(il[i]);
	inputsMatrix[i,2] = std(rl[i]);
	inputsMatrix[i,3] = std(al[i]);
end

normalizeMinMax!(inputsMatrix);
outputsMatrix = alcoholoneHotEncoding(parse.(Float64,ol),5.5);

inputsMatrix = [(inputsMatrix[:,1] .* inputsMatrix[:,2]) inputsMatrix[:,3]];

experimentoRNA((inputsMatrix,outputsMatrix));

@sk_import svm: SVC;
@sk_import tree: DecisionTreeClassifier;
@sk_import neighbors: KNeighborsClassifier;

experimentoSVC((inputsMatrix,outputsMatrix));
experimentoArboles((inputsMatrix,outputsMatrix));
experimentoKNN((inputsMatrix,outputsMatrix));
