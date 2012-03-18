require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'

task :default => :test

Rake::TestTask.new(:test) do |task|
  task.libs << "test"
  task.test_files = FileList['test/test_coverage.rb', 'test/*_test.rb']
  task.verbose = true
end

YARD::Rake::YardocTask.new do |task|
  task.files = ['lib/**/*.rb', '-', 'CHANGES.md', 'LICENSE.txt']
  task.options = ['--no-private', '--markup=markdown']
end
