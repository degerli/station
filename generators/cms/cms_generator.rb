require File.dirname(__FILE__) + '/rails_commands'
class CmsGenerator < Rails::Generator::Base
  default_options :skip_migration => false

  def initialize(runtime_args, runtime_options = {})
    parse!(runtime_args, runtime_options)
    super
  end

  def manifest
    record do |m|
      #TODO: check for collisions
      
      m.directory 'config/initializers'
      m.template  'mime_types.rb', 'config/initializers/cms_mime_types.rb'

      m.directory 'app/controllers'
      m.template  'controllers/posts_controller.rb', 'app/controllers/posts_controller.rb'

      m.directory 'app/views/posts'
      m.template 'views/posts/index.html.erb',   'app/views/posts/index.html.erb'
      m.template 'views/posts/show.html.erb',   'app/views/posts/show.html.erb'
      m.template 'views/posts/new.html.erb',   'app/views/posts/new.html.erb'
      m.template 'views/posts/edit.html.erb',  'app/views/posts/edit.html.erb'
      m.template 'views/posts/_form.erb', 'app/views/posts/_form.erb'
      m.template 'views/posts/_permissions_form.erb', 'app/views/posts/_permissions_form.erb'
      m.template 'views/posts/index.atom.builder', 'app/views/posts/index.atom.builder'
      m.template 'views/posts/_entry.builder', 'app/views/posts/_entry.builder'
      
      m.directory 'app/views/layouts'
      m.template  'views/layout.html.erb', 'app/views/layouts/posts.html.erb'

      unless options[:skip_migration]
        m.migration_template 'migration.rb', 'db/migrate',
          :migration_file_name => "cms_setup"
      end

      m.route_cms
    end
  end
end
