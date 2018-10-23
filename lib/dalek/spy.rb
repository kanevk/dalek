module Dalek
  # Use:
  #
  # class User < ActiveRecord::Base
  #   extend Dalek::Spy
  #
  #   hidden_association :has_many, :posts
  # end
  module Spy
    def hidden_association(type, name, scope: nil, **options)
      reflection =
        reflection_builder_by_type(type).build self, name, scope, options

      add_hidden_reflection reflection

      reflection
    end

    def hidden_reflections
      @hidden_reflections ||= []
    end

    private

    def add_hidden_reflection(reflection)
      hidden_reflections << reflection
    end

    def reflection_builder_by_type(type)
      case type.to_sym
      when :has_many then ActiveRecord::Associations::Builder::HasMany
      when :has_one then ActiveRecord::Associations::Builder::HasOne
      else
        raise 'Unknown reflection type'
      end
    end
  end
end
