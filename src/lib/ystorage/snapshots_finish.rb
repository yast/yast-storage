require "yast2/fs_snapshot"
require "installation/finish_client"

module Yast
  # This module exists to avoid polluting the Yast namespace. Moreover,
  # Yast::Storage exists yet so a new name was chosen.
  module YStorage
    class SnapshotsFinish < ::Installation::FinishClient
      include Yast::I18n

      def initialize
        textdomain "storage"

        Yast.import "Mode"
        Yast.import "StorageSnapper"
        Yast.include self, "installation/misc.rb"
      end

      # Write configuration
      #
      # It creates a snapshot when no second stage is required and
      # Snapper is configured.
      #
      # @return [TrueClass,FalseClass] True if snapshot was created;
      #                                otherwise it returns false.
      def write
        if !second_stage_required? && Yast2::FsSnapshot.configured?
          log.info("Creating root filesystem snapshot")
          action = Mode.update ? "upgrade" : "installation"
          create_snapshot("after #{action}")
        else
          log.info("Skipping root filesystem snapshot creation")
          false
        end
      end

      def title
        _("Creating root filesystem snapshot...")
      end

      private

      def create_snapshot(description)
        Yast2::FsSnapshot.create_single(description)
        true
      rescue Yast2::PreviousSnapshotNotFound, Yast2::SnapshotCreationFailed => e
        log.error("Filesystem snapshot not created: #{e.message}")
        false
      end
    end
  end
end
