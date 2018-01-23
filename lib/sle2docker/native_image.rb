module Sle2Docker
  # This class takes care of handling the native loadable images for
  # SUSE Linux Enterprise
  class NativeImage < Image
    IMAGES_DIR = '/usr/share/suse-docker-images/native'.freeze

    def self.list
      if File.exist?(NativeImage::IMAGES_DIR)
        Dir[File.join(NativeImage::IMAGES_DIR, '*.tar.xz')].map do |image|
          File.basename(image, '.tar.xz')
        end
      else
        []
      end
    end

    def initialize(image_name, options)
      @image_name = image_name
      @options = options
      compute_metadata_file
    end

    def activate
      verify_image

      puts 'Loading image'
      Docker::Image.load(File.join(IMAGES_DIR, "#{@image_name}.tar.xz"))
      image = Docker::Image.get("#{@repository}:#{@tag}")
      image.tag('repo' => @repository, 'tag' => 'latest')
      @options['tag_with_build'] &&
        image.tag('repo' => @repository, 'tag' => "#{@tag}-#{@build}")
    end

    private

    def compute_metadata_file
      match = parse_image_filename(@image_name)
      @metadata = parse_metadata_file("#{match['metadata_file']}.metadata")

      @repository   = @metadata['image']['name']
      @tag          = @metadata['image']['tags'][0]
      @build        = match['build']
      @image_id     = "#{@repository}:#{@tag}"
      @options['tag_with_build'] && \
        @image_id = "#{@repository}:#{@tag}-#{@build}"
    end

    def parse_image_filename(file)
      # example of image name and metadata file:
      # kiwi >= 8.30
      #      sles12sp3-container.x86_64-2.0.1-Build2.3.docker (image basename)
      #      sles12sp3-container.x86_64-2.0.1.metadata
      regexp = /(?<metadata_file>.*\d+\.\d+\.\d+)
        (-Build(?<build>\d+\.\d+)\.docker)?/x
      match = regexp.match(file)
      match.nil? &&
        raise(DockerTagError,
              "Docker image #{file} not found. "\
              'Run sle2docker list to check which docker images are available.')
      match
    end

    def parse_metadata_file(metadata_file)
      file = File.read(
        File.join(NativeImage::IMAGES_DIR, metadata_file)
      )
      metadata = JSON.parse(file)
      metadata['image']['tags'][0].to_s.empty? &&
        raise(DockerTagError,
              'Metadata file does not include a valid tag. '\
              'Container tag cannot be null or an empty string.')
      metadata['image']['name'].to_s.empty? &&
        raise(DockerTagError,
              'Metadata file does not include a valid image name. '\
              'Image name cannot be null or an empty string.')
      metadata
    end
  end
end
