# frozen_string_literal: true

require 'rake/testtask'

task default: :test

desc 'execute all test'
Rake::TestTask.new :test do |t|
  t.libs << :test
  t.libs << :lib
  t.test_files = FileList['test/test_*.rb']
end
