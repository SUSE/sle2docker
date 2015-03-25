require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require File.expand_path('../../lib/sle2docker', __FILE__)

require 'minitest/autorun'
require 'stringio'
require 'fakefs/safe'

# rubocop:disable Style/Documentation, Lint/Eval

class Object
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end
    result
  end
end

module MiniTest
  class Test
    def read_fixture(name)
      File.read(File.expand_path("../fixtures/#{name}", __FILE__))
    end
  end
end

class FakeStdin
  # @param [Array[String]] fake_input
  def initialize(fake_input)
    @fake_input = fake_input.reverse
  end

  def gets
    @fake_input.pop
  end

  def noecho
    yield(self)
  end
end

require 'mocha/mini_test'

