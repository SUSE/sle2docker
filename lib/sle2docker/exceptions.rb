module Sle2Docker
  class TemplateNotFoundError < RuntimeError
  end

  class ConfigNotFoundError < RuntimeError
  end

  class ImageNotFoundError < RuntimeError
  end

  class DockerTagError < RuntimeError
  end

  class ImageVerificationError < RuntimeError
  end
end
