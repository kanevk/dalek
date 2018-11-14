class Dalek
  class ReflectionsGraph
    class AssociationNotDefined < BaseError
      def initialize(model_class, missing_association)
        super "Association :#{missing_association} not defined for #{model_class}"
      end
    end

    class ThroughAssociationNotSupported < BaseError
      def initialize(*)
        super 'Though associations are not currently supported'
      end
    end

    def initialize(root_klass)
      @root_klass = root_klass
    end

    def reflections
      @reflections ||=
        own_reflections +
          all_belongs_to(@root_klass)
            .reject do |reverse_reflection|
              own_reflections.find { |r| r.klass == reverse_reflection.active_record }
            end
            .map { |r| create_reverse_reflection(@root_klass, r) }
    end

    def create_reverse_reflection(klass, belongs_to_reflection)
      reverse_name = belongs_to_reflection.active_record.table_name.to_sym
      foreign_key = belongs_to_reflection.foreign_key

      ActiveRecord::Reflection.create(:has_many, reverse_name, nil, {foreign_key: foreign_key}, klass)
    end

    def find(association_or_table)
      (@root_klass.reflections[association_or_table.to_s] ||
        reflections.find do |r|
          begin
            r.table_name.to_sym == association_or_table.to_sym
          rescue NameError
            false
          end
        end)
        .tap do |reflection|
          raise ThroughAssociationNotSupported if reflection&.through_reflection?
        end
    end

    private

    def own_reflections
      @root_klass.reflections.values.reject(&:through_reflection?).reject(&:polymorphic?)
    end

    def all_belongs_to(target_klass)
      Utils.all_model_classes.flat_map do |klass|
        klass
          .reflect_on_all_associations(:belongs_to)
          .reject(&:polymorphic?).reject(&:through_reflection?)
          .map { |r| r.klass == target_klass ? r : nil }
          .compact
          .uniq
      end
    end
  end
end
