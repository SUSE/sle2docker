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

    desc 'activate IMAGE_NAME', 'Activate a pre-built image'
    def activate(image_name)
      ensure_can_access_dockerd

      prebuilt_image = Sle2Docker::PrebuiltImage.new(image_name, options)
      if prebuilt_image.activated?
        warn 'Image has already been activated. Exiting'
        exit(0)
      end

      prebuilt_image.activate
      puts "#{prebuilt_image.image_id} activated"
    end

    map '-v' => :version
    desc 'version', 'Display version'
    def version
      puts Sle2Docker::VERSION
    end

    private

    def ensure_can_access_dockerd
      output = `docker info`
      if $CHILD_STATUS.exitstatus != 0
        raise output
      end
    end
  end
end
