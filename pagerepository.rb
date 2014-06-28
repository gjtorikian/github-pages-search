require 'elasticsearch'
require 'elasticsearch/model'
require 'elasticsearch/persistence'

class PageRepository
  include Elasticsearch::Persistence::Repository

  def initialize(options={})
    index  'pages'
    type   'page'
    client Elasticsearch::Client.new url: ENV['ELASTICSEARCH_URL'] || ENV['BOXEN_ELASTICSEARCH_URL'] || ENV['BONSAI_URL'] || 'http://localhost:9200', log: true
  end

  klass Page

  settings number_of_shards: 1 do
    mapping do
      indexes :title, type: 'string', analyzer: 'snowball'
      indexes :body, type: 'string', analyzer: 'snowball'
      indexes :path, type: 'string', index: :not_analyzed
      indexes :updated_at, type: 'date', index: :not_analyzed
    end
  end

  create_index! force: true

  def deserialize(document)
    Page.new document['_source'].merge('id' => document['_id'])
  end
end
