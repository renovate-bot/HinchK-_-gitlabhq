# frozen_string_literal: true

module Gitlab
  module Security
    class Features
      # rubocop: disable Metrics/AbcSize -- Generate dynamic translation as per
      # https://docs.gitlab.com/ee/development/i18n/externalization.html#keep-translations-dynamic
      def self.data
        {
          sast: {
            name: _('Static Application Security Testing (SAST)'),
            short_name: _('SAST'),
            description: _('Analyze your source code for known vulnerabilities.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path('user/application_security/sast/index'),
            configuration_help_path: Gitlab::Routing.url_helpers.help_page_path('user/application_security/sast/index',
              anchor: 'configuration'),
            type: 'sast'
          },
          sast_iac: {
            name: _('Infrastructure as Code (IaC) Scanning'),
            short_name: s_('ciReport|SAST IaC'),
            description: _('Analyze your infrastructure as code configuration files for known vulnerabilities.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path('user/application_security/iac_scanning/index'),
            configuration_help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/iac_scanning/index',
              anchor: 'configuration'),
            type: 'sast_iac'
          },
          dast: {
            badge: {
              text: _('Available on demand'),
              tooltip_text: _(
                'On-demand scans run outside of the DevOps cycle and find vulnerabilities in your projects'),
              variant: 'info'
            },
            secondary: {
              type: 'dast_profiles',
              name: _('DAST profiles'),
              description: s_('SecurityConfiguration|Manage profiles for use by DAST scans.'),
              configuration_text: s_('SecurityConfiguration|Manage profiles')
            },
            name: _('Dynamic Application Security Testing (DAST)'),
            short_name: s_('ciReport|DAST'),
            description: s_('ciReport|Analyze a deployed version of your web application for known ' \
                            'vulnerabilities by examining it from the outside in. DAST works ' \
                            'by simulating external attacks on your application while it is running.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path('user/application_security/dast/index'),
            configuration_help_path: Gitlab::Routing.url_helpers.help_page_path('user/application_security/dast/index',
              anchor: 'enable-automatic-dast-run'),
            type: 'dast',
            anchor: 'dast'
          },
          dependency_scanning: {
            name: _('Dependency Scanning'),
            description: _('Analyze your dependencies for known vulnerabilities.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/dependency_scanning/index'),
            configuration_help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/dependency_scanning/index', anchor: 'configuration'),
            type: 'dependency_scanning',
            anchor: 'dependency-scanning'
          },
          container_scanning: {
            name: _('Container Scanning'),
            description: _('Check your Docker images for known vulnerabilities.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/container_scanning/index'),
            configuration_help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/container_scanning/index', anchor: 'configuration'),
            type: 'container_scanning'
          },
          secret_detection: {
            name: _('Secret Detection'),
            description: _('Analyze your source code and git history for secrets.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/secret_detection/index'),
            configuration_help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/secret_detection/index', anchor: 'configuration'),
            type: 'secret_detection'
          },
          api_fuzzing: {
            name: _('API Fuzzing'),
            description: _('Find bugs in your code with API fuzzing.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/api_fuzzing/index'),
            type: 'api_fuzzing'
          },
          coverage_fuzzing: {
            name: _('Coverage Fuzzing'),
            description: _('Find bugs in your code with coverage-guided fuzzing.'),
            help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/coverage_fuzzing/index'),
            configuration_help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/coverage_fuzzing/index', anchor: 'enable-coverage-guided-fuzz-testing'),
            type: 'coverage_fuzzing',
            secondary: {
              type: 'corpus_management',
              name: _('Corpus Management'),
              description: s_('SecurityConfiguration|Manage corpus files used as seed ' \
                              'inputs with coverage-guided fuzzing.'),
              configuration_text: s_('SecurityConfiguration|Manage corpus')
            }
          },
          breach_and_attack_simulation: {
            anchor: 'bas',
            badge: {
              always_display: true,
              text: s_('SecurityConfiguration|Incubating feature'),
              tooltip_text: s_('SecurityConfiguration|Breach and Attack Simulation is an incubating ' \
                               'feature extending existing security testing by simulating adversary activity.'),
              variant: 'info'
            },
            description: s_('SecurityConfiguration|Simulate breach and attack scenarios against your ' \
                            'running application by attempting to detect and exploit known vulnerabilities.'),
            name: s_('SecurityConfiguration|Breach and Attack Simulation (BAS)'),
            help_path: Gitlab::Routing.url_helpers.help_page_path(
              'user/application_security/breach_and_attack_simulation/index'),
            secondary: {
              configuration_help_path: Gitlab::Routing.url_helpers.help_page_path(
                'user/application_security/breach_and_attack_simulation/index',
                anchor: 'extend-dynamic-application-security-testing-dast'),
              description: s_('SecurityConfiguration|Enable incubating Breach and Attack Simulation focused ' \
                              'features such as callback attacks in your DAST scans.'),
              name: s_('SecurityConfiguration|Out-of-Band Application Security Testing (OAST)')
            },
            short_name: s_('SecurityConfiguration|BAS'),
            type: 'breach_and_attack_simulation'
          }
        }.freeze
      end
      # rubocop: enable Metrics/AbcSize
    end
  end
end
