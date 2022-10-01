# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name                              = 'lsolr'
  s.summary                           = 'A query builder for Apache Solr in Ruby'
  s.description                       = 'LSolr is a query builder for Apache Solr in Ruby. It supports only the standard query.'
  s.version                           = '1.0.1'
  s.license                           = 'MIT'
  s.homepage                          = 'https://github.com/supercaracal/lsolr'
  s.authors                           = ['Taishi Kasuga']
  s.email                             = %w[proxy0721@gmail.com]
  s.required_ruby_version             = '>= 2.4.0'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['allowed_push_host']     = 'https://rubygems.org'
  s.files                             = Dir['lib/**/*.rb']
end
