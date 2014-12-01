module Sle2Docker

  class Cli < Thor

    #def initialize
    #  @options, @template_dir = parse_options()
    #end

    #def start
    #  builder = Builder.new(@options)
    #  builder.create(@template_dir)
    #rescue ConfigNotFoundError => e
    #  $stderr.printf(e.message + "\n")
    #  exit(1)
    #end

    desc "list", "List the available templates"
    def list
      puts "Available templates:"
      Template.list.each {|template| puts "  - #{template}"}
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
      template_dir = Template.template_dir(template_name)
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
      template_dir = Template.template_dir(template_name)
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
