module Sle2Docker

  class Cli

    def initialize
      @options, @template_dir = parse_options()
    end

    def start
      builder = Builder.new(@options)
      builder.create(@template_dir)
    rescue ConfigNotFoundError => e
      $stderr.printf(e.message + "\n")
      exit(1)
    end

    private

    def parse_options()
      options = {}

      optparse = OptionParser.new do|opts|
        opts.banner = "Usage: sle2docker [options] TEMPLATE"

        options[:username] = nil
        opts.on('-u', '--username USERNAME',
                'Username required to access repositories' ) do |u|
          options[:username] = u
        end

        options[:password] = ""
        opts.on('-p', '--password PASSWORD',
                'Password required to access repositories' ) do |p|
          options[:password] = p
        end

        options[:smt_host] = nil
        opts.on('-s', '--smt-host SMT_HOST',
                'SMT machine hosting the repositories' ) do |smt_host|
          options[:smt_host] = smt_host
        end

        options[:disable_https] = false
        opts.on('--disable-https',
                'Do not use HTTPS when accessing repositories' ) do
          options[:disable_https] = true
        end

        opts.on('-l', '--list-templates', 'List the available templates' ) do
          puts "Available templates:"
          Template.list.each {|template| puts "  - #{template}"}
          exit
        end


        opts.on('-h', '--help', 'Display this screen' ) do
          puts opts
          exit
        end

        opts.on('-v', '--version', 'Display version' ) do
          puts Sle2Docker::VERSION
          exit
        end

      end

      optparse.parse!

      if ARGV.count != 1
        $stderr.printf("Template not provided\n")
        exit(1)
      end

      [options, Template.template_dir(ARGV[0])]
    rescue TemplateNotFoundError => ex
      $stderr.printf(ex.message + "\n")
      $stderr.printf("To list the available templates use:\n")
      $stderr.printf("  sle2docker -l\n")
      exit(1)
    end
  end
end
