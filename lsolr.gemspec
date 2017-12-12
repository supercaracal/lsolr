# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'lsolr'
  s.version     = '0.0.8'
  s.date        = '2017-12-08'
  s.summary     = 'A query builder of Apache Solr for Ruby'
  s.description = 'LSolr is a query builder of Apache Solr standard Lucene type query for Ruby.'
  s.authors     = ['Taishi Kasuga']
  s.email       = 'supercaracal@yahoo.co.jp'
  s.files       = ['lib/lsolr.rb']
  s.homepage    = 'https://github.com/supercaracal/lsolr'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 2.2.2'
end
