require 'ostruct'

require 'dalek/base_error'
require 'dalek/extermination'
require 'dalek/reflections_graph'
require 'dalek/utils'
require 'dalek/version'

class Dalek
  class << self
    attr_reader :target_class, :deletion_tree

    def extermination_schema(target_class, deletion_tree = nil)
      @target_class = target_class
      @deletion_tree = deletion_tree || yield
    end

    def exterminate(*args)
      new(*args).exterminate
    end
    alias call exterminate
  end

  def initialize(target)
    @target = target
  end

  def exterminate
    Extermination.new([@target],
                      self.class.deletion_tree,
                      context: self,
                      target_class: Object.const_get(self.class.target_class))
                 .call
  end

  private

  def sql(query)
    ActiveRecord::Base.connection.execute(query)
  end

  def select_with_struct(query)
    sql(query).to_a.map { |attrs| OpenStruct.new(**attrs.symbolize_keys) }
  end

  def sql_array(collection)
    values = collection.map { |o| o.respond_to?(:id) ? o.id : o }.join(', ')
    values.empty? ? nil : "(#{values})"
  end

  def select_values(query)
    ActiveRecord::Base.connection.select_values(query)
  end
end
