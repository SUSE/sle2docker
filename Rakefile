require 'bundler'
require 'rake'
require 'rake/testtask'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  warn 'Yard not available. To generate documentation install it with: ' \
       'gem install yard'
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: :test

desc "Generate man pages"
task :man do
  system "ronn #{File.expand_path('../package/sle2docker.8.ronn', __FILE__)}"
end
