require File.expand_path('../../lib/sle2docker',__FILE__)
require 'bundler/setup' # Use bundled environment for testing
require 'minitest/autorun'
require 'stringio'

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

class MiniTest::Test

  def read_fixture(name)
    File.read(File.expand_path("../fixtures/#{name}", __FILE__))
  end

end

class FakeStdin

  # @param [Array[String]] fake_input
  def initialize(fake_input)
    @fake_input = fake_input.reverse
  end

  def gets()
    @fake_input.pop
  end

  def noecho()
    yield(self)
  end

end

