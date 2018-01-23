module Sle2Docker
  # Entry point of the command line interface
  class Cli < Thor
    check_unknown_options!

    desc 'list', 'List available pre-built images'
    def list
      puts 'Available pre-built images:'
      images = RootFSImage.list + NativeImage.list
      if images.empty?
        puts 'No pre-built image found.'
        puts "\nPre-built images can be installed from SLE12 Update " \
          'repository using zypper:'
        puts '  zypper install \"sle*-docker-image\"'
      else
        images.each { |image| puts " - #{image}" }
      end
    end

    desc 'activate IMAGE_NAME', 'Activate a pre-built image'
    method_option :all,
                  desc:    'Activate all the available pre-built images',
                  type:    :boolean,
                  default: false,
                  aliases: '-a'

    method_option :tag_with_build,
                  desc:    'Include kiwi build number into tag',
                  type:    :boolean,
                  default: false,
                  aliases: '-b'

    def activate(image_name = nil)
      ensure_can_access_dockerd
      if options['all']
        activate_all(options)
      elsif !image_name.nil?
        activate_image(image_name, options)
      else
        puts 'You have to specify an image name.'
        exit 1
      end
    end

    map '-v' => :version
    desc 'version', 'Display version'
    def version
      puts Sle2Docker::VERSION
    end

    private

    def ensure_can_access_dockerd
      Docker.info
    end

    def activate_all(options)
      images = RootFSImage
               .list.map { |img| Sle2Docker::RootFSImage.new(img, options) }
      images += NativeImage
                .list.map { |img| Sle2Docker::NativeImage.new(img, options) }
      activate_images(images)
    end

    def activate_image(image_name, options)
      if RootFSImage.list.include?(image_name)
        activate_images([Sle2Docker::RootFSImage.new(image_name, options)])
      elsif NativeImage.list.include?(image_name)
        activate_images([Sle2Docker::NativeImage.new(image_name, options)])
      else
        puts 'You have to specify an existing image name.'
        exit 1
      end
    end

    def activate_images(images)
      images.each do |image|
        if image.activated?
          warn "Image '#{image.image_id}' has already been activated."
        else
          image.activate
          puts "#{image.image_id} activated"
        end
      end
    end
  end
end
