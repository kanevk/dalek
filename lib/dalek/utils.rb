class Dalek
  module Utils
    extend self

    def all_model_classes
      ActiveRecord::Base.descendants.reject(&:abstract_class)
    end

    def all_foreign_keys
      ActiveRecord::Base.connection.execute(<<~SQL).map { |data| OpenStruct.new(**data) }
        SELECT
            tc.table_name AS from_table,
            kcu.column_name AS foreign_key,
            ccu.table_name AS to_table
        FROM
          information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        WHERE constraint_type = 'FOREIGN KEY'
      SQL
    end
  end
end
