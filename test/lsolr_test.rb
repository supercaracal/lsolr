# frozen_string_literal: true

require 'test/unit'
require 'lsolr'

class LSolrTest < Test::Unit::TestCase
  def test_build
    params = {
      term01: 'hoge',
      term02: :fuga,
      term03: 14,
      term04: 7.3,
      term05: true,
      term06: false,
      term07: Date.new(7000, 7, 1),
      term08: DateTime.new(6000, 5, 31, 6, 31, 43), # rubocop:disable Style/DateTime
      term09: Time.new(5000, 6, 30, 12, 59, 3),
      term10: LSolr.new(:term10).fuzzy_match('foo'),
      term11: [1, 2, 3],
      term12: 1..10,
      term13: 20...40,
      term14: Date.new(3000, 1, 1)..Date.new(4000, 12, 31),
      term15: (3.0..4.0).step(0.1)
    }

    expected = 'term01:hoge AND term02:fuga AND term03:14 AND term04:7.3 AND term05:true AND term06:false'\
      ' AND term07:"7000-07-01T00:00:00Z" AND term08:"6000-05-31T06:31:43Z" AND term09:"5000-06-30T12:59:03Z"'\
      ' AND term10:foo~2.0 AND (term11:1 OR term11:2 OR term11:3) AND term12:[1 TO 10] AND term13:[20 TO 40}'\
      ' AND term14:[3000-01-01T00:00:00Z TO 4000-12-31T00:00:00Z] AND term15:[3.0 TO 4.0]'

    assert_equal expected, LSolr.build(params).to_s
    assert_equal 'term1:hoge AND term2:true', LSolr.build(term1: 'hoge', term2: true).to_s
    assert_raise(ArgumentError, 'Could not build solr query. field: term, value: nil') { LSolr.build(term: nil) }
  end

  def test_initialize
    assert_raise(ArgumentError, 'Please specify a field name.') { LSolr.new('') }
  end

  def test_to_s
    assert_raise(RuntimeError, 'Please specify a search condition.') { LSolr.new(:field).to_s }

    monoclinic = LSolr.new(:crystal_system).match(:monoclinic)
    cubic = LSolr.new(:crystal_system).match(:cubic)
    soft = LSolr.new(:mohs_scale).greater_than_or_equal_to('*').less_than(5.0)
    hard = LSolr.new(:mohs_scale).greater_than_or_equal_to(5.0).less_than_or_equal_to(10.0)

    phosphophyllite = monoclinic.and(soft).wrap
    diamond = cubic.and(hard).wrap

    expected = '(crystal_system:monoclinic AND mohs_scale:[* TO 5.0})'\
      ' OR (crystal_system:cubic AND mohs_scale:[5.0 TO 10.0])'
    assert_equal expected, phosphophyllite.or(diamond).to_s
  end

  def test_blank?
    assert_equal true, LSolr.new(:field).blank?
    assert_equal false, LSolr.new(:field).match('word').blank?
    assert_equal true, LSolr.new(:field).match('').blank?
  end

  def test_present?
    assert_equal false, LSolr.new(:field).present?
    assert_equal true, LSolr.new(:field).match('word').present?
    assert_equal false, LSolr.new(:field).match('').present?
  end

  def test_wrap
    assert_equal '(field:word)', LSolr.new(:field).match('word').wrap.to_s
    assert_equal '(field:word)', LSolr.new(:field).wrap.match('word').to_s
    assert_equal '(((field:word)))', LSolr.new(:field).match('word').wrap.wrap.wrap.to_s

    query = LSolr.new(:field).match('word')
    assert_not_equal query, query.wrap
  end

  def test_not
    assert_equal 'NOT field:word', LSolr.new(:field).not.match('word').to_s
    assert_equal 'NOT field:word', LSolr.new(:field).match('word').not.to_s
  end

  def test_boost
    assert_equal 'field:word^1.5', LSolr.new(:field).match('word').boost(1.5).to_s
    assert_equal 'field:word^1.5', LSolr.new(:field).boost(1.5).match('word').to_s
    assert_equal 'field:word^0.1', LSolr.new(:field).boost(0.1).match('word').to_s
    assert_raise(ArgumentError, 'The boost factor numver must be positive. 0.0 given.') { LSolr.new(:field).match('word').boost(0.0) }
    assert_raise(ArgumentError, 'The boost factor numver must be positive. -0.1 given.') { LSolr.new(:field).match('word').boost(-0.1) }
  end

  def test_match
    assert_equal 'field:word', LSolr.new(:field).match('word').to_s
    assert_equal 'field:word', LSolr.new(:field).match(%q[- + & | ! ( ) { } [ ] ^ " ~ * ? : \ /word]).to_s
    assert_equal 'field:"Tiffany Co."', LSolr.new(:field).match('Tiffany&Co.').to_s
    assert_equal 'field:\\NOTword\\ANDword\\ORword', LSolr.new(:field).match('NOTwordANDwordORword').to_s
    assert_equal 'field:not1and2or3', LSolr.new(:field).match('not1and2or3').to_s
  end

  def test_date_time_match
    assert_equal 'field:"2000-01-01T12:00:00Z"', LSolr.new(:field).date_time_match('2000-01-01T12:00:00Z').to_s
    assert_equal 'field:"2000-01-01T12:00:00Z"', LSolr.new(:field).date_time_match(Time.new(2000, 1, 1, 12, 0, 0)).to_s
    assert_equal 'field:"2000-01-01T00:00:00Z"', LSolr.new(:field).date_time_match(Date.new(2000, 1, 1)).to_s
  end

  def test_prefix_match
    assert_equal 'field:Soo*o??olr', LSolr.new(:field).prefix_match('Soo*o??olr').to_s
    assert_equal 'field:Sooo*ooolr', LSolr.new(:field).prefix_match('Sooo&|ooolr').to_s
  end

  def test_phrase_match
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2]).to_s
    assert_equal 'field:"word1 word2"~10', LSolr.new(:field).phrase_match(%w[word1 word2], distance: 10).to_s
    assert_equal 'field:"boo foo woo"~10', LSolr.new(:field).phrase_match(%w[boo&foo woo], distance: 10).to_s
  end

  def test_fuzzy_match
    assert_equal 'field:word~0.0', LSolr.new(:field).fuzzy_match('word', distance: 0.0).to_s
    assert_equal 'field:word~2.0', LSolr.new(:field).fuzzy_match('word', distance: 2.0).to_s
    assert_equal 'field:word~2.0', LSolr.new(:field).fuzzy_match('word').to_s
    assert_raise(RangeError, 'Out of 0.0..1.0. -0.1 given.') { LSolr.new(:field).fuzzy_match('word', distance: -0.1).to_s }
    assert_raise(RangeError, 'Out of 0.0..1.0. 2.1 given.') { LSolr.new(:field).fuzzy_match('word', distance: 2.1).to_s }
    assert_equal 'field:word~2.0', LSolr.new(:field).fuzzy_match('wo|rd').to_s
  end

  def test_range_search
    assert_equal 'field:{10 TO 20}', LSolr.new(:field).greater_than(10).less_than(20).to_s
    assert_equal 'field:{10 TO 20]', LSolr.new(:field).greater_than(10).less_than_or_equal_to(20).to_s
    assert_equal 'field:[10 TO 20}', LSolr.new(:field).greater_than_or_equal_to(10).less_than(20).to_s
    assert_equal 'field:[10 TO 20]', LSolr.new(:field).greater_than_or_equal_to(10).less_than_or_equal_to(20).to_s

    assert_raise(RuntimeError, 'Please specify a search condition.') { LSolr.new(:field).greater_than(10).to_s }

    from = Date.new(2000, 1, 1)
    to = Date.new(3000, 12, 31)
    assert_equal 'field:{2000-01-01T00:00:00Z TO 3000-12-31T00:00:00Z}', LSolr.new(:field).greater_than(from).less_than(to).to_s
    assert_equal 'field:{2000-01-01T00:00:00Z TO 3000-12-31T00:00:00Z]', LSolr.new(:field).greater_than(from).less_than_or_equal_to(to).to_s
    assert_equal 'field:[2000-01-01T00:00:00Z TO 3000-12-31T00:00:00Z}', LSolr.new(:field).greater_than_or_equal_to(from).less_than(to).to_s
    assert_equal 'field:[2000-01-01T00:00:00Z TO 3000-12-31T00:00:00Z]', LSolr.new(:field).greater_than_or_equal_to(from).less_than_or_equal_to(to).to_s

    from = Time.new(2000, 1, 1, 0, 0, 1)
    to = Time.new(3000, 12, 31, 23, 59, 59)
    assert_equal 'field:{2000-01-01T00:00:01Z TO 3000-12-31T23:59:59Z}', LSolr.new(:field).greater_than(from).less_than(to).to_s
    assert_equal 'field:{2000-01-01T00:00:01Z TO 3000-12-31T23:59:59Z]', LSolr.new(:field).greater_than(from).less_than_or_equal_to(to).to_s
    assert_equal 'field:[2000-01-01T00:00:01Z TO 3000-12-31T23:59:59Z}', LSolr.new(:field).greater_than_or_equal_to(from).less_than(to).to_s
    assert_equal 'field:[2000-01-01T00:00:01Z TO 3000-12-31T23:59:59Z]', LSolr.new(:field).greater_than_or_equal_to(from).less_than_or_equal_to(to).to_s
  end

  def test_and
    query1 = LSolr.new(:field1).match('word1')
    query2 = LSolr.new(:field2).match('word2')
    composite = query1.and(query2)

    assert_equal true, composite.is_a?(LSolr)
    assert_not_equal composite, query1
    assert_not_equal composite, query2
    assert_equal 'field1:word1 AND field2:word2', composite.to_s
  end

  def test_or
    query1 = LSolr.new(:field1).match('word1')
    query2 = LSolr.new(:field2).match('word2')
    composite = query1.or(query2)

    assert_equal true, composite.is_a?(LSolr)
    assert_not_equal composite, query1
    assert_not_equal composite, query2
    assert_equal 'field1:word1 OR field2:word2', composite.to_s
  end
end
