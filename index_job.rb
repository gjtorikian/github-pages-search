require 'git'
require 'nokogiri'
require './page'

class IndexJob
  @queue = :default

  CONTENT_MATCHES = [
    'div[role="main"]',
    'div.content',
    'div.content-body',
    'body'
  ]

  def self.perform(tmpdir, repo)
    clone_repo(repo, tmpdir)
    Dir.chdir "#{tmpdir}/#{repo}" do
      @git_dir.checkout "gh-pages"
      Dir.glob("**/*.html").map(&File.method(:realpath)).each do |html_file|
        relative_path = html_file.match(/#{repo}\/(.+)/)[1]
        html_file_contents = File.read(html_file)

        # TODO: make these configurable?
        doc = Nokogiri::HTML(html_file_contents)
        title = doc.xpath("//title").text().strip
        last_updated = doc.xpath("//span[contains(concat(' ',normalize-space(@class),' '),'last-modified-at-date')]").text().strip

        body = []

        CONTENT_MATCHES.each do |content_selector|
          body += doc.css(content_selector)
          break if body.any?
        end

        # convert from Nokogiri Element objects to strings
        body.map!(&:inner_text)

        page = Page.new id: "#{repo}::#{relative_path}", title: title, body: body, path: relative_path, last_updated: last_updated

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
    "https://#{token}:x-oauth-basic@#{server}/#{repo}.git"
  end
end
