require_relative 'test_helper'

class CommandTest < MiniTest::Test
  describe 'Wrong flag' do
    it 'returns the proper name of the given flag' do
      argv = ['--flag']
      out, err = capture_io do
        Sle2Docker::Cli.start(argv)
      end

      assert out.empty?
      assert_equal "Unknown switches '--flag'\n", err
    end
  end
end
