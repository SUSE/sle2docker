module Sle2Docker

  class TemplateNotFoundError < RuntimeError
  end

  class ConfigNotFoundError < RuntimeError
  end

  class PrebuiltImageNotFoundError < RuntimeError
  end

  class DockerTagError < RuntimeError
  end

  class PrebuiltImageVerificationError < RuntimeError
  end

end
