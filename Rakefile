require 'rake'
require 'rake/testtask'

desc "Run all tests"
task :test => %w{ test:unit test:system test:stress }

namespace :test do
  desc "Run unit tests"
  Rake::TestTask.new :unit do |t|
    t.libs << "lib"
    t.libs << "test/lib"
    t.test_files = FileList["test/unit/*.rb"]
  end

  desc "Run system tests"
  task :system do |t|
    FileList["test/system/*.rb"].each do |f|
      ruby f
    end
  end

  desc "Run stress tests"
  task :stress do |t|
    FileList["test/stress/*.rb"].each do |f|
      ruby f
    end
  end
end
