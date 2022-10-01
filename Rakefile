# frozen_string_literal: true

require 'rake/testtask'
require 'rubocop/rake_task'

task default: :test

Rake::TestTask.new :test do |t|
  t.libs << :lib
  t.libs << :test
  t.options = '-v'
  t.test_files = ARGV.size > 1 ? ARGV[1..-1] : Dir['test/**/test_*.rb'] # rubocop:disable Style/SlicingWithRange
end

Rake::TestTask.new(:bench) do |t|
  t.libs << :lib
  t.libs << :test
  t.options = '-v'
  t.warning = false
  t.test_files = ARGV.size > 1 ? ARGV[1..-1] : Dir['test/**/bench_*.rb'] # rubocop:disable Style/SlicingWithRange
end

Rake::TestTask.new(:prof) do |t|
  t.libs << :lib
  t.libs << :test
  t.options = '-v'
  t.warning = false
  t.test_files = ARGV.size > 1 ? ARGV[1..-1] : Dir['test/**/prof_*.rb'] # rubocop:disable Style/SlicingWithRange
end

RuboCop::RakeTask.new
