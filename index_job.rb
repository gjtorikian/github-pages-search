require 'git'
require 'nokogiri'
require './page'

class IndexJob
  @queue = :default

  def self.perform(tmpdir, repo)
    clone_repo(repo, tmpdir)
    Dir.chdir "#{tmpdir}/#{repo}" do
      Dir.glob("**/*.html").map(&File.method(:realpath)).each do |html_file|
        relative_path = html_file.match(/#{repo}\/(.+)/)[1]
        html_file_contents = File.read(html_file)

        # TODO: make these configurable
        doc = Nokogiri::HTML(html_file_contents)
        text = doc.xpath("//div[contains(concat(' ',normalize-space(@class),' '),' article-body ')]").text()
        title = doc.xpath("//title").text()
        last_updated = doc.xpath("//[contains(concat(' ',normalize-space(@class),' '),'last-modified-at-date')]")

        page = Page.new id: "#{repo}::#{relative_path}", title: title, body: text, path: relative_path, last_updated: last_updated

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
    server = ENV['HOSTNAME'] || "github.com"
    "https://#{token}:x-oauth-basic@#{ENV['HOSTNAME']}/#{repo}.git"
  end
end
