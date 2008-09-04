require 'atom/entry'

module CMS
  # A Content is a unit of information suitable to be published online.
  # Examples of contents are texts, images, events, URIs
  #
  # Content(s) are posted by Agent(s) to Container(s), resulting in Post(s)
  #
  # == Contents in some container
  # You can use the named_scope +in_container+ to get all Contents in some container.
  #   Content.in_container(some_container) #=> Array of contents in the container
  #
  # Contents instances have posts columns in post_*
  module Content
    def self.included(base) # :nodoc:
      base.extend ClassMethods
    end

    # Return the first Content class supporting this Content Type
    def self.class_supporting(content_type)
      mime_type = Mime::Type.lookup(content_type)
      
      for content_class in CMS::content_classes
        return content_class if content_class.mime_types.include?(mime_type)
      end
      nil
    end

    module ClassMethods
      # Provides an ActiveRecord model with Content capabilities
      #
      # Content(s) are posted by Agent(s) to Container(s), creating Post(s)
      #
      # Options:
      # * <tt>:named_collection</tt> - this Content has an particular collection name, (ex. blog for articles, calendar for events, etc..)
      # * <tt>:atompub_mime_types</tt> - array of Mime Types accepted for this Content via AtomPub. Defaults to "application/atom+xml;type=entry"
      # * <tt>:has_media</tt> - this Content has attachment data. Supported plugins: attachment_fu (<tt>:attachment_fu</tt>)
      # * <tt>:disposition</tt> - specifies whether the Content will be shown inline or as attachment (see Rails send_file method). Defaults to :attachment
      # * <tt>:per_page</tt> - number of contents shown per page, using will_pagination plugin. Defaults to 9
      #
      def acts_as_content(options = {})
        CMS.register_model(self, :content)

        #FIXME: should this be the default mime type??
        options[:atompub_mime_types] ||= "application/atom+xml;type=entry"
        options[:disposition]        ||= :attachment
        options[:per_page]           ||= 9

        cattr_reader :content_options
        class_variable_set "@@content_options", options

        has_many :content_posts, 
                 :class_name => "Post",
                 :dependent => :destroy,
                 :as => :content

        # Filter "create" method for Atom Mapping
        # With this filter, a new content can be crated from a Hash of
        # Atom Entry parameters
        # The Atom Entry may include different attibutes than the Content
        # (see atom_mapping option)
        #
        # This methods maps the appropriate attributes
        class << self
          alias_method_chain :create, :cms_params_filter
        end

        # Named scope in_container returns all Contents in some container
        named_scope :in_container, lambda { |container|
          if container && container.respond_to?("container_options")
            container_conditions = " AND posts.container_id = '#{ container.id }' AND posts.container_type = '#{ container.class.base_class.to_s }'"
          end

          post_columns = Post.column_names.map{|n| "posts.#{ n } AS post_#{ n }" }.join(', ')
          { :select => "#{ self.table_name }.*, #{ post_columns }",
            :joins => "INNER JOIN posts ON posts.content_id = #{ self.table_name }.id AND posts.content_type = '#{ self.to_s }'" + container_conditions
          }
        }

        include CMS::Content::InstanceMethods
      end
      
      def mime_types
        Mime::Type.parse content_options[:atompub_mime_types]
      end

      # Returns the symbol for a set of Contents of this item
      # e.g. <tt>:articles</tt> for Article
      def collection
        self.to_s.tableize.to_sym
      end
      
      # Returns the word for a named collection of this item
      # a.g. <tt>"Gallery"</tt> for Photo
      def named_collection
        content_options[:named_collection] ? content_options[:named_collection].to_s : self.to_s.humanize.pluralize
      end

      # Returns the translated named collection for this item
      # a.g. <tt>"Galería"</tt> for Photo
      def translated_named_collection
        content_options[:named_collection] ? content_options[:named_collection].to_s.t : self.to_s.humanize.t(self.to_s.humanize.pluralize, 99)
      end

      protected

      # Introduce filters for parameters in create chain
      def create_with_cms_params_filter(params) #:nodoc:
        create_without_cms_params_filter cms_params_filter(params)
      end

      # Filter Content parameters:
      # If there is Atom Entry data, extract information from the Entry to parameters
      # If there is raw post data, convert it to suitable plugin
      def cms_params_filter(params) #:nodoc:
        params[:atom_entry].blank? ? params : 
          atom_entry_filter(Atom::Entry.parse(params[:atom_entry]))
      end

      # Atom Entry filter
      # Extracts parameter information from an Atom Entry element
      #
      # Implement this in your class if you want AtomPub support in your Content
      def atom_entry_filter(atom_entry)
        {}
      end
    end

    module InstanceMethods
      # Returns the mime type for this Content instance. 
      # TODO: Works with attachment_fu
      def mime_type
        respond_to?("content_type") ? Mime::Type.lookup(content_type) : nil
      end
      
      # Has this Content been posted in this Container? Is there any Post linking both?
      def posted_in?(container)
        return false unless container
        content_posts.select{ |p| p.container == container }.any?
      end
      

      # Can this <tt>agent</tt> read this Content?
      # True if there exists a Post for this Content that can be read by <tt>agent</tt> 
      def read_by?(agent = nil)
        content_posts.select{ |p| p.read_by?(agent) }.any?
      end

      # Method useful for icon files
      #
      # If the Content has a Mime Type, return it scaped with '-' 
      #   application/jpg => application-jpg
      # else, return the underscored class name:
      #   photo
      def mime_type_or_class_name
        mime_type ? mime_type.to_s.gsub(/[\/\+]/, '-') : self.class.to_s.underscore
      end
    end
  end
end
