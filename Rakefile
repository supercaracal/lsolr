# frozen_string_literal: true

require 'rake/testtask'
require 'rubocop/rake_task'

task default: :test

Rake::TestTask.new :test do |t|
  t.libs << :lib
  t.libs << :test
  t.options = '-v'
  t.test_files = ARGV.size > 1 ? ARGV[1..] : Dir['test/**/test_*.rb']
end

Rake::TestTask.new(:bench) do |t|
  t.libs << :lib
  t.libs << :test
  t.options = '-v'
  t.warning = false
  t.test_files = ARGV.size > 1 ? ARGV[1..] : Dir['test/**/bench_*.rb']
end

Rake::TestTask.new(:prof) do |t|
  t.libs << :lib
  t.libs << :test
  t.options = '-v'
  t.warning = false
  t.test_files = ARGV.size > 1 ? ARGV[1..] : Dir['test/**/prof_*.rb']
end

RuboCop::RakeTask.new
