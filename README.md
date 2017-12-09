[![Build Status](https://travis-ci.org/supercaracal/lsolr.svg?branch=master)](https://travis-ci.org/supercaracal/lsolr)
[![Gem Version](https://badge.fury.io/rb/lsolr.svg)](https://badge.fury.io/rb/lsolr)

# LSolr
A query builder of Apache Solr standard Lucene type query for Ruby.

## Installation

```
$ gem install lsolr
```

## Example

```ruby
require 'lsolr'

LSolr.build(term1: 'hoge', term2: true).to_s
#=> 'term1:hoge AND term2:true'
```

```ruby
require 'lsolr'

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

LSolr.build(params).to_s
#=> 'term01:hoge AND term02:fuga AND term03:14 AND term04:7.3 AND term05:true AND term06:false
#    AND term07:"7000-07-01T00:00:00Z" AND term08:"6000-05-31T06:31:43Z" AND term09:"5000-06-30T12:59:03Z"
#    AND term10:foo~2.0 AND (term11:1 OR term11:2 OR term11:3) AND term12:[1 TO 10] AND term13:[20 TO 40}
#    AND term14:[3000-01-01T00:00:00Z TO 4000-12-31T00:00:00Z] AND term15:[3.0 TO 4.0]'
```

```ruby
require 'lsolr'

monoclinic = LSolr.new(:crystal_system).match(:monoclinic)
cubic = LSolr.new(:crystal_system).match(:cubic)
soft = LSolr.new(:mohs_scale).greater_than_or_equal_to('*').less_than(5.0)
hard = LSolr.new(:mohs_scale).greater_than_or_equal_to(5.0).less_than_or_equal_to(10.0)

phosphophyllite = monoclinic.and(soft).wrap
diamond = cubic.and(hard).wrap

phosphophyllite.or(diamond).to_s
#=> '(crystal_system:monoclinic AND mohs_scale:[* TO 5.0}) OR (crystal_system:cubic AND mohs_scale:[5.0 TO 10.0])'
```

## See also
* [The Standard Query Parser](https://lucene.apache.org/solr/guide/7_1/the-standard-query-parser.html)
* [RSolr](https://github.com/rsolr/rsolr)
* [Ruby Doc](http://www.rubydoc.info/github/supercaracal/lsolr/LSolr)
* [Gem Guide](http://guides.rubygems.org/make-your-own-gem/)

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
