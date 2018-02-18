[![Build Status](https://travis-ci.org/supercaracal/lsolr.svg?branch=master)](https://travis-ci.org/supercaracal/lsolr)
[![Gem Version](https://badge.fury.io/rb/lsolr.svg)](https://badge.fury.io/rb/lsolr)
[![Maintainability](https://api.codeclimate.com/v1/badges/8535ace1024f07a2f857/maintainability)](https://codeclimate.com/github/supercaracal/lsolr/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/8535ace1024f07a2f857/test_coverage)](https://codeclimate.com/github/supercaracal/lsolr/test_coverage)
[![Issue Count](https://codeclimate.com/github/supercaracal/lsolr/badges/issue_count.svg)](https://codeclimate.com/github/supercaracal/lsolr/issues)

# LSolr
LSolr is a query builder for Apache Solr in Ruby. It keeps one direction linked list internally.

```
term = field:value = a LSolr instance

     AND      AND      AND     AND
     OR       OR       OR      OR
term <-- term <-- term <-- ... <-- term
```

It supports only [the standard query](https://lucene.apache.org/solr/guide/7_2/the-standard-query-parser.html).
It isn't Apache Solr client. It has only feature as query builder. Please use it with [RSolr](https://github.com/rsolr/rsolr).

## Installation

```
$ gem install lsolr
```

## Example

```ruby
require 'lsolr'

LSolr.build(field1: 'hoge', field2: true).to_s
#=> 'field1:hoge AND field2:true'
```

```ruby
require 'lsolr'

params = {
  field01: 'hoge',
  field02: :fuga,
  field03: 14,
  field04: 7.3,
  field05: true,
  field06: false,
  field07: Date.new(7000, 7, 1),
  field08: DateTime.new(6000, 5, 31, 6, 31, 43),
  field09: Time.new(5000, 6, 30, 12, 59, 3),
  field10: LSolr.new(:field10).fuzzy_match('foo'),
  field11: [1, 2, 3],
  field12: 1..10,
  field13: 20...40,
  field14: Date.new(3000, 1, 1)..Date.new(4000, 12, 31),
  field15: (3.0..4.0).step(0.1)
}

LSolr.build(params).to_s
#=> 'field01:hoge AND
#    field02:fuga AND
#    field03:14 AND
#    field04:7.3 AND
#    field05:true AND
#    field06:false AND
#    field07:"7000-07-01T00:00:00Z" AND
#    field08:"6000-05-31T06:31:43Z" AND
#    field09:"5000-06-30T12:59:03Z" AND
#    field10:foo~2.0 AND
#    field11:(1 2 3) AND
#    field12:[1 TO 10] AND
#    field13:[20 TO 40} AND
#    field14:[3000-01-01T00:00:00Z TO 4000-12-31T00:00:00Z] AND
#    field15:[3.0 TO 4.0]'
```

```ruby
require 'lsolr'

bool1 = LSolr.new(:bool_field).match(true)
bool2 = LSolr.new(:bool_field).match(false)
date1 = LSolr.new(:date_field1).greater_than_or_equal_to('*').less_than_or_equal_to(Time.new(2000, 6, 30, 23, 59, 59))
date2 = LSolr.new(:date_field2).greater_than(Time.new(2000, 7, 1, 0, 0, 0)).less_than(Time.new(2001, 1, 1, 0, 0, 0))

left = bool1.and(date1).and(date2).wrap
right = bool2.and(date1.or(date2).wrap).wrap

left.or(right).to_s
#=> '(bool_field:true AND date_field1:[* TO 2000-06-30T23:59:59Z] AND date_field2:{2000-07-01T00:00:00Z TO 2001-01-01T00:00:00Z})
#    OR (bool_field:false AND (date_field1:[* TO 2000-06-30T23:59:59Z] OR date_field2:{2000-07-01T00:00:00Z TO 2001-01-01T00:00:00Z}))'
```

```ruby
require 'lsolr'

%w[a b c].map { |v| LSolr.new(:field).prefix_match("#{v}*") }
         .reduce { |a, e| a.or(e) }
         .wrap.not.to_s
#=> 'NOT (field:a* OR field:b* OR field:c*)'
```

```ruby
require 'lsolr'

LSolr.build('a:1').and(b: 2).to_s
#=> 'a:1 AND b:2'
```

## See also
* [The Standard Query Parser](https://lucene.apache.org/solr/guide/7_2/the-standard-query-parser.html)
* [RSolr](https://github.com/rsolr/rsolr)
* [Ruby Doc](http://www.rubydoc.info/github/supercaracal/lsolr/LSolr)
* [Gem Guide](http://guides.rubygems.org/make-your-own-gem/)

## Motivation

We trying to use this gem in web service of our company.  
Our search component has complex features.  
So we should implement as polymorphic class each search parameters.  
We think this gem fit in implementation like that.
