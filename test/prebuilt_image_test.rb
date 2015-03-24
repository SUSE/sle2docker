require_relative 'test_helper'

class PrebuiltImageTest < MiniTest::Test

  describe "PrebuiltImage" do

    after do
      FakeFS::FileSystem.clear
    end

    describe "listing available images" do

      it "works when no pre-built image is available" do
        actual = Sle2Docker::PrebuiltImage.list
        expected = []
        assert_equal expected, actual
      end

      it "lists the names of the available images" do
        FakeFS do
          expected = [
            "sles11sp3-docker.x86_64-1.0.0-Build1.3",
            "sles12-docker.x86_64-1.0.0-Build7.2"
          ]

          FileUtils.mkdir_p(Sle2Docker::PrebuiltImage::IMAGES_DIR)
          expected.each do |image|
            FileUtils.touch(
              File.join(
                Sle2Docker::PrebuiltImage::IMAGES_DIR,
                "#{image}.tar.xz"
              )
            )
          end

          actual = Sle2Docker::PrebuiltImage.list
          assert_equal expected, actual
        end
      end
    end

    describe "activation of SLE12 pre-built image" do

      it "creates a Dockerfile" do
        begin
          image = "sles12-docker-image-1.0.0"
          prebuilt_image = Sle2Docker::PrebuiltImage.new(image, {})
          expected = <<EOF
FROM scratch
MAINTAINER "Flavio Castelli <fcastelli@suse.com>"

ADD sles12-docker-image-1.0.0.tar.xz /

ADD zypp/credentials.d /etc/zypp/credentials.d
ADD zypp/repos.d /etc/zypp/repos.d
ADD zypp/services.d /etc/zypp/services.d

RUN zypper --gpg-auto-import-keys refresh
EOF

          tmp_dir = Dir.mktmpdir("sle2docker-test")
          prebuilt_image.create_dockerfile(tmp_dir)
          dockerfile = File.join(tmp_dir, "Dockerfile")

          assert File.exist?(dockerfile)
          assert_equal(expected, File.read(dockerfile))
        ensure
          if File.exist?(tmp_dir)
            FileUtils.rm_rf(tmp_dir)
          end
        end
      end
    end

    it "copies the right repositories into the build directory" do
      FakeFS do
        zypp_path = "/etc/zypp"

        # setup repos.d
        FileUtils.mkdir_p("#{zypp_path}/repos.d")
        destination = "/tmp/"
        FileUtils.mkdir_p(destination)

        repos_to_copy = 4.times.map{|index| "to_copy_#{index + 1}"}
        (repos_to_copy + ["repo_to_ignore"]).each do |repo|
          FileUtils.touch(File.join(zypp_path, "repos.d", repo) + ".repo")
        end

        # setup credentials.d
        FileUtils.mkdir_p(zypp_path + "/credentials.d")
        FileUtils.touch(zypp_path + "/credentials.d/test_credential")

        # setup credentials.d
        FileUtils.mkdir_p(zypp_path + "/services.d")
        File.open(zypp_path + "/services.d/SLE12.service", "w") do |file|
          file.write(<<EOS
[SUSE_Linux_Enterprise_Server_12_x86_64]
name=SUSE_Linux_Enterprise_Server_12_x86_64
enabled=1
autorefresh=0
url = https://scc.suse.com/access/services/1106?credentials=SUSE_Linux_Enterprise_Server_12_x86_64
type = ris
EOS
          )
          repos_to_copy.each_with_index do |repo_name, index|
            file.write(<<EOS
repo_#{index + 1}=#{repo_name}
repo_#{index + 1}_enabled=1
repo_#{index + 1}_autorefresh=1
EOS
            )
          end
        end

        prebuilt_image = Sle2Docker::PrebuiltImage.new('foo', {})
        prebuilt_image.copy_zypper_resources(destination)

        assert File.exist?(destination + "zypp/repos.d")
        actual = Dir["#{destination}/zypp/repos.d/*.repo"].map{|file| File.basename(file)}
        assert_equal(
          repos_to_copy.map {|repo_name| "#{repo_name}.repo"}.sort,
          actual.sort
        )

        assert File.exist?("#{destination}/zypp/services.d/SLE12.service")
        assert File.exist?("#{destination}/zypp/credentials.d/test_credential")
      end
    end

    it "triggers docker build" do
      File.stubs(:exists?).returns(true)
      tmp_dir = "/foo"
      mocked_image = mock()
      mocked_image.expects(:tag)
                  .with({'repo' => 'suse/sles12', 'tag' => '1.0.0'})
                  .once

      prebuilt_image = Sle2Docker::PrebuiltImage.new('sles12-docker.x86_64-1.0.0-Build7.2', {})
      prebuilt_image.expects(:prepare_docker_build_root).once.returns(tmp_dir)
      Docker::Image.expects(:build_from_dir).with(tmp_dir).once.returns(mocked_image)
      FileUtils.expects(:rm_rf).with(tmp_dir).once

      prebuilt_image.activate
    end

  end

end

