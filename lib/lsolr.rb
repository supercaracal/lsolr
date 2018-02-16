# frozen_string_literal: true

require 'date'

# A query builder of Apache Solr standard Lucene type query for Ruby.
#
# @example How to use. Part 1:
#   LSolr.build(field1: 'hoge', field2: true).to_s
#   #=> 'field1:hoge AND field2:true'
#
# @example How to use. Part 2:
#    params = {
#      field01: 'hoge',
#      field02: :fuga,
#      field03: 14,
#      field04: 7.3,
#      field05: true,
#      field06: false,
#      field07: Date.new(7000, 7, 1),
#      field08: DateTime.new(6000, 5, 31, 6, 31, 43),
#      field09: Time.new(5000, 6, 30, 12, 59, 3),
#      field10: LSolr.new(:field10).fuzzy_match('foo'),
#      field11: [1, 2, 3],
#      field12: 1..10,
#      field13: 20...40,
#      field14: Date.new(3000, 1, 1)..Date.new(4000, 12, 31),
#      field15: (3.0..4.0).step(0.1)
#    }
#
#    LSolr.build(params).to_s
#    #=> 'field01:hoge AND field02:fuga AND field03:14 AND field04:7.3 AND field05:true
#    #    AND field06:false AND field07:"7000-07-01T00:00:00Z" AND field08:"6000-05-31T06:31:43Z"
#    #    AND field09:"5000-06-30T12:59:03Z" AND field10:foo~2.0 AND field11:(1 2 3)
#    #    AND field12:[1 TO 10] AND field13:[20 TO 40} AND field14:[3000-01-01T00:00:00Z TO 4000-12-31T00:00:00Z]
#    #    AND field15:[3.0 TO 4.0]'
#
# @example How to use. Part 3:
#    bool1 = LSolr.new(:bool_field).match(true)
#    bool2 = LSolr.new(:bool_field).match(false)
#    date1 = LSolr.new(:date_field1).greater_than_or_equal_to('*').less_than_or_equal_to(Time.new(2000, 6, 30, 23, 59, 59))
#    date2 = LSolr.new(:date_field2).greater_than(Time.new(2000, 7, 1, 0, 0, 0)).less_than(Time.new(2001, 1, 1, 0, 0, 0))
#
#    left = bool1.and(date1).and(date2).wrap
#    right = bool2.and(date1.or(date2).wrap).wrap
#
#    left.or(right).to_s
#    #=> '(bool_field:true AND date_field1:[* TO 2000-06-30T23:59:59Z] AND date_field2:{2000-07-01T00:00:00Z TO 2001-01-01T00:00:00Z})
#    #    OR (bool_field:false AND (date_field1:[* TO 2000-06-30T23:59:59Z] OR date_field2:{2000-07-01T00:00:00Z TO 2001-01-01T00:00:00Z}))'
#
# @example How to use. Part 4:
#    LSolr.build('field:value').to_s
#    #=> 'field:value'
class LSolr
  ArgumentError = Class.new(::ArgumentError)
  RangeError = Class.new(::RangeError)
  TypeError = Class.new(::TypeError)
  IncompleteQueryError = Class.new(StandardError)

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
  MULTI_VALUE_MATCH_DELIMITER = ' '
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

  attr_accessor :prev, :operator, :left_parentheses, :right_parentheses, :expr_not

  class << self
    # Builds composite query and returns builder instance.
    #
    # @param params [Hash{Symbol => String, Symbol, Integer, Float, true, false, Range, Date, Time, Array<String, Symbol, Integer>}, String] query terms or a raw query
    #
    # @return [LSolr] a instance
    def build(params)
      case params
      when Hash then params.map { |f, v| build_query(f, v) }.reduce { |a, e| a.and(e) }
      when String then new.raw(params)
      else raise TypeError, 'Could not build solr query. Please specify a Hash or String value.'
      end
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
      else raise TypeError, "Could not build solr query. field: #{field}, value: #{value.inspect}"
      end
    end

    def build_array_query(field, values)
      return new(field) if values.empty?

      new(field).match_in(values)
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
  # @param field [String, Symbol] a field name
  # @return [LSolr] a instance
  def initialize(field = '')
    @expr_not = ''
    @field = field.to_s
    @value = ''
    @range_first = ''
    @range_last = ''
    @boost = ''
    @left_parentheses = []
    @right_parentheses = []
    @raw = ''
  end

  # Returns Apache Solr standard lucene type query string.
  #
  # @return [String] a stringified query
  def to_s
    raise IncompleteQueryError, 'Please specify search field and value.' if blank?

    decorate_term_expr_if_needed(build_term_expr)
  end

  alias to_str to_s

  # A query is blank if term is incomplete in expression.
  #
  # @return [true, false]
  def blank?
    managed_query_absence = @field.empty? || (@value.empty? && (@range_first.empty? || @range_last.empty?))
    managed_query_absence && @raw.empty?
  end

  # A query is present if it's not blank.
  #
  # @return [true, false]
  def present?
    !blank?
  end

  # Sets a field name.
  #
  # @param f [String, Symbol] a field name
  #
  # @return [LSolr] self instance
  def field(f)
    @field = f.to_s
    self
  end

  # Sets a raw query.
  #
  # @param q [String] raw query
  #
  # @return [LSolr] self instance
  def raw(q)
    @raw = q.to_s
    self
  end

  # Adds parentheses to query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#grouping-terms-to-form-sub-queries Grouping Terms to Form Sub-Queries
  #
  # @return [LSolr] copied self instance
  def wrap
    this = dup
    this.head.left_parentheses << PARENTHESIS_LEFT
    this.right_parentheses << PARENTHESIS_RIGHT
    this
  end

  # Adds the boolean operator `NOT` to query expression.
  #
  # @see https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html#the-boolean-operator-not The Boolean Operator NOT ("!")
  #
  # @return [LSolr] self instance
  def not
    this = dup
    this.head.expr_not = "#{NOT} "
    this
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

  # Builds a normal multi value query expression.
  #
  # @param value [Array<String, Symbol, Integer>] a search words or a filter values
  #
  # @return [LSolr] self instance
  def match_in(values)
    raise ArgumentError, "#{values.inspect} given. Must be a not empty array." if values.nil? || !values.is_a?(Array) || values.empty?

    values = values.map { |v| clean(v) }
    @value = "(#{values.join(MULTI_VALUE_MATCH_DELIMITER)})"
    self
  end

  # Builds a normal query expression with dates and times.
  #
  # @see https://lucene.apache.org/solr/guide/6_6/working-with-dates.html Working with Dates
  #
  # @param value [String, Date, Time] a filter value
  #
  # @return [LSolr] self instance
  def date_time_match(value)
    value = stringify(value, symbols: RESERVED_SYMBOLS - %w[- : . / +])
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
    @range_first = "#{GREATER_THAN}#{stringify(value)}"
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
    @range_last = "#{stringify(value)}#{LESS_THAN}"
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
    @range_first = "#{GREATER_THAN_OR_EQUAL_TO}#{stringify(value)}"
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
    @range_last = "#{stringify(value)}#{LESS_THAN_OR_EQUAL_TO}"
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

  # Returns a first term of query.
  #
  # @return [LSolr] a first term of query.
  def head
    if !prev.nil? && prev.present?
      prev.head
    else
      self
    end
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

  def raw?
    !@raw.empty?
  end

  def clean(value, symbols: RESERVED_SYMBOLS)
    value.to_s
         .tr(symbols.join, REPLACEMENT_CHAR)
         .gsub(RESERVED_WORDS) { |match| "\\#{match}" }
  end

  def stringify(value, symbols: RESERVED_SYMBOLS - %w[- : . / + *])
    if value.is_a?(Date) || value.is_a?(Time)
      format_date(value)
    else
      clean(value, symbols: symbols)
    end
  end

  def format_date(date)
    msec_str = case date
               when Date then date.strftime(FORMAT_MILLISECOND_FOR_DATE_TYPE).gsub(date.strftime(FORMAT_SECOND), '')
               when Time then date.strftime(FORMAT_MILLISECOND_FOR_TIME_TYPE)
               else raise TypeError, "Could not format dates or times. Given value: #{date.inspect}"
               end

    return date.strftime(FORMAT_DATE_TIME) if msec_str == '000'

    "#{date.strftime('%Y-%m-%dT%H:%M:%S')}.#{msec_str}Z"
  end

  def link(another, operator)
    return self if another.nil? || another.blank?

    another = another.dup
    head = another.head
    head.prev = dup
    head.operator = operator
    another
  end

  def build_term_expr
    if raw?
      @raw
    elsif range_search?
      "#{@field}:#{@range_first} #{TO} #{@range_last}"
    else
      "#{@field}:#{@value}"
    end
  end

  def decorate_term_expr_if_needed(expr)
    expr = "#{expr_not}#{left_parentheses.join}#{expr}#{right_parentheses.join}"
    expr = "#{prev} #{operator} #{expr}" if !prev.nil? && prev.present?
    "#{expr}#{@boost}"
  end
end
