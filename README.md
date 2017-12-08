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
* [The Standard Query Parser](https://lucene.apache.org/solr/guide/6_6/the-standard-query-parser.html)
* [RSolr](https://github.com/rsolr/rsolr)
* [Ruby Doc](http://www.rubydoc.info/github/supercaracal/lsolr/master)
* [Gem Guide](http://guides.rubygems.org/make-your-own-gem/)
