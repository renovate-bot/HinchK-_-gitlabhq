# frozen_string_literal: true

module Ci
  class Stage < Ci::ApplicationRecord
    include Ci::Partitionable
    include Importable
    include Ci::HasStatus
    include Gitlab::OptimisticLocking
    include Presentable

    ROUTING_FEATURE_FLAG = :ci_partitioning_use_ci_stages_routing_table

    self.primary_key = :id
    self.sequence_name = :ci_job_stages_id_seq

    partitionable scope: :pipeline, through: {
      table: :p_ci_stages,
      flag: ROUTING_FEATURE_FLAG
    }

    enum status: Ci::HasStatus::STATUSES_ENUM

    belongs_to :project
    belongs_to :pipeline

    has_many :statuses,
      ->(stage) { in_partition(stage) },
      class_name: 'CommitStatus',
      foreign_key: :stage_id,
      partition_foreign_key: :partition_id,
      inverse_of: :ci_stage
    has_many :latest_statuses,
      ->(stage) { in_partition(stage).ordered.latest },
      class_name: 'CommitStatus',
      foreign_key: :stage_id,
      partition_foreign_key: :partition_id,
      inverse_of: :ci_stage
    has_many :retried_statuses,
      ->(stage) { in_partition(stage).ordered.retried },
      class_name: 'CommitStatus',
      foreign_key: :stage_id,
      partition_foreign_key: :partition_id,
      inverse_of: :ci_stage
    has_many :processables,
      ->(stage) { in_partition(stage) },
      class_name: 'Ci::Processable',
      foreign_key: :stage_id,
      partition_foreign_key: :partition_id,
      inverse_of: :ci_stage
    has_many :builds,
      ->(stage) { in_partition(stage) },
      foreign_key: :stage_id,
      partition_foreign_key: :partition_id,
      inverse_of: :ci_stage
    has_many :bridges,
      ->(stage) { in_partition(stage) },
      foreign_key: :stage_id,
      partition_foreign_key: :partition_id,
      inverse_of: :ci_stage
    has_many :generic_commit_statuses,
      ->(stage) { in_partition(stage) },
      foreign_key: :stage_id,
      partition_foreign_key: :partition_id,
      inverse_of: :ci_stage

    scope :ordered, -> { order(position: :asc) }
    scope :in_pipelines, ->(pipelines) { where(pipeline: pipelines) }
    scope :by_name, ->(names) { where(name: names) }
    scope :by_position, ->(positions) { where(position: positions) }

    with_options unless: :importing? do
      validates :project, presence: true
      validates :pipeline, presence: true
      validates :name, presence: true
      validates :position, presence: true
    end

    after_initialize do
      self.status = DEFAULT_STATUS if self.status.nil?
    end

    before_validation unless: :importing? do
      next if position.present?

      self.position = statuses.select(:stage_idx)
        .where.not(stage_idx: nil)
        .group(:stage_idx)
        .order('COUNT(id) DESC')
        .first&.stage_idx.to_i
    end

    state_machine :status, initial: :created do
      event :enqueue do
        transition any - [:pending] => :pending
      end

      event :request_resource do
        transition any - [:waiting_for_resource] => :waiting_for_resource
      end

      event :prepare do
        transition any - [:preparing] => :preparing
      end

      event :run do
        transition any - [:running] => :running
      end

      event :wait_for_callback do
        transition any - [:waiting_for_callback] => :waiting_for_callback
      end

      event :skip do
        transition any - [:skipped] => :skipped
      end

      event :drop do
        transition any - [:failed] => :failed
      end

      event :succeed do
        transition any - [:success] => :success
      end

      event :canceling do
        transition any - [:canceling, :canceled] => :canceling
      end

      event :cancel do
        transition any - [:canceled] => :canceled
      end

      event :block do
        transition any - [:manual] => :manual
      end

      event :delay do
        transition any - [:scheduled] => :scheduled
      end
    end

    def self.use_partition_id_filter?
      Ci::Pipeline.use_partition_id_filter?
    end

    # rubocop: disable Metrics/CyclomaticComplexity -- breaking apart hurts readability, consider refactoring issue #439268
    def set_status(new_status)
      retry_optimistic_lock(self, name: 'ci_stage_set_status') do
        case new_status
        when 'created' then nil
        when 'waiting_for_resource' then request_resource
        when 'preparing' then prepare
        when 'waiting_for_callback' then wait_for_callback
        when 'pending' then enqueue
        when 'running' then run
        when 'success' then succeed
        when 'failed' then drop
        when 'canceling' then canceling
        when 'canceled' then cancel
        when 'manual' then block
        when 'scheduled' then delay
        when 'skipped', nil then skip
        else
          raise Ci::HasStatus::UnknownStatusError, "Unknown status `#{new_status}`"
        end
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity

    # This will be removed with ci_remove_ensure_stage_service
    def update_legacy_status
      set_status(latest_stage_status.to_s)
    end

    def groups
      @groups ||= Ci::Group.fabricate(project, self)
    end

    def has_warnings?
      number_of_warnings > 0
    end

    def number_of_warnings
      BatchLoader.for(id).batch(default_value: 0) do |stage_ids, loader|
        ::CommitStatus.where(stage_id: stage_ids)
          .latest
          .failed_but_allowed
          .group(:stage_id)
          .count
          .each { |id, amount| loader.call(id, amount) }
      end
    end

    def detailed_status(current_user)
      Gitlab::Ci::Status::Stage::Factory
        .new(self, current_user)
        .fabricate!
    end

    def manual_playable?
      blocked? || skipped?
    end

    # This will be removed with ci_remove_ensure_stage_service
    def latest_stage_status
      statuses.latest.composite_status || 'skipped'
    end
  end
end
