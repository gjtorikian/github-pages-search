require "./app"
require 'resque/server'

Resque::Server.use Rack::Auth::Basic do |username, password|
  username == ENV['USERNAME'] && password == ENV['PASSWORD']
end

run Rack::URLMap.new \
  "/"       => GitHubPagesSearch,
  "/resque" => Resque::Server.new
