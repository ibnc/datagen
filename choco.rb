require 'java'
require './vendor/choco-solver/choco-solver-4.0.4-with-dependencies.jar'

class Model < org.chocosolver.solver.Model
end

def get_values(x)
  x.map { |v| v.getValue() }
end

def percent_to_count(percent, count)
  count.to_f/percent.to_f
end

model = Model.new("age distribution");
max_age = 100;
count = 501;
age = model.intVar(1, max_age, true);
agesUnder20 = model.intVarArray(percent_to_count(20, count), 1, 20, true);
agesBetween20And40 = model.intVarArray(percent_to_count(25, count), 20, 40, true);
agesBetween40And60 = model.intVarArray(percent_to_count(35, count), 40, 60, true);
agesAbove60 = model.intVarArray(percent_to_count(20, count), 60, max_age, true);
solver = model.getSolver();
solver.solve()


p get_values(agesUnder20).
  concat(get_values(agesBetween20And40)).
  concat(get_values(agesBetween40And60)).
  concat(get_values(agesAbove60))
