require_relative 'test_helper'

# rubocop:disable Metrics/BlockLength
class NativeImageTest < MiniTest::Test
  describe 'NativeImage' do
    after do
      FakeFS::FileSystem.clear
    end

    describe 'listing' do
      it 'works when no pre-built image is available' do
        actual = Sle2Docker::NativeImage.list
        expected = []
        assert_equal expected, actual
      end

      it 'lists the names of the available images' do
        FakeFS do
          expected = [
            'sles11sp3-docker.x86_64-1.0.0-Build1.3',
            'sles12-docker.x86_64-1.0.0-Build7.2'
          ]

          FileUtils.mkdir_p(Sle2Docker::NativeImage::IMAGES_DIR)
          expected.each do |image|
            FileUtils.touch(
              File.join(
                Sle2Docker::NativeImage::IMAGES_DIR,
                "#{image}.tar.xz"
              )
            )
          end

          actual = Sle2Docker::NativeImage.list
          assert_equal expected, actual
        end
      end
    end
  end
end

class NativeImageTest < MiniTest::Test
  describe 'NativeImage' do
    before do
      @options = { tag_with_build: false }
    end

    describe 'activation' do
      it 'triggers docker load' do
        image_file = '/usr/share/suse-docker-images/native/'\
                     'sles12sp3-container.x86_64-2.0.1-Build2.3.docker.tar.xz'
        File.stubs(:exist?).returns(false)
        File.stubs(:exist?).with(image_file).returns(true)
        Docker::Image.expects(:load).with(image_file).once.returns(true)
        File.stubs(:read).returns(
          '{"image": {"name": "repo", "tags": ["tag1","tag2"]}}'
        )
        mocked_image = mock
        mocked_image.expects(:tag)
                    .with('repo' => 'repo', 'tag' => 'latest')
                    .once
        Docker::Image.expects(:get).with('repo:tag1').once.returns(mocked_image)
        native_image = Sle2Docker::NativeImage.new(
          'sles12sp3-container.x86_64-2.0.1-Build2.3.docker',
          @options
        )
        native_image.expects(:verify_image).once
        native_image.activate
      end

      it 'triggers docker load and tags with build' do
        @options['tag_with_build'] = true
        image_file = '/usr/share/suse-docker-images/native/'\
                     'sles12sp3-container.x86_64-2.0.1-Build2.3.docker.tar.xz'
        File.stubs(:exist?).returns(false)
        File.stubs(:exist?).with(image_file).returns(true)
        Docker::Image.expects(:load).with(image_file).once.returns(true)
        File.stubs(:read).returns(
          '{"image": {"name": "repo", "tags": ["tag1","tag2"]}}'
        )
        mocked_image = mock
        mocked_image.expects(:tag)
                    .with('repo' => 'repo', 'tag' => 'latest')
                    .once
        mocked_image.expects(:tag)
                    .with('repo' => 'repo', 'tag' => 'tag1-2.3')
                    .once
        Docker::Image.expects(:get).with('repo:tag1').once.returns(mocked_image)
        native_image = Sle2Docker::NativeImage.new(
          'sles12sp3-container.x86_64-2.0.1-Build2.3.docker',
          @options
        )
        native_image.expects(:verify_image).once
        native_image.activate
      end

      it 'triggers a DockerTagError exception' do
        image_file = '/usr/share/suse-docker-images/native/'\
                     'sles12sp3-container.x86_64-2.0.1-Build2.3.docker.tar.xz'
        File.stubs(:exist?).returns(false)
        File.stubs(:exist?).with(image_file).returns(true)
        File.stubs(:read).returns(
          '{"image": {"name": "repo", "tags": ["","tag2"]}}'
        )
        assert_raises Sle2Docker::DockerTagError do
          Sle2Docker::NativeImage.new(
            'sles12sp3-container.x86_64-2.0.1-Build2.3.docker',
            @options
          )
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
