# frozen_string_literal: true

require 'date'

# A query builder of Apache Solr standard Lucene type query for Ruby.
#
# @example How to use. Part 1:
#   LSolr.build(term1: 'hoge', term2: true).to_s
#   #=> 'term1:hoge AND term2:true'
#
# @example How to use. Part 2:
#    params = {
#      term01: 'hoge',
#      term02: :fuga,
#      term03: 14,
#      term04: 7.3,
#      term05: true,
#      term06: false,
#      term07: Date.new(7000, 7, 1),
#      term08: DateTime.new(6000, 5, 31, 6, 31, 43),
#      term09: Time.new(5000, 6, 30, 12, 59, 3),
#      term10: LSolr.new(:term10).fuzzy_match('foo'),
#      term11: [1, 2, 3],
#      term12: 1..10,
#      term13: 20...40,
#      term14: Date.new(3000, 1, 1)..Date.new(4000, 12, 31),
#      term15: (3.0..4.0).step(0.1)
#    }
#
#    LSolr.build(params).to_s
#    #=> 'term01:hoge AND term02:fuga AND term03:14 AND term04:7.3 AND term05:true
#    #    AND term06:false AND term07:"7000-07-01T00:00:00Z" AND term08:"6000-05-31T06:31:43Z"
#    #    AND term09:"5000-06-30T12:59:03Z" AND term10:foo~2.0 AND (term11:1 OR term11:2 OR term11:3)
#    #    AND term12:[1 TO 10] AND term13:[20 TO 40} AND term14:[3000-01-01T00:00:00Z TO 4000-12-31T00:00:00Z]
#    #    AND term15:[3.0 TO 4.0]'
#
# @example How to use. Part 3:
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

  WILD_CARD = '*'
  PROXIMITY = '~'
  BOOST = '^'
  PHRASE_MATCH_DELIMITER = ' '
  FUZZY_MATCH_DISTANCE_RANGE = (0.0..2.0).freeze
  FORMAT_DATE_TIME = '%Y-%m-%dT%H:%M:%SZ'
  FORMAT_MILLISECOND_FOR_DATE_TYPE = '%Q'
  FORMAT_MILLISECOND_FOR_TIME_TYPE = '%L'
  FORMAT_SECOND = '%s'

  PARENTHESIS_LEFT = '('
  PARENTHESIS_RIGHT = ')'

  RESERVED_SYMBOLS = %w(- + & | ! ( ) { } [ ] ^ " ~ * ? : \\\\ /).freeze
  RESERVED_WORDS = /(AND|OR|NOT)/
  REPLACEMENT_CHAR = ' '

  attr_accessor :prev, :operator, :left_parentheses, :right_parentheses

  class << self
    # Builds composite query and returns builder instance.
    #
    # @param params [Hash{Symbol => String, Integer, Float, true, false, Range, Date, Time}] query terms
    #
    # @return [LSolr] a instance
    def build(params)
      params.map { |f, v| build_query(f, v) }.reduce { |a, e| a.and(e) }
    end

    private

    def build_query(field, value) # rubocop:disable Metrics/CyclomaticComplexity
      case value
      when String, Symbol, Integer, Float, true, false then new(field).match(value)
      when Date, Time then new(field).date_time_match(value)
      when LSolr then value
      when Array then build_array_query(field, value)
      when Range then build_range_query(field, value)
      when Enumerator then build_enumerator_query(field, value)
      else raise ArgumentError, "Could not build solr query. field: #{field}, value: #{value.inspect}"
      end
    end

    def build_array_query(field, values)
      values.map { |v| build_query(field, v) }.reduce { |a, e| a.or(e) }.wrap
    end

    def build_range_query(field, value)
      if value.exclude_end?
        new(field).greater_than_or_equal_to(value.first).less_than(value.last)
      else
        new(field).greater_than_or_equal_to(value.first).less_than_or_equal_to(value.last)
      end
    end

    def build_enumerator_query(field, values)
      last = nil
      values.each { |v| last = v }
      new(field).greater_than_or_equal_to(values.first).less_than_or_equal_to(last)
    end
  end

  # Create a new query builder instance.
  #
  # @param field [String] a field name
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

  # Returns Apache Solr standard lucene type query string.
  #
  # @return [String] a stringified query
  def to_s
    @value = "#{@range_first} #{TO} #{@range_last}" if range_search?
    raise 'Please specify a search condition.' if blank?

    expr = "#{left_parentheses.join}#{@not}#{@field}:#{@value}#{right_parentheses.join}"
    expr = "#{prev} #{operator} #{expr}" if !prev.nil? && prev.present?
    "#{expr}#{@boost}"
  end

  alias to_str to_s

  # A query is blank if value is empty in expression.
  #
  # @return [true, false]
  def blank?
    @value.empty? && (@range_first.empty? || @range_last.empty?)
  end

  # A query is present if it's not blank.
  #
  # @return [true, false]
  def present?
    !blank?
  end

  # Adds parentheses to query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#grouping-terms-to-form-sub-queries Grouping Terms to Form Sub-Queries
  #
  # @return [LSolr] copied self instance
  def wrap
    this = dup
    take_head(this).left_parentheses << PARENTHESIS_LEFT
    this.right_parentheses << PARENTHESIS_RIGHT
    this
  end

  # Adds the boolean operator `NOT` to query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#the-boolean-operator-not The Boolean Operator NOT ("!")
  #
  # @return [LSolr] self instance
  def not
    @not = "#{NOT} "
    self
  end

  # Boosts a query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#boosting-a-term-with Boosting a Term with "^"
  #
  # @param factor [Float] a boost factor number
  #
  # @return [LSolr] self instance
  def boost(factor)
    raise ArgumentError, "The boost factor number must be positive. #{factor} given." if factor <= 0
    @boost = "#{BOOST}#{factor}"
    self
  end

  # Builds a normal query expression.
  #
  # @param value [String, Integer, true, false] a search word or a filter value
  #
  # @return [LSolr] self instance
  def match(value)
    values = clean(value).split

    if values.size > 1
      phrase_match(values)
    else
      @value = values.join
      self
    end
  end

  # Builds a normal query expression with dates and times.
  #
  # @see https://lucene.apache.org/solr/guide/6_6/working-with-dates.html Working with Dates
  #
  # @param value [String, Date, Time] a filter value
  #
  # @return [LSolr] self instance
  def date_time_match(value)
    value = if value.is_a?(Date) || value.is_a?(Time)
              format_date(value)
            else
              clean(value, symbols: RESERVED_SYMBOLS - %w[- : . / +])
            end

    @value = %("#{value}")
    self
  end

  # Builds a prefix search query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#wildcard-searches Wildcard Searches
  #
  # @param value [String] a search word
  #
  # @return [LSolr] self instance
  def prefix_match(value)
    @value = clean(value, symbols: RESERVED_SYMBOLS - %w[* ?]).split.join(WILD_CARD)
    self
  end

  # Builds a phrase or proximity search query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#grouping-clauses-within-a-field Grouping Clauses within a Field
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#proximity-searches Proximity Searches
  #
  # @param values [Array<String>] search words
  # @param distance [Integer] proximity distance
  #
  # @return [LSolr] self instance
  def phrase_match(values, distance: 0)
    value = values.map { |v| clean(v).split }.flatten.join(PHRASE_MATCH_DELIMITER)
    proximity_match = distance > 0 ? "#{PROXIMITY}#{distance}" : ''
    @value = %("#{value}"#{proximity_match})
    self
  end

  # Builds a fuzzy search query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#fuzzy-searches Fuzzy Searches
  #
  # @param value [String] a search word
  # @param distance [Float] a proximity distance
  #
  # @return [LSolr] self instance
  def fuzzy_match(value, distance: 2.0)
    raise RangeError, "Out of #{FUZZY_MATCH_DISTANCE_RANGE}. #{distance} given." unless FUZZY_MATCH_DISTANCE_RANGE.member?(distance)
    @value = "#{clean(value).split.join}#{PROXIMITY}#{distance}"
    self
  end

  # Builds a range search query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#range-searches Range Searches
  #
  # @param value [String, Integer, Date, Time] a filter value
  #
  # @return [LSolr] self instance
  def greater_than(value)
    value = format_date(value) if value.is_a?(Date) || value.is_a?(Time)
    @range_first = "#{GREATER_THAN}#{value}"
    self
  end

  # Builds a range search query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#range-searches Range Searches
  #
  # @param value [String, Integer, Date, Time] a filter value
  #
  # @return [LSolr] self instance
  def less_than(value)
    value = format_date(value) if value.is_a?(Date) || value.is_a?(Time)
    @range_last = "#{value}#{LESS_THAN}"
    self
  end

  # Builds a range search query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#range-searches Range Searches
  #
  # @param value [String, Integer, Date, Time] a filter value
  #
  # @return [LSolr] self instance
  def greater_than_or_equal_to(value)
    value = format_date(value) if value.is_a?(Date) || value.is_a?(Time)
    @range_first = "#{GREATER_THAN_OR_EQUAL_TO}#{value}"
    self
  end

  # Builds a range search query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#range-searches Range Searches
  #
  # @param value [String, Integer, Date, Time] a filter value
  #
  # @return [LSolr] self instance
  def less_than_or_equal_to(value)
    value = format_date(value) if value.is_a?(Date) || value.is_a?(Time)
    @range_last = "#{value}#{LESS_THAN_OR_EQUAL_TO}"
    self
  end

  # Builds a composite query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#the-boolean-operator-and The Boolean Operator AND ("&&")
  #
  # @param another [LSolr] another query builder instance
  #
  # @return [LSolr] copied another query builder instance
  def and(another)
    link(another, AND)
  end

  # Builds a composite query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#boolean-operators-supported-by-the-standard-query-parser Boolean Operators Supported by the Standard Query Parser
  #
  # @param another [LSolr] another query builder instance
  #
  # @return [LSolr] copied another query builder instance
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
         .tr(symbols.join, REPLACEMENT_CHAR)
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

  def format_date(date)
    msec_str = case date
               when Date then date.strftime(FORMAT_MILLISECOND_FOR_DATE_TYPE).gsub(date.strftime(FORMAT_SECOND), '')
               when Time then date.strftime(FORMAT_MILLISECOND_FOR_TIME_TYPE)
               else raise ArgumentError, "Unknown type #{date.inspect}"
               end

    return date.strftime(FORMAT_DATE_TIME) if msec_str == '000'

    "#{date.strftime('%Y-%m-%dT%H:%M:%S')}.#{msec_str}Z"
  end
end
