# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      module Sbom
        class Component
          include Gitlab::Utils::StrongMemoize

          attr_reader :ref, :component_type, :version, :path
          attr_accessor :properties, :purl, :source_package_name, :ancestors

          def initialize(ref:, type:, name:, purl:, version:, properties: nil, source_package_name: nil)
            @ref = ref
            @component_type = type
            @name = name
            @purl = purl
            @version = version
            @properties = properties
            @source_package_name = source_package_name
            @ancestors = []
          end

          def <=>(other)
            sort_by_attributes(self) <=> sort_by_attributes(other)
          end

          def ingestible?
            supported_component_type? && supported_purl_type?
          end

          def purl_type
            purl.type
          end

          def type
            component_type
          end

          def name
            return @name unless purl

            [purl.namespace, purl.name].compact.join('/')
          end

          def name_without_namespace
            @name
          end

          def key
            [name, version, purl&.type]
          end

          private

          def supported_component_type?
            ::Enums::Sbom.component_types.include?(component_type.to_sym)
          end

          def supported_purl_type?
            # the purl type is not required as per the spec: https://cyclonedx.org/docs/1.4/json/#components_items_purl
            return true unless purl

            # however, if the purl type is provided, it _must be valid_
            ::Enums::Sbom.purl_types.include?(purl.type.to_sym)
          end

          def sort_by_attributes(component)
            [
              component.name,
              purl_type_int(component),
              component_type_int(component),
              component.version.to_s
            ]
          end

          def component_type_int(component)
            ::Enums::Sbom::COMPONENT_TYPES.fetch(component.component_type.to_sym)
          end

          def purl_type_int(component)
            ::Enums::Sbom::PURL_TYPES.fetch(component.purl&.type&.to_sym, 0)
          end
        end
      end
    end
  end
end
