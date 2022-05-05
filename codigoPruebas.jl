using DelimitedFiles
using Statistics
using JSON
using Flux
using XLSX: readdata
using Random
using DataFrames
using ScikitLearn



###########################
# Introduccion
###########################



oneHotEncoding(feature::AbstractArray{<:Any,1}, classes::AbstractArray{<:Any,1}) = 
	if (size(classes,1) == 2)
		boolVector = feature .== classes
		# Transformar boolVector a matriz bidimensional de una columna
        reshape(boolVector, (2,1))
	else
		boolMatrix =  BitArray{2}(0, size(feature,1), size(classes,1))
        for i in 1:size(classes,1)
            boolMatrix[:,i] = feature .== classes[i]
        end
	end
	
oneHotEncoding(feature::AbstractArray{<:Any,1}) = 
	oneHotEncoding(feature, unique(feature))
	
oneHotEncoding(feature::AbstractArray{Bool,1}) = 
	reshape(feature, (length(feature),1))
	
calculateMinMaxNormalizationParameters(x::AbstractArray{<:Real,2}) = 
	(minimum(x, dims=1), maximum(x, dims=1))
	
calculateZeroMeanNormalizationParameters(x::AbstractArray{<:Real,2}) = 
	(mean(x, dims=1), std(x, dims=1))
	
function normalizeMinMax!(x::AbstractArray{<:Real,2}, y::NTuple{2, AbstractArray{<:Real,2}})
	minim = y[:][1]
	maxim = y[:][2]
	x .= (x .- minim) ./ (maxim .- minim) # Añadir caso en el que min y max sean iguales
	end
	
normalizeMinMax!(x::AbstractArray{<:Real,2}) =
	normalizeMinMax!(x,calculateMinMaxNormalizationParameters(x))
	
function normalizeMinMax(x::AbstractArray{<:Real,2}, y::NTuple{2, AbstractArray{<:Real,2}})
	bar = copy(x)
	normalizeMinMax!(bar,y)
	end
	
normalizeMinMax(x::AbstractArray{<:Real,2}) =
	normalizeMinMax!(copy(x))

function normalizeZeroMean!(x::AbstractArray{<:Real,2}, y::NTuple{2, AbstractArray{<:Real,2}})
	media = y[:][1]
	desviacion = y[:][2]
	x .= (x .- media) ./ (media .- desviacion) # Añadir caso en el que desviacion tipica es 0
	end
	
normalizeZeroMean!(x::AbstractArray{<:Real,2}) =
	normalizeMinMax!(x,calculateZeroMeanNormalizationParameters(x))
	
function normalizeZeroMean(x::AbstractArray{<:Real,2}, y::NTuple{2, AbstractArray{<:Real,2}})
	bar = copy(x)
	normalizeZeroMean!(bar,y)
	end
	
normalizeZeroMean(x::AbstractArray{<:Real,2}) =
	normalizeZeroMean!(copy(x))


function accuracy(targets::AbstractArray{Bool,1}, outputs::AbstractArray{Bool, 1})
    acc = targets .== outputs
    (sum(acc) * 100)/(length(acc))
    end




###########################
# RR NN AA
###########################



function creaRNA(topology::AbstractArray{<:Int,1}, numInputsLayer::Int64, numOutputsLayer::Int64)
	# RNA vacía
	ann = Chain();

	# Si hay capas ocultas, se itera por topology y se crea una capa por iteración
	for numOutputsLayer = topology 
		ann = Chain(ann..., Dense(numInputsLayer, numOutputsLayer, σ) ); 
		numInputsLayer = numOutputsLayer; 
	end;

	# Devuelve rna creada!!
	return ann
end

function entrenaRNA(topology::AbstractArray{<:Int,1}, dataset::Tuple{AbstractArray{<:Real,2}, AbstractArray{Bool,2}}, validacion::Tuple{AbstractArray{<:Real,2},
	AbstractArray{Bool,2}}=(), test::Tuple{AbstractArray{<:Real,2},
	AbstractArray{Bool,2}}=(), maxEpochsVal::Int64=20, maxEpochs::Int64=10000, minLoss::Real=0, learningRate::Real=0.001)

	# Ojo 1, cercionarse de que inputs y targets tengan cada patrón en cada columna. La transpongo con ' pero ver si falla.
	# Ojo 2, las matrices que se pasan para entrenar deben ser disjuntas a las que se usen para test.
	
	inputs = dataset[1]
	targets = dataset[2]
	lossVector = zeros(maxEpochs)
	
	if (!isempty(validacion))
		inval = validacion[1]
		outval = validacion[2]
		lossVectorValidacion = zeros(maxEpochs)
	end
	
	# Creo RNA que vamos a entrenar 
