require "spec_helper"

describe "Rolify with UUID resources" do
  if ENV['ADAPTER'] == 'active_record'
    before(:all) do
      License.resourcify :roles, :role_cname => "Role"
      Role.destroy_all
    end

    let(:user) { User.first }
    let(:license) { License.first }

    before(:each) do
      Role.destroy_all
    end

    context "with UUID primary keys" do
      describe "adding roles" do
        it "creates role with resource_uuid instead of resource_id" do
          user.add_role(:admin, license)

          role = Role.last
          expect(role.name).to eq("admin")
          expect(role.resource_type).to eq("License")
          expect(role.resource_id).to be_nil
          expect(role.resource_uuid).to eq(license.id)
          expect(role.resource_uuid).to be_a(String)
        end

        it "creates class scoped role with resource_uuid nil" do
          user.add_role(:manager, License)

          role = Role.last
          expect(role.name).to eq("manager")
          expect(role.resource_type).to eq("License")
          expect(role.resource_id).to be_nil
          expect(role.resource_uuid).to be_nil
        end

        it "creates global role with both resource columns nil" do
          user.add_role(:admin)

          role = Role.last
          expect(role.name).to eq("admin")
          expect(role.resource_type).to be_nil
          expect(role.resource_id).to be_nil
          expect(role.resource_uuid).to be_nil
        end
      end

      describe "#has_role?" do
        before { user.add_role(:admin, license) }

        it "returns true for instance scoped role" do
          expect(user.has_role?(:admin, license)).to be true
        end

        it "returns true with :any parameter" do
          expect(user.has_role?(:admin, :any)).to be true
        end

        it "returns true when checking class scope" do
          expect(user.has_role?(:admin, License.first)).to be true
        end

        it "returns false for different license" do
          other_license = License.last
          expect(user.has_role?(:admin, other_license)).to be false
        end

        it "returns false for wrong role name" do
          expect(user.has_role?(:moderator, license)).to be false
        end

        it "distinguishes between UUID and integer resources" do
          forum = Forum.first
          user.add_role(:admin, forum)

          # Should have role on forum (integer ID)
          expect(user.has_role?(:admin, forum)).to be true
          # Still has role on license (UUID)
          expect(user.has_role?(:admin, license)).to be true

          # Check the roles were stored correctly
          license_role = user.roles.find_by(resource_type: 'License')
          forum_role = user.roles.find_by(resource_type: 'Forum')

          expect(license_role.resource_uuid).to eq(license.id)
          expect(license_role.resource_id).to be_nil
          expect(forum_role.resource_id).to eq(forum.id)
          expect(forum_role.resource_uuid).to be_nil
        end
      end

      describe "#has_cached_role?" do
        before { user.add_role(:moderator, license) }

        it "returns true for instance scoped role with preloaded roles" do
          cached_user = User.includes(:roles).find(user.id)
          expect(cached_user.has_cached_role?(:moderator, license)).to be true
        end

        it "returns true with :any parameter" do
          cached_user = User.includes(:roles).find(user.id)
          expect(cached_user.has_cached_role?(:moderator, :any)).to be true
        end

        it "returns false for different license" do
          cached_user = User.includes(:roles).find(user.id)
          other_license = License.last
          expect(cached_user.has_cached_role?(:moderator, other_license)).to be false
        end

        it "works correctly with mixed UUID and integer resources" do
          forum = Forum.first
          user.add_role(:moderator, forum)

          cached_user = User.includes(:roles).find(user.id)
          expect(cached_user.has_cached_role?(:moderator, license)).to be true
          expect(cached_user.has_cached_role?(:moderator, forum)).to be true
        end
      end

      describe "scopes" do
        describe ".global" do
          it "returns only global roles" do
            global_role = user.add_role(:admin)
            user.add_role(:manager, license)

            expect(user.roles.global).to eq([global_role])
          end
        end

        describe ".class_scoped" do
          it "returns class scoped roles for UUID resources" do
            class_role = user.add_role(:manager, License)
            user.add_role(:admin, license)

            expect(user.roles.class_scoped).to include(class_role)
            expect(user.roles.class_scoped(License)).to eq([class_role])
          end

          it "does not return instance scoped UUID roles" do
            user.add_role(:admin, license)

            expect(user.roles.class_scoped(License)).to be_empty
          end
        end

        describe ".instance_scoped" do
          it "returns instance scoped roles for UUID resources" do
            instance_role = user.add_role(:visitor, license)
            user.add_role(:manager, License)

            expect(user.roles.instance_scoped).to include(instance_role)
            expect(user.roles.instance_scoped(License)).to include(instance_role)
          end

          it "filters by specific UUID resource" do
            license1_role = user.add_role(:visitor, License.first)
            license2_role = user.add_role(:visitor, License.last)

            expect(user.roles.instance_scoped(License.first)).to eq([license1_role])
            expect(user.roles.instance_scoped(License.last)).to eq([license2_role])
          end

          it "works with both UUID and integer resources" do
            license_role = user.add_role(:visitor, license)
            forum_role = user.add_role(:visitor, Forum.first)

            all_instance_roles = user.roles.instance_scoped
            expect(all_instance_roles).to include(license_role, forum_role)
          end
        end
      end

      describe "#remove_role" do
        it "removes role from UUID resource" do
          user.add_role(:admin, license)
          expect(user.has_role?(:admin, license)).to be true

          user.remove_role(:admin, license)
          expect(user.has_role?(:admin, license)).to be false
        end

        it "removes correct role when multiple UUID resources exist" do
          user.add_role(:admin, License.first)
          user.add_role(:admin, License.last)

          user.remove_role(:admin, License.first)

          expect(user.has_role?(:admin, License.first)).to be false
          expect(user.has_role?(:admin, License.last)).to be true
        end

        it "only removes UUID role, not integer role with same name" do
          user.add_role(:admin, license)
          user.add_role(:admin, Forum.first)

          user.remove_role(:admin, license)

          expect(user.has_role?(:admin, license)).to be false
          expect(user.has_role?(:admin, Forum.first)).to be true
        end
      end

      describe "Resource.with_role" do
        it "finds UUID resources with specific role" do
          user.add_role(:admin, License.first)
          user.add_role(:admin, License.second)

          admins = License.with_role(:admin, user)
          expect(admins).to include(License.first, License.second)
          expect(admins).not_to include(License.last)
        end

        it "finds UUID resources with class scoped role" do
          user.add_role(:manager, License)

          managers = License.with_role(:manager, user)
          expect(managers.count).to eq(License.count)
        end

        it "finds integer ID resources with specific role" do
          Forum.resourcify :roles, :role_cname => "Role"
          user.add_role(:moderator, Forum.first)
          user.add_role(:moderator, Forum.second)

          moderators = Forum.with_role(:moderator, user)
          expect(moderators).to include(Forum.first, Forum.second)
          expect(moderators).not_to include(Forum.last)
        end

        it "finds integer ID resources with class scoped role" do
          Forum.resourcify :roles, :role_cname => "Role"
          user.add_role(:editor, Forum)

          editors = Forum.with_role(:editor, user)
          expect(editors.count).to eq(Forum.count)
        end
      end

      describe "mixed UUID and integer ID resources" do
        before(:all) do
          Forum.resourcify :roles, :role_cname => "Role"
        end

        it "correctly distinguishes between UUID and integer resources in queries" do
          # Add roles to both UUID and integer ID resources
          user.add_role(:owner, license)
          user.add_role(:owner, Forum.first)

          # Query each type separately
          license_owners = License.with_role(:owner, user)
          forum_owners = Forum.with_role(:owner, user)

          # Verify they return the correct resources
          expect(license_owners).to include(license)
          expect(license_owners.to_a).not_to include(Forum.first)
          expect(forum_owners).to include(Forum.first)
          expect(forum_owners.to_a).not_to include(license)
        end

        it "maintains separate role storage for UUID vs integer IDs" do
          # Create roles on both types
          user.add_role(:contributor, license)
          user.add_role(:contributor, Forum.first)

          # Check the roles were stored with correct ID columns
          license_role = Role.find_by(name: 'contributor', resource_type: 'License')
          forum_role = Role.find_by(name: 'contributor', resource_type: 'Forum')

          expect(license_role.resource_uuid).to eq(license.id)
          expect(license_role.resource_id).to be_nil
          expect(forum_role.resource_id).to eq(Forum.first.id)
          expect(forum_role.resource_uuid).to be_nil
        end
      end

      describe "empty table handling" do
        it "handles empty UUID resource tables correctly" do
          # Delete all licenses to test with empty table
          License.delete_all

          # Add a class-scoped role (no specific license instance)
          user.add_role(:viewer, License)

          # Should return empty relation without errors
          # The key is that it doesn't fail when determining column type on empty table
          viewers = License.with_role(:viewer, user)
          expect(viewers.count).to eq(0)
          expect(viewers).to be_empty
        end
      end
    end
  end
end
