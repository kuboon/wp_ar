gem 'activerecord', '~> 4.0'
require 'active_record'

# Adapted from http://snippets.dzone.com/posts/show/1314 and
# considerably extended

module Wordpress
  class Base < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = 'wp_'
  end

  class Comment < Base
    self.primary_key = "comment_ID"

    belongs_to :post, foreign_key: "comment_post_ID"

    validates_presence_of :comment_post_ID, :comment_author, :comment_content, :comment_author_email
    validate :valid_comment_status

    def valid_comment_status
      unless post.comment_status == 'open'
        errors.add_to_base('Sorry, comments are closed for this post')
      end
    end
  end

  class PostMeta < Base
    self.table_name = "#{table_name_prefix}postmeta"
    self.primary_key = "meta_id"
    belongs_to :post
  end

  class Post < Base
    has_many :comments, foreign_key: "comment_post_ID"
    has_many :metas, :class_name => 'PostMeta'

    has_many :term_relationships, :foreign_key => 'object_id'
    has_many :term_taxonomies, :through => :term_relationships
    has_many :taggings, through: :term_relationships, :source => :term_taxonomy#, :conditions => ['#{table_name_prefix}term_taxonomy.taxonomy = ?', 'post_tag']

    belongs_to :author, :class_name => 'User', :foreign_key => 'post_author'

    scope :published, ->{ where(post_status: 'publish') }
    default_scope { order('post_date DESC') }

    validates_presence_of :post_modified, :post_modified_gmt, :post_date, :post_date_gmt
    before_validation :set_timestamps

    def set_timestamps
      self.post_modified = DateTime.now
      self.post_modified_gmt = self.post_modified.utc
      self.post_date ||= self.post_modified
      self.post_date_gmt ||= self.post_date.utc
    end

    def published?
      status == 'published' and post_date <= DateTime.now
    end

    def tags
      taggings.pluck(:term)
    end
  end

  class Term < Base
    self.primary_key = 'term_id'
    has_many :taxonomies, :class_name => 'TermTaxonomy'
    has_many :relationships, :through => :taxonomies

    def posts
      relationships.includes(:post).map(&:post)
    end
  end

  class TermTaxonomy < Base
    self.table_name = "#{table_name_prefix}term_taxonomy"
    self.primary_key = 'term_taxonomy_id'
    belongs_to :term
    has_many :relationships, :class_name => 'TermRelationship'
  end

  class TermRelationship < Base
    belongs_to :post, foreign_key: 'object_id'
    belongs_to :term_taxonomy
  end

  class Link < Base
    self.primary_key = 'link_id'
  end

  class User < Base
#    self.primary_key = 'ID'
    has_many :user_metas
    has_many :posts, foreign_key: 'post_author'

    validates_presence_of :user_registered
    validates_uniqueness_of :user_email, :user_login

    before_validation on: :create do
      self.user_registered ||= DateTime.now
    end

    class << self
      # Note: Recent versions of WP do not simply store an MD5
      # they use PHPPass (wp-includes/class-phpass.php)
      # If anyone has written a ruby equivalent, please let me know so I
      # can integrate it
      def encrypt(password)
        Digest::MD5.hexdigest(password)
      end
    end
  end

  class UserMeta < Base
    self.table_name = "#{table_name_prefix}usermeta"
    self.primary_key = 'umeta_id'
    belongs_to :user
  end

  class Option < Base
    self.primary_key = 'option_id'
  end
end
