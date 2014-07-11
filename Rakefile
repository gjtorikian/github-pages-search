require './app.rb'
require 'resque/tasks'

task "resque:setup" do
  ENV['QUEUE'] = '*'
end

desc "Alias for resque:work (To run workers on Heroku)"
task "jobs:work" => "resque:work"

namespace :deploy do
  desc 'Deploy the app'
  task :production do
    app = "github-pages-search"
    remote = "git@heroku.com:#{app}.git"

    system "heroku maintenance:on --app #{app}"
    system "git push #{remote} master"
    system "heroku run rake db:migrate --app #{app}"
    system "heroku maintenance:off --app #{app}"
  end
end

def in_tmpdir
  path = File.expand_path "#{Dir.tmpdir}/indexer/repos/#{Time.now.to_i}#{rand(1000)}/"
  FileUtils.mkdir_p path
  puts "Directory created at: #{path}"
  yield path
ensure
  FileUtils.rm_rf(path) if File.exists?(path)
end

desc 'Manually index a GitHub Pages repository'
task :reindex do
  in_tmpdir do |tmpdir|
    IndexJob.perform(tmpdir, ENV['REPO'])
  end
end
