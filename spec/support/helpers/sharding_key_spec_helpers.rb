# frozen_string_literal: true

module ShardingKeySpecHelpers
  def not_nullable?(table_name, column_name)
    sql = <<~SQL
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public' AND
    table_name = '#{table_name}' AND
    column_name = '#{column_name}' AND
    is_nullable = 'NO'
    SQL

    result = ApplicationRecord.connection.execute(sql)

    result.count > 0
  end

  def has_null_check_constraint?(table_name, column_name)
    # This is a heuristic query to look for all check constraints on the table and see if any of them contain a clause
    # column IS NOT NULL. This is to match tables that will have multiple sharding keys where either of them can be not
    # null. Such cases may look like:
    #    (project_id IS NOT NULL) OR (group_id IS NOT NULL)
    # It's possible that this will sometimes incorrectly find a check constraint that isn't exactly as strict as we want
    # but it should be pretty unlikely.
    sql = <<~SQL
    SELECT 1
    FROM pg_constraint
    INNER JOIN pg_class ON pg_constraint.conrelid = pg_class.oid
    WHERE pg_class.relname = '#{table_name}'
    AND contype = 'c'
    AND pg_get_constraintdef(pg_constraint.oid) ILIKE '%#{column_name} IS NOT NULL%'
    SQL

    result = ApplicationRecord.connection.execute(sql)

    result.count > 0
  end

  def has_foreign_key?(from_table_name, column_name, to_table_name: nil)
    where_clause = {
      constrained_table_name: from_table_name,
      constrained_columns: [column_name]
    }

    where_clause[:referenced_table_name] = to_table_name if to_table_name

    fk = ::Gitlab::Database::PostgresForeignKey.where(where_clause).first

    lfk = ::Gitlab::Database::LooseForeignKeys.definitions.find do |d|
      d.from_table == from_table_name &&
        (to_table_name.nil? || d.to_table == to_table_name) &&
        d.options[:column] == column_name
    end

    fk.present? || lfk.present?
  end

  def column_exists?(table_name, column_name)
    sql = <<~SQL
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public' AND
    table_name = '#{table_name}' AND
    column_name = '#{column_name}';
    SQL

    result = ApplicationRecord.connection.execute(sql)

    result.count > 0
  end
end
