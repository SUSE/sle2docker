module Sle2Docker

  class Cli < Thor

    desc "list", "List the available templates"
    def list
      puts "Available templates:"
      Template.list_kiwi.each {|template| puts "  - #{template}"}

      puts "\nAvailable pre-built images:"
      prebuilt_images = PrebuiltImage.list
      if prebuilt_images.empty?
        puts "No pre-built image found."
        puts "\nPre-built images can be installed from SLE12 Update repository using zypper:"
        puts "  zypper install \"sle*-docker-image\""
      else
        prebuilt_images.each {|image| puts " - #{image}"}
      end
    end

    desc "activate IMAGE_NAME", "Import and activate a pre-built image"
    long_desc "Import a pre-built image and add the official repositories to it."
    def activate(image_name)
      prebuilt_image = Sle2Docker::PrebuiltImage.new(image_name)
      image_tag = prebuilt_image.docker_tag
      image_id  = "#{image_tag["repo"]}:#{image_tag["tag"]}"
      if Docker::Image.exist?(image_id)
        warn "Image #{image_id} already exists. Exiting"
        exit(0)
      else
        puts "Activating #{image_id}"
        prebuilt_image.activate
        puts "Done"
      end
    rescue RuntimeError => e
      $stderr.printf(e.message + "\n")
      exit(1)
    end

    map "-v" => :version
    desc "version", "Display version"
    def version
      puts Sle2Docker::VERSION
    end

    desc "show TEMPLATE", "Print the rendered TEMPLATE"
    method_option :username, :aliases => "-u", :type => :string,
                  :default => nil,
                  :desc => "Username required to access repositories"
    method_option :password, :aliases => "-p", :type => :string,
                  :default => "",
                  :desc => "Password required to access repositories"
    method_option :smt_host, :aliases => ["-s", "--smt-host"], :type => :string,
                  :default => nil,
                  :desc => "SMT machine hosting the repositories"
    method_option :disable_https, :aliases => ["--disable-https"],
                  :type => :boolean,
                  :default => false,
                  :desc => "Do not use HTTPS when accessing repositories"
    method_option :include_build_repositories, :aliases => ["--include-build-repos"],
                  :type => :boolean,
                  :default => true,
                  :desc => "Add the repositories used at build time to the Docker image"
    def show(template_name)
      template_dir = Template.kiwi_template_dir(template_name)
      builder = Builder.new(options)
      template_file = builder.find_template_file(template_dir)
      if template_file.end_with?('.erb')
        template = builder.render_template(template_file)
        puts "\n\n"
        puts template
      end
    rescue ConfigNotFoundError => e
      $stderr.printf(e.message + "\n")
      exit(1)
    rescue TemplateNotFoundError => ex
      $stderr.printf(ex.message + "\n")
      $stderr.printf("To list the available templates use:\n")
      $stderr.printf("  sle2docker list\n")
      exit(1)
    end

    desc "build TEMPLATE", "Use TEMPLATE to build a SLE Docker image"
    method_option :username, :aliases => "-u", :type => :string,
                  :default => nil,
                  :desc => "Username required to access repositories"
    method_option :password, :aliases => "-p", :type => :string,
                  :default => "",
                  :desc => "Password required to access repositories"
    method_option :smt_host, :aliases => ["-s", "--smt-host"], :type => :string,
                  :default => nil,
                  :desc => "SMT machine hosting the repositories"
    method_option :disable_https, :aliases => ["--disable-https"],
                  :type => :boolean,
                  :default => false,
                  :desc => "Do not use HTTPS when accessing repositories"
    method_option :http_proxy, :aliases => ["--http-proxy"],
                  :default => ENV['http_proxy'],
                  :desc => "HTTP proxy to use (eg: http://squid.local:3128)"
    method_option :include_build_repositories, :aliases => ["--include-build-repos"],
                  :type => :boolean,
                  :default => true,
                  :desc => "Add the repositories used at build time to the Docker image"
    def build(template_name)
      template_dir = Template.kiwi_template_dir(template_name)
      builder = Builder.new(options)
      container = builder.create(template_dir)
      puts "Container created, it can be imported by running the following command:"
      puts "  docker import - <desired image name> < #{container}"
      puts "\nThen the '#{File.expand_path(File.join(File.dirname(container), '..'))}' directory and all its contents can be removed."
      puts "Note well: KIWI created some of these files while running as root user, " +
           "hence root privileges are required to remove them."
    rescue ConfigNotFoundError => e
      $stderr.printf(e.message + "\n")
      exit(1)
    rescue TemplateNotFoundError => ex
      $stderr.printf(ex.message + "\n")
      $stderr.printf("To list the available templates use:\n")
      $stderr.printf("  sle2docker list\n")
      exit(1)
    end

  end
end
