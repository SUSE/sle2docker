require_relative 'test_helper'

class PrebuiltImageTest < MiniTest::Test

  describe "PrebuiltImage" do

    before do
      @options = { password: "" }
    end

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

      it "creates a Dockerfile re-using host's credentials" do
        begin
          image = "sles12-docker-image-1.0.0"
          prebuilt_image = Sle2Docker::PrebuiltImage.new(image, @options)
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

      it "creates a Dockerfile using SMT repositories" do
        begin
          image = "sles12-docker-image-1.0.0"
          smt_host = "my-smt.local"
          prebuilt_image = Sle2Docker::PrebuiltImage.new(
            image, {smt_host: smt_host})

          expected = <<EOF
FROM scratch
MAINTAINER "Flavio Castelli <fcastelli@suse.com>"

ADD sles12-docker-image-1.0.0.tar.xz /

RUN zypper ar -f http://my-smt.local/SUSE/Products/SLE-SERVER/12/x86_64/product \"SLE12-Pool\"
RUN zypper ar -f http://my-smt.local/SUSE/Updates/SLE-SERVER/12/x86_64/update \"SLE12-Updates\"

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

          prebuilt_image = Sle2Docker::PrebuiltImage.new('foo', @options)
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

        prebuilt_image = Sle2Docker::PrebuiltImage.new(
          'sles12-docker.x86_64-1.0.0-Build7.2',
          @options
        )
        prebuilt_image.expects(:prepare_docker_build_root).once.returns(tmp_dir)
        prebuilt_image.expects(:verify_image).once
        Docker::Image.expects(:build_from_dir).with(tmp_dir).once.returns(mocked_image)
        FileUtils.expects(:rm_rf).with(tmp_dir).once

        prebuilt_image.activate
      end

    end

    describe "activation of SLE11SP3 pre-built image" do

      it "creates a Dockerfile using NCC repositories" do
        begin
          username = "test_username"
          password = "test_password"
          $stdin = FakeStdin.new([username, password])

          image = "sles11sp3-docker-image-1.0.0"
          prebuilt_image = Sle2Docker::PrebuiltImage.new(image, @options)
          expected = <<EOF
FROM scratch
MAINTAINER "Flavio Castelli <fcastelli@suse.com>"

ADD sles11sp3-docker-image-1.0.0.tar.xz /

RUN zypper ar -f https://nu.novell.com/repo/\\$RCE/SLES11-SP3-Updates/sle-11-x86_64?credentials=NCCcredentials \"SLES11-SP3-Updates\"
RUN zypper ar -f https://nu.novell.com/repo/\\$RCE/SLES11-SP3-Pool/sle-11-x86_64?credentials=NCCcredentials \"SLES11-SP3-Pool\"

RUN mkdir /etc/zypp/credentials.d
RUN echo \"username=test_username\" > /etc/zypp/credentials.d/NCCcredentials
RUN echo \"password=test_password\" > /etc/zypp/credentials.d/NCCcredentials
RUN chmod 600 /etc/zypp/credentials.d/NCCcredentials

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

      it "creates a Dockerfile using SMT repositories" do
        begin
          image = "sles11sp3-docker-image-1.0.0"
          smt_host = "my-smt.local"
          prebuilt_image = Sle2Docker::PrebuiltImage.new(
            image, {smt_host: smt_host})

          expected = <<EOF
FROM scratch
MAINTAINER "Flavio Castelli <fcastelli@suse.com>"

ADD sles11sp3-docker-image-1.0.0.tar.xz /

RUN zypper ar -f https://my-smt.local/repo/\\$RCE/SLES11-SP3-Updates/sle-11-x86_64?credentials=NCCcredentials \"SLES11-SP3-Updates\"
RUN zypper ar -f https://my-smt.local/repo/\\$RCE/SLES11-SP3-Pool/sle-11-x86_64?credentials=NCCcredentials \"SLES11-SP3-Pool\"


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

      it "triggers docker build" do
        FakeFS do
          image_name = 'sles11sp3-docker.x86_64-1.0.0-Build7.2'

          FileUtils.mkdir_p(Sle2Docker::PrebuiltImage::IMAGES_DIR)
          FileUtils.touch("#{Sle2Docker::PrebuiltImage::IMAGES_DIR}/#{image_name}.tar.xz")

          mocked_image = mock()
          mocked_image.expects(:tag)
                      .with({'repo' => 'suse/sles11sp3', 'tag' => '1.0.0'})
                      .once

          prebuilt_image = Sle2Docker::PrebuiltImage.new(
            image_name,
            {smt_host: 'my-smt.local'})
          prebuilt_image.expects(:create_dockerfile).once
          prebuilt_image.expects(:copy_prebuilt_image).once
          prebuilt_image.expects(:copy_zypper_resources).never
          prebuilt_image.expects(:verify_image).once
          Docker::Image.expects(:build_from_dir).once.returns(mocked_image)

          prebuilt_image.activate
        end
      end

    end

  end

end

