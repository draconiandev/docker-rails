class Post < ApplicationRecord
  include ImageUploader::Attachment.new(:image)

  validates :title, presence: true
  validates :content, presence: true

  after_commit on: :update do |post|
    PostRelayJob.perform_later(post)
  end

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  index_name Rails.application.class.parent_name.underscore
  document_type self.name.downcase

  settings index: { number_of_shards: 1 } do
    mapping dynamic: false do
      indexes :title, analyzer: 'english'
      indexes :content, analyzer: 'english'
    end
  end

  def self.search(query)
    __elasticsearch__.search(
      {
        query: {
          multi_match: {
            query: query,
            fields: ['title^5', 'content']
          }
        },
        highlight: {
          pre_tags: ['<strong>'],
          post_tags: ['</strong>'],
          fields: {
            title: {},
            content: {},
          }
        },
        suggest: {
          text: query,

          title: {
            term: {
              size: 1,
              field: :title
            }
          },

          content: {
            term: {
              size: 1,
              field: :content
            }
          }
        }
      }
    )
  end

  def as_indexed_json(options = nil)
    self.as_json( only: [ :title, :content ] )
  end
end
