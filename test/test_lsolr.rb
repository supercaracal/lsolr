# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/.bundle/'
  add_filter '/test/'
end

require 'minitest/autorun'
require 'time'
require 'lsolr'

class TestLSolr < Minitest::Test
  def test_build
    params = { field1: 'value', field2: true }
    assert_instance_of LSolr, LSolr.build(params)
    assert_instance_of LSolr, LSolr.build(field1: 'value', field2: true)
    assert_instance_of LSolr, LSolr.build('field1:value AND field2:true')
    assert_instance_of LSolr, LSolr.build(field: [])
    assert_raises(LSolr::ArgumentError) { LSolr.build(f: nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.build(f: {}) }
    assert_raises(LSolr::ArgumentError) { LSolr.build([]) }
    assert_raises(LSolr::ArgumentError) { LSolr.build(nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.build(0) }
    assert_raises(LSolr::ArgumentError) { LSolr.build(0.1) }
  end

  def test_initialize
    assert_instance_of LSolr, LSolr.new
    assert_instance_of LSolr, LSolr.new(nil)
    assert_instance_of LSolr, LSolr.new(:field)
    assert_instance_of LSolr, LSolr.new('field')
    assert_raises(LSolr::ArgumentError) { LSolr.new('') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:'') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(0) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(0.1) }
    assert_raises(LSolr::ArgumentError) { LSolr.new([]) }
    assert_raises(LSolr::ArgumentError) { LSolr.new({}) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(false) }
  end

  def test_to_s
    assert_equal 'field:value', LSolr.new(:field).match('value').to_s
    assert_raises(LSolr::IncompleteQueryError) { LSolr.new.to_s }
    assert_raises(LSolr::IncompleteQueryError) { LSolr.new(nil).to_s }
    assert_raises(LSolr::IncompleteQueryError) { LSolr.new(:field).to_s }
    assert_raises(LSolr::IncompleteQueryError) { LSolr.new(:field).match('').to_s }
    assert_raises(LSolr::IncompleteQueryError) { LSolr.new(:field).greater_than_or_equal_to(0).to_s }
    assert_raises(LSolr::IncompleteQueryError) { LSolr.new(:field).less_than_or_equal_to(0).to_s }
  end

  def test_to_str
    assert_equal 'field:value', LSolr.new(:field).match('value').to_str
  end

  def test_inspect
    assert_match(/\A#<LSolr:0x[a-z0-9]{16} ``>\z/, LSolr.new.inspect)
    assert_match(/\A#<LSolr:0x[a-z0-9]{16} `f:1`>\z/, LSolr.new(:f).match(1).inspect)
    assert_match(/\A#<LSolr:0x[a-z0-9]{16} `f:1 AND g:2`>\z/, LSolr.new(:f).match(1).and(LSolr.new(:g).match(2)).inspect)
  end

  def test_blank?
    assert_equal true, LSolr.new.blank?
    assert_equal true, LSolr.new(nil).blank?
    assert_equal true, LSolr.new(:field).blank?
    assert_equal false, LSolr.new(:field).match('word').blank?
    assert_equal true, LSolr.new(:field).match('').blank?
    assert_equal false, LSolr.new(:field).greater_than(0).less_than_or_equal_to(1).blank?
    assert_equal true, LSolr.new(:field).greater_than_or_equal_to(0).blank?
    assert_equal true, LSolr.new(:field).greater_than(0).blank?
    assert_equal true, LSolr.new(:field).less_than_or_equal_to(0).blank?
    assert_equal true, LSolr.new(:field).less_than(0).blank?
    assert_equal false, LSolr.new.raw('field:value').blank?
  end

  def test_present?
    assert_equal false, LSolr.new.present?
    assert_equal false, LSolr.new(nil).present?
    assert_equal false, LSolr.new(:field).present?
    assert_equal true, LSolr.new(:field).match('word').present?
    assert_equal false, LSolr.new(:field).match('').present?
    assert_equal true, LSolr.new(:field).greater_than_or_equal_to(0).less_than(1).present?
    assert_equal false, LSolr.new(:field).greater_than_or_equal_to(0).present?
    assert_equal false, LSolr.new(:field).greater_than(0).present?
    assert_equal false, LSolr.new(:field).less_than_or_equal_to(0).present?
    assert_equal false, LSolr.new(:field).less_than(0).present?
    assert_equal true, LSolr.new.raw('field:value').present?
  end

  def test_field
    assert_instance_of LSolr, LSolr.new.field('field')
    assert_instance_of LSolr, LSolr.new.field(:field)
    assert_equal 'field:value', LSolr.new.field(:field).match('value').to_s
    assert_raises(LSolr::ArgumentError) { LSolr.new.field(nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.field('') }
    assert_raises(LSolr::ArgumentError) { LSolr.new.field(:'') }
    assert_raises(LSolr::ArgumentError) { LSolr.new.field(0) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.field(0.1) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.field(false) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.field([]) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.field({}) }
  end

  def test_raw
    assert_instance_of LSolr, LSolr.new.raw('field:value')
    assert_equal 'field:value', LSolr.new.raw('field:value').to_s
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw(nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw('') }
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw(:'') }
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw(0) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw(0.1) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw(false) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw([]) }
    assert_raises(LSolr::ArgumentError) { LSolr.new.raw({}) }
  end

  def test_wrap
    assert_equal '(field:word)', LSolr.new(:field).match('word').wrap.to_s
    assert_equal '(field:word)', LSolr.new(:field).wrap.match('word').to_s
    assert_equal '(((field:word)))', LSolr.new(:field).match('word').wrap.wrap.wrap.to_s

    instance = LSolr.new(:field).match('word')
    assert !instance.equal?(instance.wrap)

    incomplete_term = LSolr.new(:dummy)
    term = LSolr.new(:field).match('word')
    assert_instance_of LSolr, incomplete_term.wrap
    assert_equal '(field:word)', incomplete_term.and(term).wrap.to_s
    assert_equal '(field:word)', term.and(incomplete_term).wrap.to_s
    assert_instance_of LSolr, incomplete_term.and(incomplete_term).wrap
    assert_raises(LSolr::IncompleteQueryError) { incomplete_term.and(incomplete_term).wrap.to_s }

    assert_equal '(f:1 AND g:2)', LSolr.new.raw('f:1').and(LSolr.new(:g).match(2)).wrap.to_s
    assert_equal '(f:1 AND g:2)', LSolr.new(:f).match(1).and(LSolr.new.raw('g:2')).wrap.to_s
  end

  def test_not
    assert_equal 'NOT field:word', LSolr.new(:field).not.match('word').to_s
    assert_equal 'NOT field:word', LSolr.new(:field).match('word').not.to_s
    assert_equal 'NOT field:(1 2 3)', LSolr.new(:field).match_in([1, 2, 3]).not.to_s

    cond1 = LSolr.new(:field1).match('word1')
    cond2 = LSolr.new(:field2).not.match('word2')
    assert_equal 'NOT (field1:word1 AND NOT field2:word2)', cond1.and(cond2).wrap.not.to_s

    assert_equal 'NOT f:1 AND g:2', LSolr.new.raw('f:1').and(LSolr.new(:g).match(2)).not.to_s
    assert_equal 'NOT f:1 AND g:2', LSolr.new(:f).match(1).and(LSolr.new.raw('g:2')).not.to_s

    assert_equal 'f:1 AND NOT g:2', LSolr.new.raw('f:1').and(LSolr.new(:g).match(2).not).to_s
    assert_equal 'f:1 AND NOT g:2', LSolr.new(:f).match(1).and(LSolr.new.raw('g:2').not).to_s
  end

  def test_boost
    assert_equal 'field:word^1.0', LSolr.new(:field).match('word').boost(1.0).to_s
    assert_equal 'field:word^1.0', LSolr.new(:field).boost(1.0).match('word').to_s
    assert_equal 'field:word^0.1', LSolr.new(:field).boost(0.1).match('word').to_s
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').boost(0.0) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').boost(-0.1) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').boost(nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').boost('') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').boost(:'') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').boost([]) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').boost({}) }
    assert_equal 'f:1^0.5 AND g:2', LSolr.new(:f).match(1).boost(0.5).and(LSolr.new(:g).match(2)).to_s
    assert_equal 'f:1 AND g:2^0.5', LSolr.new(:f).match(1).and(LSolr.new(:g).match(2).boost(0.5)).to_s
    assert_equal 'f:1 AND g:2^0.5', LSolr.new(:f).match(1).and(LSolr.new(:g).match(2)).boost(0.5).to_s
    assert_equal '(f:1 AND g:2)^0.5', LSolr.new(:f).match(1).and(LSolr.new(:g).match(2)).wrap.boost(0.5).to_s
  end

  def test_constant_score
    assert_equal 'field:word^=1.0', LSolr.new(:field).match('word').constant_score(1.0).to_s
    assert_equal 'field:word^=1.0', LSolr.new(:field).constant_score(1.0).match('word').to_s
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').constant_score(nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').constant_score('') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').constant_score(:'') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').constant_score([]) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match('word').constant_score({}) }
    assert_equal 'f:1^=0.5 AND g:2', LSolr.new(:f).match(1).constant_score(0.5).and(LSolr.new(:g).match(2)).to_s
    assert_equal 'f:1 AND g:2^=0.5', LSolr.new(:f).match(1).and(LSolr.new(:g).match(2).constant_score(0.5)).to_s
    assert_equal 'f:1 AND g:2^=0.5', LSolr.new(:f).match(1).and(LSolr.new(:g).match(2)).constant_score(0.5).to_s
    assert_equal '(f:1 AND g:2)^=0.5', LSolr.new(:f).match(1).and(LSolr.new(:g).match(2)).wrap.constant_score(0.5).to_s
  end

  def test_match
    assert_equal 'field:word', LSolr.new(:field).match('word').to_s
    assert_equal 'field:word', LSolr.new(:field).match(%q[- + & | ! ( ) { } [ ] ^ " ~ * ? : \ /word]).to_s
    assert_equal 'field:"Tiffany Co."', LSolr.new(:field).match('Tiffany&Co.').to_s
    assert_equal 'field:\\NOTword\\ANDword\\ORword', LSolr.new(:field).match('NOTwordANDwordORword').to_s
    assert_equal 'field:not1and2or3', LSolr.new(:field).match('not1and2or3').to_s
  end

  def test_match_in
    assert_equal 'field:(1 2 3)', LSolr.new(:field).match_in([1, 2, 3]).to_s
    assert_equal 'field:(a b c)', LSolr.new(:field).match_in(%w[a b c]).to_s
    assert_equal 'field:(a b c)', LSolr.new(:field).match_in(%i[a b c]).to_s
    assert_equal 'field:(true false)', LSolr.new(:field).match_in([true, false]).to_s
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in(nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in('') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in(:'') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in({}) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in([]) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in([nil]) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in(['']) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in(0) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in(0.1) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).match_in(false) }
  end

  def test_date_time_match
    assert_equal 'field:"2000-01-01T12:00:00Z"', LSolr.new(:field).date_time_match('2000-01-01T12:00:00Z').to_s
    assert_equal 'field:"2000-01-01T12:00:00Z"', LSolr.new(:field).date_time_match(Time.new(2000, 1, 1, 12, 0, 0)).to_s
    assert_equal 'field:"2000-01-01T00:00:00Z"', LSolr.new(:field).date_time_match(Date.new(2000, 1, 1)).to_s
    assert_equal 'field:"2000-04-05T06:07:08.256Z"', LSolr.new(:field).date_time_match(Time.parse('2000-04-05 06:07:08.256')).to_s
    assert_equal 'field:"NOW+9HOURS-7DAYS"', LSolr.new(:field).date_time_match('NOW+9HOURS-7DAYS').to_s
  end

  def test_prefix_match
    assert_equal 'field:Soo*o??olr', LSolr.new(:field).prefix_match('Soo*o??olr').to_s
    assert_equal 'field:Sooo*ooolr', LSolr.new(:field).prefix_match('Sooo&|ooolr').to_s
  end

  def test_phrase_match
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2]).to_s
    assert_equal 'field:"word1 word2"~10', LSolr.new(:field).phrase_match(%w[word1 word2], distance: 10).to_s
    assert_equal 'field:"boo foo woo"~10', LSolr.new(:field).phrase_match(%w[boo&foo woo], distance: 10).to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: '').to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: :'').to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: nil).to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: false).to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: []).to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: {}).to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: 0).to_s
    assert_equal 'field:"word1 word2"', LSolr.new(:field).phrase_match(%w[word1 word2], distance: -1).to_s
  end

  def test_fuzzy_match
    assert_equal 'field:word~0.0', LSolr.new(:field).fuzzy_match('word', distance: 0.0).to_s
    assert_equal 'field:word~2.0', LSolr.new(:field).fuzzy_match('word', distance: 2.0).to_s
    assert_equal 'field:word~2.0', LSolr.new(:field).fuzzy_match('word').to_s
    assert_equal 'field:word~2.0', LSolr.new(:field).fuzzy_match('wo|rd').to_s
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: -0.1) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: 2.1) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: '') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: :'') }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: nil) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: false) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: []) }
    assert_raises(LSolr::ArgumentError) { LSolr.new(:field).fuzzy_match('word', distance: {}) }
  end

  def test_range_search
    assert_equal 'field:{10 TO 20}', LSolr.new(:field).greater_than(10).less_than(20).to_s
    assert_equal 'field:{10 TO 20]', LSolr.new(:field).greater_than(10).less_than_or_equal_to(20).to_s
    assert_equal 'field:[10 TO 20}', LSolr.new(:field).greater_than_or_equal_to(10).less_than(20).to_s
    assert_equal 'field:[10 TO 20]', LSolr.new(:field).greater_than_or_equal_to(10).less_than_or_equal_to(20).to_s
    assert_equal 'field:[* TO *]', LSolr.new(:field).greater_than_or_equal_to('*').less_than_or_equal_to('*').to_s
    assert_equal 'field:{* TO *}', LSolr.new(:field).greater_than('*').less_than('*').to_s
    assert_equal 'field:[-10.5 TO 20.7]', LSolr.new(:field).greater_than_or_equal_to(-10.5).less_than_or_equal_to(20.7).to_s
    assert_equal 'field:[NOW+9HOURS-7DAYS TO *]', LSolr.new(:field).greater_than_or_equal_to('NOW+9HOURS-7DAYS').less_than_or_equal_to('*').to_s

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
    term1 = LSolr.new(:field1).match('word1')
    term2 = LSolr.new(:field2).match('word2')
    composite = term1.and(term2)

    assert_instance_of LSolr, composite
    assert !term1.equal?(composite)
    assert !term2.equal?(composite)
    assert_equal 'field1:word1 AND field2:word2', composite.to_s

    assert_equal 'f:1 AND g:2', LSolr.build(f: 1).and(g: 2).to_s
    assert_equal 'f:1 AND g:2', LSolr.build(f: 1).and('g:2').to_s

    assert_equal 'f:1', LSolr.new(:f).match(1).and(nil).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).and(:'').to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).and(0).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).and(0.1).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).and(false).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).and([]).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).and({}).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).and('').to_s
  end

  def test_or
    term1 = LSolr.new(:field1).match('word1')
    term2 = LSolr.new(:field2).match('word2')
    composite = term1.or(term2)

    assert_instance_of LSolr, composite
    assert !term1.equal?(composite)
    assert !term2.equal?(composite)
    assert_equal 'field1:word1 OR field2:word2', composite.to_s

    assert_equal 'f:1 OR g:2', LSolr.build(f: 1).or(g: 2).to_s
    assert_equal 'f:1 OR g:2', LSolr.build(f: 1).or('g:2').to_s

    assert_equal 'f:1', LSolr.new(:f).match(1).or(nil).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).or(:'').to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).or(0).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).or(0.1).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).or(false).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).or([]).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).or({}).to_s
    assert_equal 'f:1', LSolr.new(:f).match(1).or('').to_s
  end

  def test_constant_score_takes_priority_over_boost_factor
    assert_equal 'f:1^=0.6', LSolr.new(:f).match(1).boost(0.5).constant_score(0.6).to_s
    assert_equal 'f:1^=0.6', LSolr.new(:f).match(1).constant_score(0.6).boost(0.5).to_s
  end

  def test_can_build_from_hash_object
    params = {
      field01: 'hoge',
      field02: :fuga,
      field03: 14,
      field04: 7.3,
      field05: true,
      field06: false,
      field07: Date.new(7000, 7, 1),
      field08: DateTime.new(6000, 5, 31, 6, 31, 43), # rubocop:disable Style/DateTime
      field09: Time.new(5000, 6, 30, 12, 59, 3),
      field10: LSolr.new(:field10).fuzzy_match('foo'),
      field11: [1, 2, 3],
      field12: 1..10,
      field13: 20...40,
      field14: Date.new(3000, 1, 1)..Date.new(4000, 12, 31),
      field15: (3.0..4.0).step(0.1)
    }

    expected =
      'field01:hoge AND '\
      'field02:fuga AND '\
      'field03:14 AND '\
      'field04:7.3 AND '\
      'field05:true AND '\
      'field06:false AND '\
      'field07:"7000-07-01T00:00:00Z" AND '\
      'field08:"6000-05-31T06:31:43Z" AND '\
      'field09:"5000-06-30T12:59:03Z" AND '\
      'field10:foo~2.0 AND '\
      'field11:(1 2 3) AND '\
      'field12:[1 TO 10] AND '\
      'field13:[20 TO 40} AND '\
      'field14:[3000-01-01T00:00:00Z TO 4000-12-31T00:00:00Z] AND '\
      'field15:[3.0 TO 4.0]'

    assert_equal expected, LSolr.build(params).to_s
  end

  def test_can_build_from_hash_parameters
    assert_equal 'field1:value AND field2:true', LSolr.build(field1: 'value', field2: true).to_s
  end

  def test_can_build_from_string
    assert_equal 'field1:value AND field2:true', LSolr.build('field1:value AND field2:true').to_s
    assert_equal 'It does not change anything.', LSolr.build('It does not change anything.').to_s
  end

  def test_can_build_with_any_matchers
    bool1 = LSolr.new(:bool_field).match(true)
    bool2 = LSolr.new(:bool_field).match(false)
    date1 = LSolr.new(:date_field1).greater_than_or_equal_to('*').less_than_or_equal_to(Time.new(2000, 6, 30, 23, 59, 59))
    date2 = LSolr.new(:date_field2).greater_than(Time.new(2000, 7, 1, 0, 0, 0)).less_than(Time.new(2001, 1, 1, 0, 0, 0))

    left = bool1.and(date1).and(date2).wrap
    right = bool2.and(date1.or(date2).wrap).wrap

    expected =
      '(bool_field:true AND date_field1:[* TO 2000-06-30T23:59:59Z] AND date_field2:{2000-07-01T00:00:00Z TO 2001-01-01T00:00:00Z})'\
      ' OR (bool_field:false AND (date_field1:[* TO 2000-06-30T23:59:59Z] OR date_field2:{2000-07-01T00:00:00Z TO 2001-01-01T00:00:00Z}))'

    assert_equal expected, left.or(right).to_s
  end

  def test_can_build_with_higher_order_functions
    actual = %w[a b c].map { |v| LSolr.new(:field).prefix_match("#{v}*") }
                      .reduce { |a, e| a.or(e) }
                      .wrap.not.to_s
    assert_equal 'NOT (field:a* OR field:b* OR field:c*)', actual
  end

  def test_can_build_with_raw_queries
    assert_equal 'a:1 AND b:2', LSolr.build('a:1').and(b: 2).to_s
  end

  def test_can_build_complex_query
    q = LSolr.build(f: 1)
    q1 = q.wrap.and(q)
    q2 = q.and(q.wrap)
    q3 = q1.wrap.or(q2.wrap)
    q4 = q3.wrap.not

    assert_equal 'f:1', q.to_s
    assert_equal '(f:1) AND f:1', q1.to_s
    assert_equal 'f:1 AND (f:1)', q2.to_s
    assert_equal '((f:1) AND f:1) OR (f:1 AND (f:1))', q3.to_s
    assert_equal 'NOT (((f:1) AND f:1) OR (f:1 AND (f:1)))', q4.to_s
  end

  def test_can_build_with_incomplete_term
    incomplete_term = LSolr.new(:dummy)
    q = LSolr.build(f: 1)

    assert_equal 'f:1', incomplete_term.and(q).to_s
    assert_equal 'f:1', q.and(incomplete_term).to_s

    assert_equal 'f:1', incomplete_term.or(q).to_s
    assert_equal 'f:1', q.or(incomplete_term).to_s
  end
end
