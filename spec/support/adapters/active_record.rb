load File.dirname(__FILE__) + '/utils/active_record.rb'

extend_rspec_with_activerecord_specific_matchers
establish_connection

ActiveRecord::Base.extend Rolify

load File.dirname(__FILE__) + '/../schema.rb'

# Standard user and role classes
class User < ActiveRecord::Base
  rolify
end

# Join table model for users_roles
class UsersRole < ActiveRecord::Base
  belongs_to :user
  belongs_to :role
end

class Role < ActiveRecord::Base
  has_many :users_roles
  has_many :users, through: :users_roles
  has_many :strict_users_roles
  has_many :strict_users, through: :strict_users_roles

  belongs_to :resource, :polymorphic => true

  extend Rolify::Adapter::Scopes
end

# Strict user and role classes
class StrictUser < ActiveRecord::Base
  rolify strict: true
end

# Join table model for strict_users_roles
class StrictUsersRole < ActiveRecord::Base
  belongs_to :strict_user
  belongs_to :role
end

# Resourcifed and rolifed at the same time
class HumanResource < ActiveRecord::Base
  resourcify :resources
  rolify
end

# Join table model for human_resources_roles
class HumanResourcesRole < ActiveRecord::Base
  belongs_to :human_resource
  belongs_to :role
end

# Custom role and class names
class Customer < ActiveRecord::Base
  rolify :role_cname => "Privilege"
end

# Join table model for customers_privileges
class CustomersPrivilege < ActiveRecord::Base
  belongs_to :customer
  belongs_to :privilege, class_name: "Privilege"
end

class Privilege < ActiveRecord::Base
  has_many :customers_privileges
  has_many :customers, through: :customers_privileges, source: :customer
  belongs_to :resource, :polymorphic => true

  extend Rolify::Adapter::Scopes
end

# Namespaced models
module Admin
  def self.table_name_prefix
    'admin_'
  end

  class Moderator < ActiveRecord::Base
    rolify :role_cname => "Admin::Right", :role_join_table_name => "moderators_rights"
  end

  # Join table model for moderators_rights
  class ModeratorsRight < ActiveRecord::Base
    self.table_name = "moderators_rights"
    belongs_to :moderator, class_name: "Admin::Moderator"
    belongs_to :right, class_name: "Admin::Right"
  end

  class Right < ActiveRecord::Base
    has_many :moderators_rights, class_name: "Admin::ModeratorsRight"
    has_many :moderators, through: :moderators_rights, class_name: "Admin::Moderator"
    belongs_to :resource, :polymorphic => true

    extend Rolify::Adapter::Scopes
  end
end


# Resources classes
class Forum < ActiveRecord::Base
  #resourcify done during specs setup to be able to use custom user classes
end

class Group < ActiveRecord::Base
  #resourcify done during specs setup to be able to use custom user classes

  def subgroups
    Group.where(:parent_id => id)
  end
end

class Team < ActiveRecord::Base
  #resourcify done during specs setup to be able to use custom user classes
  self.primary_key = "team_code"

  default_scope { order(:team_code) }
end

class Organization < ActiveRecord::Base

end

class Company < Organization

end

class License < ActiveRecord::Base
  # UUID primary key model for testing UUID resource support
end
