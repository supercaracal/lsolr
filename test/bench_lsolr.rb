# frozen_string_literal: true

require 'minitest/benchmark'
require 'minitest/autorun'
require 'lsolr'

class BenchmarkLSolr < Minitest::Benchmark
  MIN_THRESHOLD = 0.95

  def bench_build
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

    assert_performance_linear(MIN_THRESHOLD) do |n|
      n.times do
        LSolr.build(params).to_s
      end
    end
  end
end
