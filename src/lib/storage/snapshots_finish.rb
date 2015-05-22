require "yast2/fs_snapshot"
require "installation/finish_client"

module Storage
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
      if !second_stage_required? && StorageSnapper.configure_snapper?
        log.info("Creating root filesystem snapshot")
        action = Mode.update ? "upgrade" : "installation"
        create_snapshot(:single, "after #{action}")
      else
        log.info("Skipping root filesystem snapshot creation")
        false
      end
    end

    def title
      _("Creating root filesystem snapshot...")
    end

    private

    def create_snapshot(snapshot_type, description)
      Yast2::FsSnapshot.create_single(description)
      true
    rescue Yast2::SnapperNotConfigured, Yast2::PreviousSnapshotNotFound, Yast2::SnapshotCreationFailed
      log.error("Filesystem snapshot could not be created.")
      false
    end
  end
end
