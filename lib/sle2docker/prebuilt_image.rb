module Sle2Docker

  class PrebuiltImage

    IMAGES_DIR = "/usr/share/suse-docker-images"

    class SUPPORTED_BASE_SYSTEMS
      SLE11 = "sle11"
      SLE12 = "sle12"
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

    def initialize(image_name)
      @image_name = image_name
      @base_system = if @image_name =~ /\Asle.12/
        SUPPORTED_BASE_SYSTEMS::SLE12
      elsif @image_name =~ /\Asle.11/
        SUPPORTED_BASE_SYSTEMS::SLE11
      end
    end

    def activate
      if !File.exists?(File.join(IMAGES_DIR, "#{@image_name}.tar.xz"))
        raise PrebuiltImageNotFoundError("Cannot find pre-built image #{@image_name}")
      end

      tmp_dir = prepare_docker_build_root
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
      if @base_system == SUPPORTED_BASE_SYSTEMS::SLE12
        copy_zypper_resources(tmp_dir)
      end
      tmp_dir
    end

    def create_dockerfile(tmp_dir)
      template_name = case @base_system
      when SUPPORTED_BASE_SYSTEMS::SLE12
        "sle12-dockerfile.erb"
      when SUPPORTED_BASE_SYSTEMS::SLE11
        "sle11-dockerfile.erb"
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
        )
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

  end

end

