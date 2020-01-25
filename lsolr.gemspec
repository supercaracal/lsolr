# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'lsolr'
  s.version     = '1.0.1'
  s.date        = '2020-01-25'
  s.summary     = 'A query builder for Apache Solr in Ruby'
  s.description = 'LSolr is a query builder for Apache Solr in Ruby. It supports only the standard query.'
  s.authors     = ['Taishi Kasuga']
  s.email       = 'supercaracal@yahoo.co.jp'
  s.files       = ['lib/lsolr.rb']
  s.homepage    = 'https://github.com/supercaracal/lsolr'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 2.4.0'
end
