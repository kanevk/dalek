require 'ostruct'

require 'dalek/base_error'
require 'dalek/extermination'
require 'dalek/reflections_graph'
# require 'dalek/extermination_dsl'
require 'dalek/utils'
require 'dalek/version'

class DeletionDSL
  def self.call(handler, &block)
    new(handler).tap { |dsl| dsl.instance_eval(&block) }.deletion_tree
  end

  attr_reader :deletion_tree

  def initialize(handler)
    @deletion_tree = {_handler: handler}
  end

  def resolve(name, **options, &block)
    @deletion_tree[Array[name, options]] = block
  end

  def skip(*args, **options, &block)
    handle_nested(*args, :skip, **options, &block)
  end

  def delete(*args, **options, &block)
    handle_nested(*args, :delete, **options, &block)
  end

  def handle_nested(*names, handler, **options, &block)
    names.each do |name|
      @deletion_tree[Array[name, options.dup]] =
        block_given? ? DeletionDSL.call(handler, &block) : handler
    end
  end

  def before(&callback)
    @deletion_tree[:_before] = callback
  end

  def after(&callback)
    @deletion_tree[:_after] = callback
  end

  def on_resolve(&callback)
    @deletion_tree[:_handler] = callback
  end
end

class Dalek
  class << self
    attr_reader :table_name, :deletion_tree

    def delete(table_name, deletion_tree = nil, &block)
      @table_name = table_name
      @deletion_tree = deletion_tree || DeletionDSL.call(:delete, &block)
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
                      table_name: self.class.table_name)
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
