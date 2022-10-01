# frozen_string_literal: true

require 'memory_profiler'
require 'lsolr'

module LSolrProfiler
  module_function

  ATTEMPT_COUNT = 1000

  def run
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

    print_letter('LSolr#build')
    profile { LSolr.build(params).to_s }
  end

  def print_letter(title)
    print "################################################################################\n"
    print "# #{title}\n"
    print "################################################################################\n"
    print "\n"
  end

  def profile(&block)
    # https://github.com/SamSaffron/memory_profiler
    report = ::MemoryProfiler.report(top: 20, &block)
    report.pretty_print(color_output: true, normalize_paths: true)
  end
end

LSolrProfiler.run
