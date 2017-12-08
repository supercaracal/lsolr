# frozen_string_literal: true

# @example How to use.
#   monoclinic = LSolr.new(:crystal_system).match(:monoclinic)
#   cubic = LSolr.new(:crystal_system).match(:cubic)
#   soft = LSolr.new(:mohs_scale).greater_than_or_equal_to('*').less_than(5.0)
#   hard = LSolr.new(:mohs_scale).greater_than_or_equal_to(5.0).less_than_or_equal_to(10.0)
#
#   phosphophyllite = monoclinic.and(soft).wrap
#   diamond = cubic.and(hard).wrap
#
#   phosphophyllite.or(diamond).to_s
#   #=> '(crystal_system:monoclinic AND mohs_scale:[* TO 5.0}) OR (crystal_system:cubic AND mohs_scale:[5.0 TO 10.0])'
class LSolr
  NOT = 'NOT'
  AND = 'AND'
  OR = 'OR'
  TO = 'TO'

  GREATER_THAN = '{'
  LESS_THAN = '}'
  GREATER_THAN_OR_EQUAL_TO = '['
  LESS_THAN_OR_EQUAL_TO = ']'

  PROXIMITY = '~'
  BOOST = '^'
  FUZZY_MATCH_DISTANCE_RANGE = (0.0..1.0).freeze

  PARENTHESIS_LEFT = '('
  PARENTHESIS_RIGHT = ')'

  RESERVED_SYMBOLS = %w(- + & | ! ( ) { } [ ] ^ " ~ * ? : \\\\ /).freeze
  RESERVED_WORDS = /(AND|OR|NOT)/
  REPLACEMENT_CHAR = ' '

  attr_accessor :prev, :operator, :left_parentheses, :right_parentheses

  # @param field [String] field name
  # @return [LSolr] a instance
  def initialize(field)
    raise ArgumentError, 'Please specify a field name.' if field.nil? || field.empty?

    @not = ''
    @field = field
    @value = ''
    @range_first = ''
    @range_last = ''
    @boost = ''
    @left_parentheses = []
    @right_parentheses = []
  end

  # @return [String] a stringigied query
  def to_s
    @value = "#{@range_first} #{TO} #{@range_last}" if range_search?
    raise 'Please specify a search condition.' if blank?

    expr = "#{left_parentheses.join}#{@not}#{@field}:#{@value}#{right_parentheses.join}"
    expr = "#{prev} #{operator} #{expr}" if !prev.nil? && prev.present?
    "#{expr}#{@boost}"
  end

  # @return [true] unless search condition specified
  # @return [false] if search condition specified
  def blank?
    @value.empty? && (@range_first.empty? || @range_last.empty?)
  end

  # @return [true] if search condition specified
  # @return [false] unless search condition specified
  def present?
    !blank?
  end

  # @return [LSolr] copied self instance
  def wrap
    this = dup
    take_head(this).left_parentheses << PARENTHESIS_LEFT
    this.right_parentheses << PARENTHESIS_RIGHT
    this
  end

  # @return [LSolr] self instance
  def not
    @not = "#{NOT} "
    self
  end

  # @param weight [Float] boost weight
  # @return [LSolr] self instance
  def boost(weight)
    @boost = "#{BOOST}#{weight}"
    self
  end

  # @param value [String, Integer, true, false] search word or filter value
  # @return [LSolr] self instance
  def match(value)
    values = clean(value).split
    if values.size > 1
      phrase_match(values)
    else
      @value = values.join('')
      self
    end
  end

  # @param value [String] filter value
  # @return [LSolr] self instance
  def date_time_match(value)
    @value = clean(value, symbols: RESERVED_SYMBOLS - %w[- : . / +])
    self
  end

  # @param value [String] search word
  # @return [LSolr] self instance
  def prefix_match(value)
    @value = clean(value, symbols: RESERVED_SYMBOLS - %w[* ?])
    self
  end

  # @param values [Array<String>] search word
  # @param distance [Integer] proximity distance
  # @return [LSolr] self instance
  def phrase_match(values, distance: 0)
    value = values.map { |v| clean(v) }.join(REPLACEMENT_CHAR)
    proximity_match = distance.positive? ? "#{PROXIMITY}#{distance}" : ''
    @value = %("#{value}"#{proximity_match})
    self
  end

  # @param value [String] search word
  # @param distance [Float] proximity distance
  # @return [LSolr] self instance
  def fuzzy_match(value, distance: 0.0)
    raise RangeError, "Out of #{FUZZY_MATCH_DISTANCE_RANGE}. #{distance} given." unless FUZZY_MATCH_DISTANCE_RANGE.member?(distance)
    @value = "#{clean(value)}#{PROXIMITY}#{distance}"
    self
  end

  # @param value [String, Integer] filter value
  # @return [LSolr] self instance
  def greater_than(value)
    @range_first = "#{GREATER_THAN}#{value}"
    self
  end

  # @param value [String, Integer] filter value
  # @return [LSolr] self instance
  def less_than(value)
    @range_last = "#{value}#{LESS_THAN}"
    self
  end

  # @param value [String, Integer] filter value
  # @return [LSolr] self instance
  def greater_than_or_equal_to(value)
    @range_first = "#{GREATER_THAN_OR_EQUAL_TO}#{value}"
    self
  end

  # @param value [String, Integer] filter value
  # @return [LSolr] self instance
  def less_than_or_equal_to(value)
    @range_last = "#{value}#{LESS_THAN_OR_EQUAL_TO}"
    self
  end

  # @param another [LSolr] another instance
  # @return [LSolr] copied another instance
  def and(another)
    link(another, AND)
  end

  # @param another [LSolr] another instance
  # @return [LSolr] copied another instance
  def or(another)
    link(another, OR)
  end

  private

  def initialize_copy(obj)
    obj.prev = obj.prev.dup if !obj.prev.nil? && obj.prev.present?
    obj.left_parentheses = obj.left_parentheses.dup
    obj.right_parentheses = obj.right_parentheses.dup
  end

  def range_search?
    @value.empty? && !@range_first.empty? && !@range_last.empty?
  end

  def clean(value, symbols: RESERVED_SYMBOLS)
    value.to_s
         .tr(symbols.join(''), REPLACEMENT_CHAR)
         .gsub(RESERVED_WORDS) { |match| "\\#{match}" }
  end

  def link(another, operator)
    return self if another.nil? || another.blank?

    another = another.dup
    head = take_head(another)
    head.prev = dup
    head.operator = operator
    another
  end

  def take_head(element)
    while !element.prev.nil? && element.prev.present? do element = element.prev end
    element
  end
end
