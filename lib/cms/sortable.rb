module CMS 
  # Container(s) are models receiving Content(s) posted by Agent(s)
  module Sortable
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end

    module ClassMethods
      # Provides an ActiveRecord model with Sort capabilities
      #
      # Example:
      #   acts_as_sortable :columns => [ :name,
      #                                  :description,
      #                                  { :name    => "Container",
      #                                    :content => :container,
      #                                    :no_sort => true } ]
      #
      # Options:
      # * columns:: Array of columns that will be displayed. 
      # Columns can be defined in two ways: 
      # Hash:: Describe each column attributes. These are:
      # * name: Title of the column
      # * content: The content that will be displayed for each object of the list. See CMS::Sortable::Column#data
      # * order: The +ORDER+ fragment in the SQL code
      # * no_sort: The column is not sortable
      # Symbol:: Takes defaults for each column attribute
      def acts_as_sortable(options = {})
        options[:columns] ||= self.table_exists? ? 
          self.columns.map{ |c| c.name.to_sym } :
          Array.new

        cattr_reader :sortable_options
        class_variable_set "@@sortable_options", options

        named_scope :column_sort, lambda { |order, direction|
          { :order => sanitize_order_and_direction(order, direction) }
        }
      end

      # Return all CMS::Sortable::Column for this Model
      def sortable_columns
        @sortable_columns ||= sortable_options[:columns].map{ |c| CMS::Sortable::Column.new(c) }
      end

      # Sanitize user send params
      def sanitize_order_and_direction(order, direction)
        order ||= "updated_at"
        direction = direction ? direction.upcase : "DESC"

        default_order = sortable_options[:default_order] || columns.first.name
        default_direction = sortable_options[:default_direction] || "DESC"

        #FIXME joins columns
        order = default_order unless columns.map(&:name).include?(order)
        direction = default_direction unless %w{ ASC DESC }.include?(direction)
 
        "#{ order } #{ direction }"
      end
    end

    # This class models columns that are shown in sortable_list
    class Column
      attr_reader :content, :name, :order, :no_sort

      def initialize(column) #:nodoc:
        case column
        when Symbol
          @content = column
          @name = column.to_s.humanize
          @order = column.to_s
        when Hash
          @content = column[:content]
          @name = column[:name] || column[:content] && column[:content].is_a?(Symbol) && column[:content].to_s.humanize || ""
          @order = column[:order] || column[:content] && column[:content].is_a?(Symbol) && column[:content].to_s || ""
          @no_sort = column[:no_sort]
        end
      end

      # Is this column sortable?
      def no_sort?
        ! @no_sort.nil?
      end

      # Get data for this object based in <tt>:content</tt> parameter. 
      # There are two types of <tt>:content</tt> parameter:
      # Symbol:: represents a method of the object, like <tt>object.name</tt>
      # Proc:: more complicate data. Example:
      #   :content => proc{ |helper, object|
      #     helper.link_to(object.container.name, helper.polymorhic_path(object.container))
      #   }
      #
      def data(helper, object)
        case content
        when Symbol
          object.send content
        when Proc
          content.call(helper, object)
        end
      end
    end
  end
end
