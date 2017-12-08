[![Build Status](https://travis-ci.org/supercaracal/lsolr.svg?branch=master)](https://travis-ci.org/supercaracal/lsolr)

# LSolr
A query builder of Apache Solr standard Lucene type query for Ruby.

# How to use

```ruby
monoclinic = LSolr.new(:crystal_system).match(:monoclinic)
cubic = LSolr.new(:crystal_system).match(:cubic)
soft = LSolr.new(:mohs_scale).greater_than_or_equal_to('*').less_than(5.0)
hard = LSolr.new(:mohs_scale).greater_than_or_equal_to(5.0).less_than_or_equal_to(10.0)

phosphophyllite = monoclinic.and(soft).wrap
diamond = cubic.and(hard).wrap

phosphophyllite.or(diamond).to_s
#=> '(crystal_system:monoclinic AND mohs_scale:[* TO 5.0}) OR (crystal_system:cubic AND mohs_scale:[5.0 TO 10.0])'
```
