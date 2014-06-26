require "sinatra/base"
require "json"
require "fileutils"
require "resque"
require "redis"
require "openssl"
require "base64"

require './page'
require './pagerepository'
require './index_job'

class GitHubPagesSearch < Sinatra::Base
  set :root, File.dirname(__FILE__)

  set :repository, PageRepository.new
  set :per_page,   10

  configure do

    if ENV['RACK_ENV'] == "production"
      uri = URI.parse( ENV[ "REDISTOGO_URL" ])
      REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
      Resque.redis = REDIS
    else
      Resque.redis = Redis.new
    end
  end

  before do
    # trim trailing slashes
    request.path_info.sub! %r{/$}, ''
    pass unless %w[index].include? request.path_info.split('/')[1]
    # ensure signature is correct
    request.body.rewind
    payload_body = request.body.read
    verify_signature(payload_body)
    # keep some important vars
    @payload = JSON.parse payload_body
    @repo = "#{@payload["repository"]["full_name"]}"
    check_params
  end

  get "/" do
    "I think you misunderstand how to use this."
  end

  get "/search" do
    content_type :json
    @page  = [ params[:p].to_i, 1 ].max

    @pages = GitHubPagesSearch.repository.search \
               query: ->(q, t) do
                query = if q && !q.empty?
                  { match: { body: q } }
                else
                  { match_all: {} }
                end

                filter = if t && !t.empty?
                  { term: { tags: t } }
                end

                if filter
                  { filtered: { query: query, filter: filter } }
                else
                  query
                end
               end.(params[:q], params[:t]),

              #  sort: [{created_at: {order: 'desc'}}],

               size: settings.per_page,
               from: settings.per_page * (@page-1),

               highlight: { fields: { body: { fragment_size: 160, number_of_fragments: 1, pre_tags: ['<em class="hl">'], post_tags: ['</em>'] } } }

    result = {}

    return result if @pages.empty?

    result[:results] = []
    @pages.each_with_hit do |page, hit|
      require 'pp'
      pp hit.highlight.size
      result[:results] << {:result => (hit.highlight && hit.highlight.size > 0 ? hit.highlight.body.first : page.attributes["body"][0..80]), :title => page.attributes["title"], :last_updated => "03/06/1984" }
    end

    result[:total] = @pages.total

    result.to_json
  end

  post "/index" do
    do_the_work
  end

  helpers do

    def verify_signature(payload_body)
      return true if Sinatra::Base.development? or ENV['SECRET_TOKEN'].nil?
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), ENV['SECRET_TOKEN'], payload_body)
      return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
    end

    def check_params
      return halt 422, "GitHub Pages site not built, aborting." unless @payload["build"]["status"] == "built"
    end

    def do_the_work
      in_tmpdir do |tmpdir|
        Resque.enqueue(IndexJob, tmpdir, @repo)
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
  end
end
