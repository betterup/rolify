module Rolify
  module Adapter
    module Scopes
      def global
        where(:resource_type => nil, :resource_id => nil, :resource_uuid => nil)
      end

      def class_scoped(resource_type = nil)
        where_conditions = "resource_type IS NOT NULL AND resource_id IS NULL AND resource_uuid IS NULL"
        where_conditions = [ "resource_type = ? AND resource_id IS NULL AND resource_uuid IS NULL", resource_type.name ] if resource_type
        where(where_conditions)
      end

      def instance_scoped(resource_type = nil)
        where_conditions = "resource_type IS NOT NULL AND (resource_id IS NOT NULL OR resource_uuid IS NOT NULL)"
        if resource_type
          if resource_type.is_a? Class
            where_conditions = [ "resource_type = ? AND (resource_id IS NOT NULL OR resource_uuid IS NOT NULL)", resource_type.name ]
          else
            # Check if the resource ID is a string (UUID) or integer
            if resource_type.id.is_a?(String)
              where_conditions = [ "resource_type = ? AND resource_uuid = ?", resource_type.class.name, resource_type.id ]
            else
              where_conditions = [ "resource_type = ? AND resource_id = ?", resource_type.class.name, resource_type.id ]
            end
          end
        end
        where(where_conditions)
      end
    end
  end
end