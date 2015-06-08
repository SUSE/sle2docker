module Sle2Docker
  # Entry point of the command line interface
  class Cli < Thor
    desc 'list', 'List available pre-built images'
    def list
      puts 'Available pre-built images:'
      prebuilt_images = PrebuiltImage.list
      if prebuilt_images.empty?
        puts 'No pre-built image found.'
        puts "\nPre-built images can be installed from SLE12 Update " \
          'repository using zypper:'
        puts '  zypper install \"sle*-docker-image\"'
      else
        prebuilt_images.each { |image| puts " - #{image}" }
      end
    end

    desc 'activate IMAGE_NAME', 'Import and activate a pre-built image'
    long_desc 'Import a pre-built image and add the official repositories to it'
    method_option :username,
                  aliases: '-u',
                  type: :string,
                  default: nil,
                  desc: 'Username required to access repositories'
    method_option :password,
                  aliases: '-p',
                  type: :string,
                  default: '',
                  desc: 'Password required to access repositories'
    method_option :smt_host,
                  aliases: ['-s', '--smt-host'],
                  type: :string,
                  default: nil,
                  desc: 'SMT machine hosting the repositories'
    method_option :disable_https,
                  aliases: ['--disable-https'],
                  type: :boolean,
                  default: false,
                  desc: 'Do not use HTTPS when accessing repositories'
    def activate(image_name)
      fail NotAdminError, 'This command requires root privileges' if Process.uid != 0
      begin
        Docker.info
      rescue Excon::Errors::SocketError => e
        fail "Docker is not running: #{e.message}"
      end

      prebuilt_image = Sle2Docker::PrebuiltImage.new(image_name, options)
      image_tag = prebuilt_image.docker_tag
      image_id  = "#{image_tag['repo']}:#{image_tag['tag']}"
      if Docker::Image.exist?(image_id)
        warn "Image #{image_id} already exists. Exiting"
        exit(0)
      end

      prebuilt_image.activate
      puts "#{image_id} activated"
    end

    map '-v' => :version
    desc 'version', 'Display version'
    def version
      puts Sle2Docker::VERSION
    end

  end
end
