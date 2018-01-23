require_relative 'test_helper'

# rubocop:disable Metrics/BlockLength
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

  describe 'Activate images' do
    it 'activates a single native image' do
      Sle2Docker::RootFSImage.stubs(:list).returns([])
      Sle2Docker::NativeImage.stubs(:list).returns(
        ['sles12sp3-container.x86_64-2.0.1-Build2.3.docker']
      )
      Docker.expects(:info)

      mocked_image = mock
      mocked_image.expects(:image_id).once.returns('repo:tag')
      mocked_image.expects(:activated?).once.returns(false)
      mocked_image.expects(:activate).once

      Sle2Docker::NativeImage.expects(:new).once.returns(mocked_image)

      argv = ['activate', 'sles12sp3-container.x86_64-2.0.1-Build2.3.docker']
      Sle2Docker::Cli.start(argv)
    end

    it 'activates a single rootfs image' do
      Sle2Docker::RootFSImage.stubs(:list).returns(
        ['sles12-docker.x86_64-1.0.0-Build7.2']
      )
      Sle2Docker::NativeImage.stubs(:list).returns([])
      Docker.expects(:info)

      mocked_image = mock
      mocked_image.expects(:image_id).once.returns('repo:tag')
      mocked_image.expects(:activated?).once.returns(false)
      mocked_image.expects(:activate).once

      Sle2Docker::RootFSImage.expects(:new).once.returns(mocked_image)

      argv = ['activate', 'sles12-docker.x86_64-1.0.0-Build7.2']
      Sle2Docker::Cli.start(argv)
    end
  end
end
# rubocop:enable Metrics/BlockLength
