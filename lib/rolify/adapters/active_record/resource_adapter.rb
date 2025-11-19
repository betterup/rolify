require 'rolify/adapters/base'

module Rolify
  module Adapter
    class ResourceAdapter < ResourceAdapterBase
      def find_roles(role_name, relation, user)
        roles = user && (user != :any) ? user.roles : self.role_class
        roles = roles.where('resource_type IN (?)', self.relation_types_for(relation))
        roles = roles.where(:name => role_name.to_s) if role_name && (role_name != :any)
        roles
      end

      def resources_find(roles_table, relation, role_name)
        klasses   = self.relation_types_for(relation)
        relations = klasses.inject('') do |str, klass|
          str = "#{str}'#{klass.to_s}'"
          str << ', ' unless klass == klasses.last
          str
        end

        id_column = id_column_name(relation)

        resources = relation.joins("INNER JOIN #{quote_table(roles_table)} ON #{quote_table(roles_table)}.resource_type IN (#{relations}) AND
                                    (#{quote_table(roles_table)}.#{id_column} IS NULL OR #{quote_table(roles_table)}.#{id_column} = #{quote_table(relation.table_name)}.#{quote_column(relation.primary_key)})")
        resources = resources.where("#{quote_table(roles_table)}.name IN (?) AND #{quote_table(roles_table)}.resource_type IN (?)", Array(role_name), klasses)
        resources
      end

      def in(relation, user, role_names)
        roles = user.roles.where(:name => role_names).select("#{quote_table(role_class.table_name)}.#{quote_column(role_class.primary_key)}")
        id_column = id_column_name(relation)

        relation.where("#{quote_table(role_class.table_name)}.#{quote_column(role_class.primary_key)} IN (?) AND ((#{quote_table(role_class.table_name)}.#{id_column} = #{quote_table(relation.table_name)}.#{quote_column(relation.primary_key)}) OR (#{quote_table(role_class.table_name)}.#{id_column} IS NULL))", roles)
      end

      def applied_roles(relation, children)
        if children
          relation.role_class.where(resource_type: self.relation_types_for(relation), resource_id: nil, resource_uuid: nil)
        else
          relation.role_class.where(resource_type: relation.to_s, resource_id: nil, resource_uuid: nil)
        end
      end

      def all_except(resource, excluded_obj)
        prime_key = resource.primary_key.to_sym
        resource.where.not(prime_key => excluded_obj.pluck(prime_key))
      end

      private

      # Determines the appropriate ID column (resource_id or resource_uuid) based on the relation's primary key type
      # Returns the column name as a string
      def id_column_name(relation)
        pk_column = relation.columns_hash[relation.primary_key]
        uses_string_id = pk_column && pk_column.type.in?([:string, :uuid])
        uses_string_id ? "resource_uuid" : "resource_id"
      end

      def quote_column(column)
        ActiveRecord::Base.connection.quote_column_name column
      end

      def quote_table(table)
        ActiveRecord::Base.connection.quote_table_name table
      end

    end
  end
end
