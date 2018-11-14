class Dalek
  class Extermination
    ScopeOptions = Struct.new(:table_name, :parent_reference_column, :reference_column, :model_class, keyword_init: true) do
      def self.from_records(model_class, _records)
        new(
          table_name: model_class.table_name,
          parent_reference_column: model_class.primary_key,
          reference_column: nil,
          model_class: model_class
        )
      end
    end

    DeletionTree = Struct.new(:scope_options,
                              :handler,
                              :before,
                              :after,
                              :sub_trees,
                              keyword_init: true)

    def initialize(targets, deletion_tree, context:, target_class:)
      @targets = targets
      @deletion_tree = deletion_tree
      @context = context
      @target_class = target_class
    end

    def call
      execute_recursively parse_deletion_tree(ScopeOptions.from_records(@target_class, @targets),
                                            @deletion_tree),
                          scope: @target_class.where(id: @targets)
    end

    private

    def execute_recursively(deletion_tree, scope:)
      cached_scope = scope.to_a if deletion_tree.after

      return if deletion_tree.before &&
                @context.instance_exec(scope, &deletion_tree.before) == false

      deletion_tree.sub_trees.each do |sub_tree|
        execute_recursively sub_tree, scope: scope_for(scope, sub_tree.scope_options)
      end

      if deletion_tree.handler == :delete
        scope.delete_all
      elsif deletion_tree.handler == :skip
        nil
      elsif deletion_tree.handler.is_a? Proc
        @context.instance_exec(scope, &deletion_tree.handler)
      else
        raise "Unknown execution method #{deletion_tree.handler}"
      end

      @context.instance_exec(cached_scope, &deletion_tree.after) if deletion_tree.after
    end

    def parse_deletion_tree(scope_options, raw_tree)
      raw_tree = {_handler: raw_tree} unless raw_tree.is_a? Hash

      raw_settings, raw_sub_trees =
        raw_tree.partition { |(key, _)| key.is_a?(Symbol) && key.match?('\A_') }.map(&:to_h)

      settings =
        {handler: :delete, scope_options: scope_options, sub_trees: []}
        .merge(raw_settings.transform_keys { |k| k[1..-1].to_sym })

      settings[:sub_trees] = raw_sub_trees.map do |(raw_scope_pair, raw_sub_tree)|
        table_or_association_name, raw_scope_options = Array.wrap(raw_scope_pair)
        raw_scope_options ||= {}

        sub_scope_options =
          build_scope_options(scope_options, table_or_association_name, raw_scope_options)

        parse_deletion_tree(sub_scope_options, raw_sub_tree)
      end

      DeletionTree.new(**settings)
    end

    def build_scope_options(parent_scope_options, table_or_association_name, raw_scope_options)
      reflection = find_reflection(parent_scope_options.model_class, table_or_association_name)
      if reflection.nil?
        ScopeOptions.new(
          table_name: table_or_association_name,
          parent_reference_column: raw_scope_options[:primary_key] || :id,
          reference_column: raw_scope_options[:foreign_key],
          model_class: model_by_table_name[table_or_association_name]
        )
      elsif reflection.belongs_to?
        ScopeOptions.new(
          table_name: reflection.table_name.to_sym,
          parent_reference_column: reflection.foreign_key,
          reference_column: reflection.active_record_primary_key,
          model_class: reflection.klass
        )
      else
        ScopeOptions.new(
          table_name: reflection.table_name.to_sym,
          parent_reference_column: reflection.association_primary_key,
          reference_column: reflection.foreign_key,
          model_class: reflection.klass
        )
      end
    end

    def find_reflection(model_class, table_or_association_name)
      @reflections_graph_per_class ||= {}
      (@reflections_graph_per_class[model_class] ||= ReflectionsGraph.new(model_class))
        .find(table_or_association_name)
    end

    def scope_for(parent_scope, scope_options)
      scope_options.model_class.where(
        scope_options.reference_column => parent_scope.select(scope_options.parent_reference_column)
      )
    end

    def target_model
      Object.const_get self.class.model_class_name
    end

    def model_by_table_name
      @model_by_table_name ||=
        ActiveRecord::Base.descendants.reject(&:abstract_class).index_by(&:table_name).symbolize_keys
    end
  end
end
