module Sle2Docker
  # Entry point of the command line interface
  class Cli < Thor
    check_unknown_options!

    desc 'list', 'List available pre-built images'
    def list
      puts 'Available pre-built images:'
      prebuilt_images = PrebuiltImage.list
      native_images = NativeImage.list
      if prebuilt_images.empty? && native_images.empty?
        puts 'No pre-built image found.'
        puts "\nPre-built images can be installed from SLE12 Update " \
          'repository using zypper:'
        puts '  zypper install \"sle*-docker-image\"'
      else
        prebuilt_images.each { |image| puts " - #{image}" }
        native_images.each { |image| puts " - #{image}" }
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

    def activate_all(options)
      native_images = NativeImage.list
      prebuilt_images = PrebuiltImage.list
      images = prebuilt_images
               .map { |img| Sle2Docker::PrebuiltImage.new(img, options) }
      images += native_images
                .map { |img| Sle2Docker::NativeImage.new(img, options) }
      activate_images(images)
    end

    def activate_image(image_name, options)
      native_images = NativeImage.list
      prebuilt_images = PrebuiltImage.list

      if prebuilt_images.include?(image_name)
        activate_images([Sle2Docker::PrebuiltImage.new(image_name, options)])
      elsif native_images.include?(image_name)
        activate_images([Sle2Docker::NativeImage.new(image_name, options)])
      else
        puts 'You have to specify an existing image name.'
        exit 1
      end
    end

    def ensure_can_access_dockerd
      output = `docker info 2>&1`
      raise output if $CHILD_STATUS.exitstatus.nonzero?
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
