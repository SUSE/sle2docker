module Sle2Docker
  class Builder

    def initialize(options)
      @options = options
    end

    # Creates the actual Docker image using kiwi
    #
    # @param [String] template_dir
    # @return [String] path to the image created by kiwi
    def create(template_dir)
      tmp_dir          = Dir.mktmpdir("sle2docker")
      tmp_template_dir = File.join(tmp_dir, "template")
      result_dir       = File.join(tmp_dir, "result")

      FileUtils.cp_r(File.join(template_dir, "."), tmp_template_dir)
      FileUtils.mkdir_p(result_dir)

      template_file = find_template_file(tmp_template_dir)
      if template_file.end_with?('.erb')
        template = render_template(template_file)
        File.open(File.join(tmp_template_dir, "config.xml"), "w") do |file|
          file.write(template)
        end
      end

      docker_cmd = "docker run --rm "
      # dns entries - otherwise docker uses Google's DNS
      dns_entries.each do |entry|
        docker_cmd += "--dns=#{entry} "
      end
      # the HTTP proxy specified by the user
      if @options[:http_proxy]
        docker_cmd += "-e http_proxy=#{@options[:http_proxy]} "
      end
      # ensure kiwi cache is persistent
      docker_cmd += "-v /var/cache/kiwi:/var/cache/kiwi "
      # share build dir
      docker_cmd += "-v #{tmp_dir}:/#{tmp_dir} "
      # required because kiwi needs to bind mount /proc while creating the image
      docker_cmd += "--privileged "
      # the image to use
      docker_cmd += "opensuse/kiwi "
      # kiwi directives
      docker_cmd += "--build #{tmp_template_dir} --type docker -d #{result_dir}"
      begin
        puts "Starting build process inside of Docker container"
        if !system(docker_cmd)
          $stderr.printf("Something wrong happened during the build process\n")
          exit(1)
        end
      end
      Dir[File.join(result_dir, "*.tbz")].first
    end

    # Looks for either config.xml or config.xml.erb inside of the template
    # directory.
    #
    # Exits with an error if no file is found.
    #
    # @param [String] template_dir
    # @return [String] full path to the template file
    def find_template_file(template_dir)
      template_file = File.join(template_dir, 'config.xml.erb')

      if !File.exist?(template_file)
        raise ConfigNotFoundError.new("Cannot find config.xml.erb file inside of #{template_dir}")
      end

      template_file
    end

    # Performs the rendering of config.xml.erb
    #
    # @param [String] template_file
    # @return [String] rendered template
    def render_template(template_file)
      host = if @options[:smt_host]
        @options[:smt_host]
      else
        "nu.novell.com"
      end

      username = @options[:username]
      if !username && (!@options[:password].empty? || !@options[:smt_host])
        puts "Enter #{@options[:smt_host] ? '' : 'NCC '}username:"
        username = $stdin.gets.chomp
      end

      password = @options[:password]
      if (username || !@options[:smt_host]) && password.empty?
        puts "Enter #{@options[:smt_host] ? '' : 'NCC '}password:"
        password = $stdin.noecho(&:gets).chomp
      end

      credentials = ""
      if username || !password.empty?
        credentials = "username='#{username}' password='#{password}'"
      end

      use_ncc = !@options[:smt_host]

      enable_https = !@options[:disable_https]

      include_build_repos = @options[:include_build_repositories]

      ERB.new(File.read(template_file)).result(binding)
    end

    def dns_entries
      File.open('/etc/resolv.conf', 'r') do |file|
        file.readlines("\n").grep(/\Anameserver\s+/).map{|l| l.split(" ", 2)[1].strip}
      end
    end
  end

end
