require 'git'
require 'nokogiri'
require './page'

class IndexJob
  @queue = :default

  def self.perform(tmpdir, repo)
    clone_repo(repo, tmpdir)
    Dir.chdir "#{tmpdir}/#{repo}" do
      Dir.glob("**/*.html").map(&File.method(:realpath)).each do |html_file|
        html_file_contents = File.read(html_file)

        doc = Nokogiri::HTML(html_file_contents)
        text = doc.xpath("//div[contains(concat(' ',normalize-space(@class),' '),' article-body ')]").text()
        title = doc.xpath("//title").text()

        page = Page.new id: "#{repo}::#{html_file}", title: title, body: text

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
