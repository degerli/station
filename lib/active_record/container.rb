module ActiveRecord #:nodoc:
  # A Container is a model that have many Contents
  #
  # Include this functionality in your modules using ActsAsMethods#acts_as_container
  module Container
    class << self
      def included(base) #:nodoc:
        base.extend ActsAsMethods
      end
    end

    module ActsAsMethods
      # Provides an ActiveRecord model with Container capabilities
      #
      # Options:
      # <tt>contents</tt>:: an Array of Contents that can be posted to this Container. Ex: [ :articles, :images ]. Defaults to all available Content models.
      # <tt>sources</tt>:: The container has remote sources. It will import Atom/RSS feeds as contents. See Source. Defaults to false
      def acts_as_container(options = {})
        ActiveRecord::Container.register_class(self)

        cattr_reader :container_options
        class_variable_set "@@container_options", options

        if options[:sources]
          has_many :sources, :as => :container,
                             :dependent => :destroy
        end

        extend  ClassMethods
        include InstanceMethods
      end
    end

    module ClassMethods
      # Array of symbols representing the Contents that this Container supports
      def contents
        container_options[:contents] || ActiveRecord::Content.symbols
      end
    end


    # Instance methods can be redefined in each Model for custom features
    module InstanceMethods #:nodoc:
      # Array of contents of this container instance.
      #
      # Uses ActiveRecord::Content::Inquirer for building the query in 
      # several tables.
      def contents(options = {})
        container_options[:containers] = Array(self)

        ActiveRecord::Content::Inquirer.all(options, container_options)
      end

      # A list of all the nested containers of this Container, including self,
      # sorted by closeness
      def container_and_ancestors
        ca = respond_to?(:container) && container.try(:container_and_ancestors) || nil

        (Array(self) + Array(ca)).compact
      end
    end
  end
end
