require 'mongo_mapper'

module MongoMapper
  module Plugins
    module Sluggable
      def self.configure(model)
        class << model
          alias_method :origin_find, :find
          def find(*args)
            arg_f = args.first
            if (args.size == 1) && arg_f.is_a?(String) && ( arg_f !~ /^[0-9a-f]{24}$/i )
              options = slug_options
              first options[:key] => arg_f
            else
              origin_find *args
            end
          end
        end
      end

      module ClassMethods
        def sluggable(to_slug = :title, options = {})
          class_attribute :slug_options

          self.slug_options = {
            :to_slug      => to_slug,
            :key          => :slug,
            :index        => true,
            :method       => :parameterize,
            :scope        => nil,
            :callback     => :before_validation_on_create,
            :force        => false
          }.merge(options)

          key slug_options[:key], String, :index => slug_options[:index]

          self.send(slug_options[:callback], :set_slug)
        end
      end

      module InstanceMethods
        def set_slug
          options = self.class.slug_options
          need_set_slug = self.send(options[:key]).blank? || (options[:force] && self.send(:"#{options[:to_slug]}_changed?"))
          return unless need_set_slug

          to_slug = self[options[:to_slug]]
          return if to_slug.blank?

          the_slug = raw_slug = to_slug.send(options[:method]).to_s

          conds = {}
          conds[options[:key]]   = the_slug
          conds[options[:scope]] = self.send(options[:scope]) if options[:scope]

          # todo - remove the loop and use regex instead so we can do it in one query
          i = 0
          while self.class.first(conds)
            i += 1
            conds[options[:key]] = the_slug = "#{raw_slug}-#{i}"
          end

          self.send(:"#{options[:key]}=", the_slug)
        end
        
        def to_param
          options = self.class.slug_options
          ( self.send(options[:key]) || self.id ).to_s
        end
      end
    end
  end
end
