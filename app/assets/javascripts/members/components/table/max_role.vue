<script>
import { GlBadge, GlCollapsibleListbox, GlTooltipDirective } from '@gitlab/ui';
import { GlBreakpointInstance as bp } from '@gitlab/ui/dist/utils';
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { guestOverageConfirmAction } from 'ee_else_ce/members/guest_overage_confirm_action';
import { roleDropdownItems, initialSelectedRole } from 'ee_else_ce/members/utils';
import { ACCESS_LEVEL_LABELS } from '~/access_level/constants';
import { s__ } from '~/locale';

export default {
  components: {
    GlCollapsibleListbox,
    GlBadge,
    LdapDropdownFooter: () =>
      import('ee_component/members/components/action_dropdowns/ldap_dropdown_footer.vue'),
    ManageRolesDropdownFooter: () =>
      import('ee_component/members/components/action_dropdowns/manage_roles_dropdown_footer.vue'),
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['namespace', 'group'],
  props: {
    member: {
      type: Object,
      required: true,
    },
    permissions: {
      type: Object,
      required: true,
    },
  },
  data() {
    const accessLevelOptions = roleDropdownItems(this.member);
    return {
      accessLevelOptions,
      busy: false,
      customPermissions: this.member.customPermissions ?? [],
      isDesktop: false,
      memberRoleId: this.member.accessLevel.memberRoleId ?? null,
      selectedRole: initialSelectedRole(accessLevelOptions.flatten, this.member),
    };
  },
  computed: {
    disabled() {
      return this.permissions.canOverride && !this.member.isOverridden;
    },
  },
  mounted() {
    this.isDesktop = bp.isDesktop();
  },
  methods: {
    ...mapActions({
      updateMemberRole(dispatch, { memberId, accessLevel, memberRoleId }) {
        return dispatch(`${this.namespace}/updateMemberRole`, {
          memberId,
          accessLevel,
          memberRoleId,
        });
      },
    }),
    async handleSelect(value) {
      this.busy = true;

      const newRole = this.accessLevelOptions.flatten.find((item) => item.value === value);
      const previousRole = this.selectedRole;
      const previousMemberRoleId = this.memberRoleId;

      try {
        const confirmed = await guestOverageConfirmAction({
          oldAccessLevel: this.member.accessLevel.integerValue,
          newRoleName: ACCESS_LEVEL_LABELS[newRole.accessLevel],
          newMemberRoleId: newRole.memberRoleId,
          group: this.group,
          memberId: this.member.id,
          memberType: this.namespace,
        });
        if (!confirmed) {
          return;
        }

        this.selectedRole = value;
        this.memberRoleId = newRole.memberRoleId;

        await this.updateMemberRole({
          memberId: this.member.id,
          accessLevel: newRole.accessLevel,
          memberRoleId: newRole.memberRoleId,
        });

        this.$toast.show(s__('Members|Role updated successfully.'));
      } catch (error) {
        this.selectedRole = previousRole;
        this.memberRoleId = previousMemberRoleId;
        Sentry.captureException(error);
      } finally {
        this.busy = false;
      }
    },
  },
  i18n: {
    customRole: s__('MemberRole|Custom role'),
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      v-if="permissions.canUpdate"
      :placement="isDesktop ? 'left' : 'right'"
      :header-text="__('Change role')"
      :disabled="disabled"
      :loading="busy"
      data-testid="access-level-dropdown"
      :items="accessLevelOptions.formatted"
      :selected="selectedRole"
      @select="handleSelect"
    >
      <template #list-item="{ item }">
        <div data-testid="access-level-link" :class="{ 'gl-font-weight-bold': item.memberRoleId }">
          {{ item.text }}
        </div>
        <div v-if="item.description" class="gl-text-gray-700 gl-font-sm gl-pt-1 gl-line-clamp-2">
          {{ item.description }}
        </div>
      </template>
      <template #footer>
        <ldap-dropdown-footer
          v-if="permissions.canOverride && member.isOverridden"
          :member-id="member.id"
        />
        <manage-roles-dropdown-footer />
      </template>
    </gl-collapsible-listbox>

    <div v-else v-gl-tooltip.ds0="member.accessLevel.description" data-testid="role-text">
      {{ member.accessLevel.stringValue }}
    </div>

    <gl-badge v-if="memberRoleId" class="gl-mt-3">{{ $options.i18n.customRole }}</gl-badge>
  </div>
</template>
