module Dalek
  module Exterminate
    attr_reader :target

    class AssociationNotDefined < BaseError
      def initialize(model_class, missing_association)
        super "Association #{missing_association} not defined for #{model_class}"
      end
    end

    module ClassInterface
      attr_reader :model_class_name, :deletion_tree

      def extermination_plan(model_class_name, deletion_tree = nil)
        @model_class_name = model_class_name
        @deletion_tree = deletion_tree || yield
      end

      def execute(*args)
        new(*args).execute
      end
    end

    class << self
      def included(base_class)
        base_class.extend ClassInterface
      end
    end

    def initialize(target)
      @target = target
    end

    def execute(current_target_model = target_model,
                foreign_key: nil,
                parent_scope: nil,
                current_deletion_tree: deletion_tree)

      current_scope =
        if parent_scope.nil?
          current_target_model.where(id: @target.id)
        else
          current_target_model.where(foreign_key => parent_scope)
        end

      options =
        if current_deletion_tree.is_a?(Symbol) || current_deletion_tree.is_a?(Proc)
          {_handler: current_deletion_tree}
        else
          {_handler: :delete}.merge(current_deletion_tree)
        end

      settings, child_tables = options.inject([{}, {}]) do |(settings, tables), (key, value),|
        if key.to_s.start_with?('_')
          [settings.merge!(key => value), tables]
        else
          [settings, tables.merge!(key => value)]
        end
      end

      # table name with association
      # named association
      # table name without association
      # infer the association by the reverse belongs_to
      # Issue: when an association is missing the associations tree is has cutted branch.
      child_tables.each do |table_or_association, inner_deletion_tree|
        reflection =
          current_target_model.reflections[table_or_association.to_s] ||
          current_target_model.reflections.values.find { |r| r.table_name.to_sym == table_or_association } ||
          current_target_model.hidden_reflections.find { |r| r.table_name.to_sym == table_or_association }

        if reflection.nil?
          raise AssociationNotDefined.new(current_target_model, table_or_association)
        end

        # TODO: handle has_many through relations
        execute reflection.klass,
                foreign_key: reflection&.foreign_key,
                parent_scope: current_scope,
                current_deletion_tree: inner_deletion_tree
      end

      return false if settings[:_before] && !instance_exec(current_scope, &settings[:_before])

      if settings[:_handler] == :delete
        current_scope.delete_all
      elsif settings[:_handler] == :skip
        nil
      elsif settings[:_handler].is_a? Proc
        instance_exec current_scope, &settings[:_handler]
      else
        raise "Unknown execution method #{settings[:_handler]}"
      end
    end

    private

    def deletion_tree
      self.class.deletion_tree
    end

    def target_model
      Object.const_get self.class.model_class_name
    end

    def model_by_table_name
      @model_by_table_name ||=
        ActiveRecord::Base.descendants.reject(&:abstract_class).index_by(&:table_name).symbolize_keys
    end

    def sql(query)
      ActiveRecord::Base.connection.execute query
    end
  end
end