#	ann = creaRNA(topology, size(inputs,1), size(targets,1))

	ann = Chain(
		Dense(3,size(dataset,1),σ),
		Dense(size(dataset,1),1,σ),
	)
	
	loss(x, y) = (size(y, 1) == 1) ? Losses.binarycrossentropy(ann(x), y) : Losses.crossentropy(ann(x), y);

	# Bucle para entrenar cada ciclo!!!
	aux = 1
	ctr = 0
	auxAnn = ann

	while ((loss(inputs',targets') > minLoss) && (aux < maxEpochs) && (ctr < maxEpochsVal)) 

		Flux.train!(loss, params(ann), [(inputs', targets')], ADAM(learningRate)); 

		lossVector[aux+1] = loss(inputs',targets')
		
		if (!isempty(validacion))
			lossVectorValidacion[aux+1] = loss(inval',outval')
			if (lossVectorValidacion[aux+1] >= lossVectorValidacion[aux])
				ctr += 1
			else
				ctr = 0
				auxAnn = ann
			end
		else 
			auxAnn = ann
		end

		aux += 1
	end
	
	# Devuelvo RNA entrenada y un vector con los valores de loss en cada iteración.
	# Si se da conjunto de validación, devuelve la rna con menor error de validación.
	return (auxAnn, lossVector)

end



###########################
# Sobreentrenamiento
###########################



function holdOut(N::Int64, P::Float64)
	v = randperm(N)
	cut = round(Int64,size(v,1)*P)
	return (v[1:cut], v[(cut + 1):(size(v,1))])
end

function holdOut(N::Int64, Pval::Float64, Ptest::Float64)
	t1 = holdOut(N, Pval + Ptest)
	t2 = holdOut(size(t1[2],1), Ptest)
	w1 = zeros(Int64,size(t2[1],1))
	w2 = zeros(Int64,size(t2[2],1))
	j = 1
	for i in t2[1]
		w1[j] = t1[2][i]
		j += 1
	end
	j = 1
	for i in t2[2]
		w2[j] = t1[2][i]
		j += 1
	end
	return (t1[1], w1, w2)

end


###########################
# Metricas
###########################



function confusionMatrix(outputs::AbstractArray{Bool,1}, targets::AbstractArray{Bool,1})
	#Verdadero negativo:
	v1 = 0 .== outputs
	v2 = 0 .== targets
	aux = (v1 .&& v2)	
	vn = count(aux)
	
	#Verdadero positivo:		
	v1 = 1 .== outputs
	v2 = 1 .== targets
	aux = v1 .&& v2
	vp = count(aux)
	
	#Falso negativo:
	v1 = 0 .== outputs
	v2 = 1 .== targets
	aux = v1 .&& v2
	fn = count(aux)
	
	#Falso positivo:
	v1 = 1 .== outputs
	v2 = 0 .== targets
	aux = v1 .&& v2
	fp = count(aux)

    matr = [vn fp; fn vp]

	accuracy = 		(vn+vp)/(vn+fn+vp+fp)
    if(isnan(accuracy)) 
        accuracy = 0
    end
	tasa_fallo = 	(fn + fp)/(vn + vp + fn + fp)
    if(isnan(tasa_fallo)) 
        tasa_fallo = 0
    end

    sensibilidad = 1
    if (vn != length(outputs))
	    sensibilidad = 	vp / (fn + vp)
        if(isnan(sensibilidad)) 
            sensibilidad = 0
        end
    end 

	especificidad = 	vn / (fp + vn) 
    if (isnan(especificidad)) 
        especificidad = 0
    end

    v_pred_pos = 1
    if(vn != length(outputs))
		v_pred_pos = 	vp / (vp + fp)
        if(isnan(v_pred_pos)) 
            v_pred_pos = 0
        end
	end

	v_pred_neg = 1
	if (vp != length(outputs))
		v_pred_neg = 	vn / (vn + fn)
        if(isnan(v_pred_neg)) 
            v_pred_neg = 0
        end
	end

	f1_score = 0
	if (sensibilidad != 0 && v_pred_pos != 0)
		f1_score = 2 * (sensibilidad*v_pred_pos) / (sensibilidad+v_pred_pos)
        if(isnan(f1_score)) 
            f1_score = 0
        end
	end

    return Dict("valor_precision" => accuracy, "tasa_fallo" => tasa_fallo, "sensibilidad" => sensibilidad , "especificidad" => especificidad, "valor_predictivo_positivo" => v_pred_pos, "valor_predictivo_negativo" => v_pred_neg, "f1_score" => f1_score, "matriz_confusion" => matr)
end

function confusionMatrix(outputs::AbstractArray{<:Real}, targets::AbstractArray{Bool,1}, umbral::Number=0.5)
	confusionMatrix((outputs .>= umbral),targets)
end




###########################
# Clasificacion Multiclase
###########################





###########################
# Validacion Cruzada
###########################



# N > k
function crossvalidation(N::Int64, k::Int64)
	v = Vector{Int64}(1:k)
	vect = repeat(v,N)
	shuffle!(vect[1:N])
end

function crossvalidation(targets::AbstractArray{Bool,2}, k::Int64)
	v = Vector{Int64}(1:size(targets,1))
	for col in eachcol(targets)
		v = crossvalidation(sum(col),k)
	end
	return v
end

function crossvalidation(targets::AbstractArray{<:Any,1}, k::Int64)
	crossvalidation(oneHotEncoding(targets),k)
end
# importante asegurarse de que se tienen al menos 10 patrones de cada clase