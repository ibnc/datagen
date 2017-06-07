require "rubygems"
require "bundler/setup"

require "forgery"

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

# if $0 == __FILE__
random_text = StringValue.new.
    of_length(2, 15).
    transformed_as(:lower)

first_name = StringValue.new(:first_name).
    transformed_as(:lower)

login = StringValue.new(:composite).
    from(first_name, random_text).
    joined_by("_")

age = NumericValue.new.
    between(5, 40)

puts age.
    generate(100)

Distribution.new.
    add(WestCoastStates.new, 10).
    add(MidWestStates.new, 3).
    add(EastCoastStates.new, 7).
    generate(10)

Distribution.new.
    add(WestCoastStates.new, 5).
    add(MidWestStates.new, 10).
    add(EastCoastStates.new).
    generate(10)

# login_name = StringValue.new.composed_of(StringValue.new.with_format(:first_name), StringValue.new.with_format(:last_name)).joined_by(:-).transformed_as(:uppercase)
# puts login_name.generate
# end