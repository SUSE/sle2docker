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
    method_option :all,
      desc:    "Activate all the available pre-built images",
      type:    :boolean,
      default: false,
      aliases: "-a"
    def activate(image_name = nil)
      ensure_can_access_dockerd

      if options["all"]
        prebuilt_images = PrebuiltImage.list.map { |img| Sle2Docker::PrebuiltImage.new(img, options) }
      elsif !image_name.nil?
        prebuilt_images = [Sle2Docker::PrebuiltImage.new(image_name, options)]
      else
        puts "You have to specify an image name."
        exit 1
      end

      prebuilt_images.each do |image|
        if image.activated?
          warn "Image '#{image.image_id}' has already been activated."
        else
          image.activate
          puts "#{image.image_id} activated"
        end
      end
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
