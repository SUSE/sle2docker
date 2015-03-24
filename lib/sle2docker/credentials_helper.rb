module Sle2Docker

  class CredentialsHelper

    def initialize(options, mandatory)
      # make a duplicate, this is usually a frozen hash created by Thor
      @options   = options.dup
      @mandatory = mandatory
    end

    def username
      if @mandatory && @options[:username].nil?
        puts "Enter #{@options[:smt_host] ? '' : 'NCC '}username:"
        @options[:username] = $stdin.gets.chomp
      end
      @options[:username]
    end

    def password
      if (username || !@options[:smt_host]) && @options[:password].empty?
        puts "Enter #{@options[:smt_host] ? '' : 'NCC '}password:"
        @options[:password] = $stdin.noecho(&:gets).chomp
      end
      @options[:password]
    end

  end

end
