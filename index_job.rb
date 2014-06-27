require 'git'
require 'pismo'
require './page'

class IndexJob
  @queue = :default

  def self.perform(tmpdir, repo)
    clone_repo(repo, tmpdir)
    Dir.chdir "#{tmpdir}/#{repo}" do
      Dir.glob("**/*.html").map(&File.method(:realpath)).each do |html_file|
        html_file_contents = File.read(html_file)
        pismo_doc = Pismo::Document.new(html_file_contents, :reader => :cluster)

        begin
          pismo_doc.body
        rescue NoMethodError
          # no op:
          # NoMethodError: undefined method `values' for #<Set: {}>
          # from /vendor/gems/ruby/2.1.0/gems/sanitize-3.0.0/lib/sanitize.rb:92:in `initialize'
          # and yet, somehow, calling it again below fixes the problem.
        end

        page = Page.new id: "#{repo}::#{html_file}", title: pismo_doc.title, body: pismo_doc.body

        GitHubPagesSearch::repository.save(page)
      end
    end
  end

  def self.token
    ENV["MACHINE_USER_TOKEN"]
  end

  def self.clone_repo(repo, tmpdir)
    puts "Cloning #{repo}..."
    @git_dir = Git.clone(clone_url_with_token(token, repo), "#{tmpdir}/#{repo}")
  end

  def self.setup_git
   @git_dir.config('user.name', 'Hubot')
   @git_dir.config('user.email', 'cwanstrath+hubot@gmail.com')
  end

  def self.clone_url_with_token(token, repo)
    server = ENV['ENTERPRISE'] || "github.com"
    "https://#{token}:x-oauth-basic@#{ENV['ENTERPRISE']}/#{repo}.git"
  end
end
