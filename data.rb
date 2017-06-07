require "rubygems"
require "bundler/setup"

require "forgery"
require_relative "weighted_distribution"

class GenericValue
  def generate(sample_size=1)
    raise "Need to at least generate 1 sample" if sample_size < 1

    result = []
    sample_size.times do
      result << apply_transform(one_result)
    end

    result
  end

  private

  def one_result
    unless @format == :composite
      return @allows_options ? @generator.send(@method, options) : @generator.send(@method)
    end

    raise "Must have a separator for :composite StringValues" unless @separator

    @children.map(&:generate).join(@separator)
  end
end

class NumericValue < GenericValue
  FORMATTERS = {
      integer: [:basic, :number, true]
  }

  def initialize(format=:integer)
    @format = format
    formatter_name, @method, @allows_options = FORMATTERS[@format]
    @generator = Forgery(formatter_name)
  end

  def between(min, max)
    options.merge!(at_least: min, at_most: max)
    self
  end

  def options
    @options ||= {}
  end

  def apply_transform(result)
    return result
  end
end

class StringValue < GenericValue
  FORMATTERS = {
      basic: [:basic, :text, true],
      first_name: [:name, :first_name, false],
      last_name: [:name, :last_name, false],
      name: [:name, :full_name, false],
  }

  def initialize(format=:basic)
    @format = format

    if format == :composite
      @separator = "-"
    else
      formatter_name, @method, @allows_options = FORMATTERS[@format]
      @generator = Forgery(formatter_name)
    end
  end

  def from(*values)
    assert_type(:composite)
    @children = values
    self
  end

  def joined_by(separator)
    assert_type(:composite)
    @separator = separator
    self
  end

  def transformed_as(transformer)
    @transformer = transformer # e.g. :uppercase
    self
  end

  def of_length(len, upper_bound=nil)
    raise "Max must be greater than or equal to min" if upper_bound && upper_bound < len

    options.merge! upper_bound.nil? ? {exactly: len} : {at_least: len, at_most: upper_bound}
    self
  end

  def options
    @options ||= {}
  end

  def apply_transform(result)
    return result unless @transformer

    case @transformer
      when :upper
        result.upcase
      when :lower
        result.downcase
      else
        result
    end
  end

  def assert_type(type)
    raise "Can only be used with #{type.inspect} type StringValues" unless @format == type
  end
end

class EntityValue < GenericValue

  def initialize(name)
    @attributes = {}
    @name = name
  end

  def has(attributes)
    @attributes.merge!(attributes)
    self
  end

  def generate(times)
    Array.new(times) {
      @attributes.inject({}) do |memo, entry|
        name = entry[0]
        value = entry[1]
        memo[name] = value.generate
        memo
      end
    }
  end
end

class WeightedDistro

  def initialize
    @generators_to_weights = {}
  end

  def as_percentages
    @interpret_weights_as_percentages = true
    self
  end

  def add(generic_value, weight)
    raise "All weights must be postive" unless weight > 0
    @generators_to_weights[generic_value] = weight
    self
  end

  def default(generic_value)
    @default = generic_value
    self
  end

  def generate(sample_size=1)
    raise "Must generate at least 1 sample" if sample_size < 1
    validate_percentages if @interpret_weights_as_percentages

    distributor.sample(sample_size)
  end

  private

  def distributor
    @generator ||= WeightedDistribution.new(@generators_to_weights)
  end

  def validate_percentages
    total = sum(@generators_to_weights.values)

    if !@default.nil? && total < 100
      add(@default, 100 - total)
      total = sum(@generators_to_weights.values)
    end

    raise "Percentages do not add up to 100%" unless total.round == 100
  end

  def sum(collection)
    collection.reduce(:+)
  end

end

if $0 == __FILE__
  puts "Running example"

  random_text = StringValue.new.
      of_length(2, 15).
      transformed_as(:lower)

  first_name = StringValue.new(:first_name).
      transformed_as(:lower)

  login = StringValue.new(:composite).
      from(first_name, random_text).
      joined_by("_")

  wee_people = NumericValue.new.
      between(1, 3)

  youngins = NumericValue.new.
      between(4, 12)

  troublemakers = NumericValue.new.
      between(13, 20)

  everyone_else = NumericValue.new.
      between(21, 120)

  ages = WeightedDistro.new.
      add(wee_people, 1).
      add(youngins, 3).
      add(troublemakers, 3).
      add(everyone_else, 5)

  ages = WeightedDistro.new.
      as_percentages.
      add(wee_people, 10).
      add(youngins, 25).
      add(troublemakers, 40).
      default(everyone_else)

  weight = NumericValue.new.
      between(80, 270)

  person = EntityValue.new("person").
      has(
          patient_name: first_name,
          patient_age: ages,
          patient_weight: weight
      )

  num = 10000
  people = person.generate(num)

  def age_percentage(people, total, &block)
    ages = people.map {|person| person[:patient_age]}.flatten
    count = ages.select(&block).size
    "#{100 * (count / total.to_f)}%"
  end

  puts %Q{
  out of #{num} samples:

  wee: #{age_percentage(people, num) {|age| age < 4}}
  young: #{age_percentage(people, num) {|age| age >= 4 && age <= 12}}
  trouble: #{age_percentage(people, num) {|age| age >= 13 && age <= 20}}
  else: #{age_percentage(people, num) {|age| age > 20}}
  }

  # Entity.new.associate(first_name, age, weight)
end