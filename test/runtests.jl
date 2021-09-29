using NLPModels, NLPModelsJuMP, OptimizationProblems, Test

@test names(ADNLPProblems) == [:ADNLPProblems]

import ADNLPModels

ndef = ADNLPProblems.default_nvar

# Test that every problem can be instantiated.
for prob in names(PureJuMP)
  prob == :PureJuMP && continue
  println(prob)
  prob_fn = eval(Meta.parse("PureJuMP.$(prob)"))
  model = prob_fn(ndef)

  prob == :hs61 && continue #because nlpmodelsjump is not working here https://github.com/JuliaSmoothOptimizers/NLPModelsJuMP.jl/issues/84
  prob in [:clplatea, :clplateb, :clplatec, :fminsrf2] && continue # issue because variable is a matrix

  nlp_jump = MathOptNLPModel(model)
  nlp_ad = eval(Meta.parse("ADNLPProblems.$(prob)()"))

  @test nlp_jump.meta.nvar == nlp_ad.meta.nvar
  @test nlp_jump.meta.x0 == nlp_ad.meta.x0
  @test nlp_jump.meta.ncon == nlp_ad.meta.ncon
  @test nlp_jump.meta.lvar == nlp_ad.meta.lvar
  @test nlp_jump.meta.uvar == nlp_ad.meta.uvar

  x1 = nlp_ad.meta.x0
  x2 = nlp_ad.meta.x0 .+ 0.01
  n0 = max(abs(obj(nlp_ad, nlp_ad.meta.x0)), 1)
  @test isapprox(obj(nlp_ad, x1), obj(nlp_jump, x1), atol = 1e-14 * n0)
  @test isapprox(obj(nlp_ad, x2), obj(nlp_jump, x2), atol = 1e-14 * n0)

  if nlp_ad.meta.ncon > 0
    @test nlp_ad.meta.lcon == nlp_jump.meta.lcon
    @test nlp_ad.meta.ucon == nlp_jump.meta.ucon
    @test isapprox(cons(nlp_ad, x1), cons(nlp_jump, x1))
    @test isapprox(cons(nlp_ad, x2), cons(nlp_jump, x2))
  end
end

for prob in names(ADNLPProblems)
  prob == :ADNLPProblems && continue
  prob in [:clplatea, :clplateb, :clplatec, :fminsrf2] && continue # issue because variable is a matrix

  println(prob)
  try
    n, m = eval(Meta.parse("ADNLPProblems.get_$(prob)_meta(n=$(2 * ndef))"))
    meta_pb = eval(Meta.parse("ADNLPProblems.$(prob)_meta"))
    if meta_pb[:variable_size]
      @test n != meta_pb[:nvar]
    else
      @test n == meta_pb[:nvar]
    end
    if meta_pb[:variable_con_size]
      @test m != meta_pb[:ncon]
    else
      @test m == meta_pb[:ncon]
    end
  catch
    # prob_meta and get_prob_meta not defined for all problems yet.
  end

  for T in [Float32, Float64]
    nlp = eval(Meta.parse("ADNLPProblems.$(prob)(type=$(Val(T)))"))
    x0 = nlp.meta.x0
    @test eltype(x0) == T
    @test typeof(obj(nlp, x0)) == T
    if nlp.meta.ncon > 0
      @test eltype(cons(nlp, x0)) == T
    end
  end
end