module Sle2Docker
  # This class is the base class of native and prebulid images for
  # SUSE Linux Enterprise
  class Image
    attr_reader :image_id

    def activated?
      Docker::Image.exist?(image_id)
    end

    def verify_image
      check_image_exists

      puts 'Verifying integrity of the pre-built image'
      package_name = rpm_package_name
      verification = `rpm --verify #{package_name}`
      if $CHILD_STATUS.exitstatus.nonzero?
        raise(ImageVerificationError,
              "Verification of #{package_name} failed: #{verification}")
      end
      true
    end

    def rpm_package_name
      image_file = File.join(self.class::IMAGES_DIR, "#{@image_name}.tar.xz")
      package_name = `rpm -qf #{image_file}`
      if $CHILD_STATUS.exitstatus.nonzero?
        raise(
          ImageVerificationError,
          "Cannot find rpm package providing #{file}: #{package_name}"
        )
      end
      package_name
    end

    def check_image_exists
      msg = "Cannot find pre-built image #{@image_name}"
      raise(ImageNotFoundError, msg) unless File.exist? File.join(
        self.class::IMAGES_DIR, "#{@image_name}.tar.xz"
      )
    end
  end
end
