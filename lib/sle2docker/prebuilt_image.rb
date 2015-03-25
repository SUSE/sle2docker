module Sle2Docker
  # This class takes care of handling the pre-build images for
  # SUSE Linux Enterprise
  class PrebuiltImage
    IMAGES_DIR = '/usr/share/suse-docker-images'

    # Enum of the supported base systems
    class SUPPORTED_BASE_SYSTEMS
      SLE11SP3 = 'sle11sp3'
      SLE12    = 'sle12'
    end

    def self.list
      if File.exist?(PrebuiltImage::IMAGES_DIR)
        Dir[File.join(IMAGES_DIR, '*.tar.xz')].map do |image|
          File.basename(image, '.tar.xz')
        end
      else
        []
      end
    end

    def initialize(image_name, options)
      @image_name = image_name
      @options    = options

      if @image_name =~ /\Asle.12/
        @base_system = SUPPORTED_BASE_SYSTEMS::SLE12
      elsif @image_name =~ /\Asle.11sp3/
        @base_system = SUPPORTED_BASE_SYSTEMS::SLE11SP3
      end
    end

    def activate
      unless File.exist?(File.join(IMAGES_DIR, "#{@image_name}.tar.xz"))
        fail PrebuiltImageNotFoundError,
             "Cannot find pre-built image #{@image_name}"
      end

      verify_image

      tmp_dir = prepare_docker_build_root
      puts 'Activating image'
      Docker::Image.build_from_dir(tmp_dir).tag(docker_tag)
    ensure
      FileUtils.rm_rf(tmp_dir) if tmp_dir && File.exist?(tmp_dir)
    end

    def prepare_docker_build_root
      tmp_dir = Dir.mktmpdir("sle2docker-#{@image_name}-dockerfile")

      create_dockerfile(tmp_dir)
      copy_prebuilt_image(tmp_dir)
      if @base_system == SUPPORTED_BASE_SYSTEMS::SLE12 && @options[:smt_host].nil?
        copy_zypper_resources(tmp_dir)
      end
      tmp_dir
    end

    # rubocop:disable Lint/UselessAssignment
    def create_dockerfile(tmp_dir)
      repositories  = {}
      credentials   = {}
      enable_https  = !@options[:disable_https]

      case @base_system
      when SUPPORTED_BASE_SYSTEMS::SLE12
        host = @options[:smt_host]
        template_name = 'sle12-dockerfile.erb'
      when SUPPORTED_BASE_SYSTEMS::SLE11SP3
        host = @options[:smt_host] || 'nu.novell.com'
        if @options[:smt_host].nil?
          cred_helper = CredentialsHelper.new(@options, true)
          credentials[:username] = cred_helper.username
          credentials[:password] = cred_helper.password
          credentials[:filename] = 'NCCcredentials'
        end

        template_name = 'sle11sp3-dockerfile.erb'
      else
        fail TemplateNotFoundError,
             "Cannot find right template for #{@image_name}"
      end

      prebuilt_image = @image_name + '.tar.xz'

      template = ERB.new(
        File.read(
          File.join(
            File.expand_path('../../templates/docker_build', __FILE__),
            template_name
          )
        ),
        nil,
        '<>'
      ).result(binding)

      File.open(File.join(tmp_dir, 'Dockerfile'), 'w') do |file|
        file.write(template)
      end
    end
    # rubocop:enable Lint/UselessAssignment

    def copy_prebuilt_image(tmp_dir)
      prebuilt_image = File.join(IMAGES_DIR, "#{@image_name}.tar.xz")
      destination = File.join(tmp_dir, "#{@image_name}.tar.xz")
      FileUtils.cp(prebuilt_image, destination)
    end

    def copy_zypper_resources(tmp_dir)
      services = Dir['/etc/zypp/services.d/*.service']
      if services.empty?
        fail ConfigNotFoundError,
             'No service file found under /etc/zypp/services.d'
      end

      destination = FileUtils.mkdir_p(File.join(tmp_dir, 'zypp'))
      FileUtils.cp_r('/etc/zypp/services.d', File.join(destination, 'services.d'))

      repos_target_dir = File.join(destination, 'repos.d')
      FileUtils.mkdir_p(repos_target_dir)

      services.each do |service|
        File.readlines(service)
          .grep(/repo_\d+=/)
          .map { |match| match.split('=', 2)[1].chomp + '.repo' }
          .each do |repo|
            FileUtils.cp(
              File.join('/etc/zypp/repos.d', repo),
              File.join(repos_target_dir, repo))
          end
      end

      source = '/etc/zypp/credentials.d'
      if !File.exist?(source)
        fail ConfigNotFoundError, "#{source} does not exist"
      else
        FileUtils.cp_r(source, File.join(tmp_dir, 'zypp'))
      end
    end

    def docker_tag
      # example of image name: sles12-docker.x86_64-1.0.0-Build7.2
      match = /\A(?<name>.*)-docker\..*-(?<version>\d+\.\d+\.\d+)/.match(@image_name)
      if match.nil?
        fail DockerTagError,
             "Cannot calculate the Docker tag for #{@image_name}"
      end

      {
        'repo' => "suse/#{match['name']}",
        'tag' => match['version']
      }
    end

    def verify_image
      file = File.join(IMAGES_DIR, "#{@image_name}.tar.xz")
      package_name = `rpm -qf #{file}`
      if $CHILD_STATUS.exitstatus != 0
        fail PrebuiltImageVerificationError,
             "Cannot find rpm package providing #{file}: #{package_name}"
      end

      puts 'Verifying integrity of the pre-built image'
      verification = `rpm --verify #{package_name}`
      if $CHILD_STATUS.exitstatus != 0
        fail PrebuiltImageVerificationError,
             "Verification of #{package_name} failed: #{verification}"
      end
    end
  end
end
