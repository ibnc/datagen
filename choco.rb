require 'java'
require './vendor/choco-solver/choco-solver-4.0.4-with-dependencies.jar'

class Model < org.chocosolver.solver.Model
end

def get_values(x)
  x.map { |v| v.getValue() }
end

def percent_to_count(percent, count)
  (percent.to_f/100.0) * count.to_f
end

model = Model.new("age distribution")
max_age = 100
count = 500
age = model.intVar(1, max_age, true)
agesUnder20 = model.intVarArray(percent_to_count(20, count), 1, 20, true)
agesBetween20And40 = model.intVarArray(percent_to_count(25, count), 20, 40, true)
agesBetween40And60 = model.intVarArray(percent_to_count(35, count), 40, 60, true)
agesAbove60 = model.intVarArray(percent_to_count(20, count), 60, max_age, true)
solver = model.getSolver()
solver.solve()

puts "finding the solution by simply modeling:\n"

p get_values(agesUnder20).
  concat(get_values(agesBetween20And40)).
  concat(get_values(agesBetween40And60)).
  concat(get_values(agesAbove60))

puts "***************"*88
puts "\n\n\n\n"
puts "finding the solution using constraints using constraints:\n"


model2 = Model.new("age distro using constraints")
ages = model2.intVarArray(count, 1, max_age, true)

offset = 0

percent_to_count(20, count).to_i.times do |i|
  model2.arithm(ages[i], "<=", model2.intVar(20)).post()
end
offset += percent_to_count(20, count).to_i

percent_to_count(25, count).to_i.times do |i|
  j = i + offset
  model2.arithm(ages[j], ">=", 20).post()
  model2.arithm(ages[j], "<=", 40).post()
end
offset += percent_to_count(25, count).to_i

percent_to_count(35, count).to_i.times do |i|
  j = i + offset
  model2.arithm(ages[j], ">=", 40).post()
  model2.arithm(ages[j], "<=", 60).post()
end

offset += percent_to_count(35, count).to_i

percent_to_count(20, count).to_i.times do |i|
  j = i + offset
  model2.arithm(ages[j], ">=", 60).post()
  model2.arithm(ages[j], "<=", max_age).post()
end

solver = model2.getSolver()
solver.solve()

solution =  get_values(ages)
p solution

puts "there are #{solution.select { |x| x < 20 }.size} elements under 20 ( 0.2 * #{count} )is #{0.2 * count}"
puts "there are #{solution.select { |x| x >= 20 && x < 40 }.size} elements under between 20 and 40 ( 0.25 * #{count} )is #{0.25 * count}"
puts "there are #{solution.select { |x| x >= 40 && x < 60 }.size} elements under between 40 and 60 ( 0.35 * #{count} )is #{0.35 * count}"
puts "there are #{solution.select { |x| x >= 60 && x < max_age }.size} elements under between 60 and #{max_age} ( 0.2 * #{count} )is #{0.2 * count}"
