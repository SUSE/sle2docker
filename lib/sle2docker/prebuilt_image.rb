module Sle2Docker

  class PrebuiltImage

    IMAGES_DIR = "/usr/share/suse-docker-images"

    class SUPPORTED_BASE_SYSTEMS
      SLE11SP3 = "sle11sp3"
      SLE12    = "sle12"
    end

    def self.list
      if File.exists?(PrebuiltImage::IMAGES_DIR)
        Dir[File.join(IMAGES_DIR, "*.tar.xz")].map do |image|
          File.basename(image, ".tar.xz")
        end
      else
        []
      end
    end

    def initialize(image_name, options)
      @image_name = image_name
      @options    = options

      @base_system = if @image_name =~ /\Asle.12/
        SUPPORTED_BASE_SYSTEMS::SLE12
      elsif @image_name =~ /\Asle.11sp3/
        SUPPORTED_BASE_SYSTEMS::SLE11SP3
      end
    end

    def activate
      if !File.exists?(File.join(IMAGES_DIR, "#{@image_name}.tar.xz"))
        raise PrebuiltImageNotFoundError.new("Cannot find pre-built image #{@image_name}")
      end

      verify_image

      tmp_dir = prepare_docker_build_root
      puts "Activating image"
      image = Docker::Image.build_from_dir(tmp_dir)
      image.tag(docker_tag())
    ensure
      if tmp_dir && File.exists?(tmp_dir)
        FileUtils.rm_rf(tmp_dir)
      end
    end

    def prepare_docker_build_root
      tmp_dir = Dir.mktmpdir("sle2docker-#{@image_name}-dockerfile")

      create_dockerfile(tmp_dir)
      copy_prebuilt_image(tmp_dir)
      if @base_system == SUPPORTED_BASE_SYSTEMS::SLE12 && @options[:smt_host].empty?
        copy_zypper_resources(tmp_dir)
      end
      tmp_dir
    end

    def create_dockerfile(tmp_dir)
      repositories  = {}
      credentials   = {}

      case @base_system
      when SUPPORTED_BASE_SYSTEMS::SLE12
        if @options[:smt_host]
          repositories["http://#{@options[:smt_host]}/SUSE/Products/SLE-SERVER/12/x86_64/product"] = "SLE12-Pool"
          repositories["http://#{@options[:smt_host]}/SUSE/Updates/SLE-SERVER/12/x86_64/update"] = "SLE12-Updates"
        end
        template_name = "sle12-dockerfile.erb"
      when SUPPORTED_BASE_SYSTEMS::SLE11SP3
        if @options[:smt_host]
          repositories["https://#{@options[:smt_host]}/repo/\\$RCE/SLES11-SP3-Updates/sle-11-x86_64?credentials=NCCcredentials"] = "SLES11-SP3-Updates"
          repositories["https://#{@options[:smt_host]}/repo/\\$RCE/SLES11-SP3-Pool/sle-11-x86_64?credentials=NCCcredentials"] = "SLES11-SP3-Pool"
        else
          repositories["https://nu.novell.com/repo/\\$RCE/SLES11-SP3-Updates/sle-11-x86_64?credentials=NCCcredentials"] = "SLES11-SP3-Updates"
          repositories["https://nu.novell.com/repo/\\$RCE/SLES11-SP3-Pool/sle-11-x86_64?credentials=NCCcredentials"] = "SLES11-SP3-Pool"

          cred_helper = CredentialsHelper.new(@options, true)
          credentials[:username] = cred_helper.username
          credentials[:password] = cred_helper.password
          credentials[:filename] = "NCCcredentials"
        end

        template_name = "sle11sp3-dockerfile.erb"
      else
        raise TemplateNotFoundError.new("Cannot find right template for #{@image_name}")
      end

      prebuilt_image = @image_name + ".tar.xz"

      template = ERB.new(
        File.read(
          File.join(
            File.expand_path("../../templates/docker_build", __FILE__),
            template_name
          )
        ),
        nil,
        "<>"
      ).result(binding)

      File.open(File.join(tmp_dir, "Dockerfile"), "w") do |file|
        file.write(template)
      end
    end

    def copy_prebuilt_image(tmp_dir)
      prebuilt_image = File.join(IMAGES_DIR, "#{@image_name}.tar.xz")
      destination = File.join(tmp_dir, "#{@image_name}.tar.xz")
      FileUtils.cp(prebuilt_image, destination)
    end

    def copy_zypper_resources(tmp_dir)
      repos_to_copy = []

      # copy services.d files
      source = "/etc/zypp/services.d"
      services = Dir["#{source}/*.service"]
      if services.empty?
        raise ConfigNotFoundError.new("No service file found under /etc/zypp/services.d")
      end
      FileUtils.mkdir_p(File.join(tmp_dir, "zypp", "services.d"))
      services.each do |service|
        FileUtils.cp(
          service,
          File.join(tmp_dir, "zypp", "services.d", File.basename(service))
        )
        repos_to_copy += File.readlines(service)
          .grep(/repo_\d+=/)
          .map{ |match| match.split("=", 2)[1].chomp + ".repo" }
      end

      # copy credentials.d files
      source = "/etc/zypp/credentials.d"
      if !File.exist?(source)
        raise ConfigNotFoundError.new("#{source} does not exist")
      else
        FileUtils.cp_r(source, File.join(tmp_dir, "zypp"))
      end

      # copy repositories
      destination = File.join(tmp_dir, "zypp", "repos.d")
      FileUtils.mkdir_p(destination)

      repos_to_copy.each do |repo|
        source = File.join("/etc/zypp/repos.d", repo)
        if File.exists?(source)
          FileUtils.cp(source, File.join(destination, repo))
        else
          raise ConfigNotFoundError.new("Cannot find repository file #{source}")
        end
      end
    end

    def docker_tag
      # example of image name: sles12-docker.x86_64-1.0.0-Build7.2
      match = /\A(?<name>.*)-docker\..*-(?<version>\d+\.\d+\.\d+)/.match(@image_name)
      if match.nil?
        raise DockerTagError.new("Cannot calculate the Docker tag for #{@image_name}")
      end

      {
        "repo" => "suse/#{match["name"]}",
        "tag" => match["version"]
      }
    end

    def verify_image
      file = File.join(IMAGES_DIR, "#{@image_name}.tar.xz")
      package_name = `rpm -qf #{file}`
      if $?.exitstatus != 0
        raise PrebuiltImageVerificationError.new("Cannot find rpm package providing #{file}: #{package_name}")
      end

      puts "Verifying integrity of the pre-built image"
      verification = `rpm --verify #{package_name}`
      if $?.exitstatus != 0
        raise PrebuiltImageVerificationError.new("Verification of #{package_name} failed: #{verification}")
      end
    end

  end

end

