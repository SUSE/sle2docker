require_relative 'test_helper'

# rubocop:disable Metrics/LineLength, Metrics/BlockLength
class RootFSImageTest < MiniTest::Test
  describe 'RootFSImage' do
    before do
      @options = { password: '', tag_with_build: false }
    end

    after do
      FakeFS::FileSystem.clear
    end

    describe 'listing' do
      it 'works when no pre-built image is available' do
        actual = Sle2Docker::RootFSImage.list
        expected = []
        assert_equal expected, actual
      end

      it 'lists the names of the available images' do
        FakeFS do
          expected = [
            'sles11sp3-docker.x86_64-1.0.0-Build1.3',
            'sles12-docker.x86_64-1.0.0-Build7.2'
          ]

          FileUtils.mkdir_p(Sle2Docker::RootFSImage::IMAGES_DIR)
          expected.each do |image|
            FileUtils.touch(
              File.join(
                Sle2Docker::RootFSImage::IMAGES_DIR,
                "#{image}.tar.xz"
              )
            )
          end

          actual = Sle2Docker::RootFSImage.list
          assert_equal expected, actual
        end
      end
    end
  end
end

# rubocop:disable Style/IndentHeredoc
class RootFSImageTest < MiniTest::Test
  describe 'RootFSImage' do
    before do
      @options = { password: '', tag_with_build: false }
    end

    after do
      FakeFS::FileSystem.clear
    end

    describe 'activation' do
      it 'creates a Dockerfile and builds the image' do
        begin
          image = 'sles12-docker.x86_64-1.0.0-Build7.2'
          prebuilt_image = Sle2Docker::RootFSImage.new(image, @options)
          expected = <<DOCKERFILE
FROM scratch
MAINTAINER "Flavio Castelli <fcastelli@suse.com>"

ADD sles12-docker.x86_64-1.0.0-Build7.2.tar.xz /
DOCKERFILE

          tmp_dir = Dir.mktmpdir('sle2docker-test')
          prebuilt_image.create_dockerfile(tmp_dir)
          dockerfile = File.join(tmp_dir, 'Dockerfile')

          assert File.exist?(dockerfile)
          assert_equal(expected, File.read(dockerfile))
        ensure
          FileUtils.rm_rf(tmp_dir) if tmp_dir && File.exist?(tmp_dir)
        end
      end

      it 'triggers docker build' do
        File.stubs(:exist?).returns(true)
        tmp_dir = '/foo'
        mocked_image = mock
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => '1.0.0')
                    .once
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => 'latest')
                    .once

        prebuilt_image = Sle2Docker::RootFSImage.new(
          'sles12-docker.x86_64-1.0.0-Build7.2',
          @options
        )
        img_file = File.join(
          Sle2Docker::RootFSImage::IMAGES_DIR,
          'sles12-docker.x86_64-1.0.0-Build7.2.tar.xz'
        )
        prebuilt_image.expects(:prepare_docker_build_root).once.returns(tmp_dir)
        prebuilt_image.expects(:`).with("rpm -qf #{img_file}")
                      .once.returns('sles12-docker')
        prebuilt_image.expects(:`).with('rpm --verify sles12-docker').once
        Docker::Image.expects(:build_from_dir).with(tmp_dir).once.returns(mocked_image)
        FileUtils.expects(:rm_rf).with(tmp_dir).once

        prebuilt_image.activate
      end

      it 'triggers docker build and tags with build #' do
        @options['tag_with_build'] = true
        File.stubs(:exist?).returns(true)
        tmp_dir = '/foo'
        mocked_image = mock
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => '1.0.0-7.2')
                    .once
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => 'latest')
                    .once

        prebuilt_image = Sle2Docker::RootFSImage.new(
          'sles12-docker.x86_64-1.0.0-Build7.2',
          @options
        )
        prebuilt_image.expects(:prepare_docker_build_root).once.returns(tmp_dir)
        prebuilt_image.expects(:verify_image).once
        Docker::Image.expects(:build_from_dir).with(tmp_dir).once.returns(mocked_image)
        FileUtils.expects(:rm_rf).with(tmp_dir).once

        prebuilt_image.activate
      end

      it 'triggers docker build and tags with build# (build# empty)' do
        @options['tag_with_build'] = true
        File.stubs(:exist?).returns(true)
        tmp_dir = '/foo'
        mocked_image = mock
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => '1.0.0-0.0')
                    .once
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => 'latest')
                    .once

        prebuilt_image = Sle2Docker::RootFSImage.new(
          'sles12-docker.x86_64-1.0.0-Build',
          @options
        )
        prebuilt_image.expects(:prepare_docker_build_root).once.returns(tmp_dir)
        prebuilt_image.expects(:verify_image).once
        Docker::Image.expects(:build_from_dir).with(tmp_dir).once.returns(mocked_image)
        FileUtils.expects(:rm_rf).with(tmp_dir).once

        prebuilt_image.activate
      end
    end
  end
end
# rubocop:enable Style/IndentHeredoc, Metrics/LineLength, Metrics/BlockLength
