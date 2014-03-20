# encoding: utf-8

module Yast
  module Helper1bInclude

    def initialize_helper1b(include_target)
      Yast.import "Storage"
      Yast.import "StorageProposal"
      Yast.import "Testsuite"

      Storage.InitLibstorage(false)

      StorageProposal.GetControlCfg

      target_map = Storage.GetTargetMap()
      prop = StorageProposal.get_inst_prop(target_map)

      if prop.fetch("ok", false)
        Storage.SetTargetMap(prop.fetch("target", {}))

        infos = Storage.GetCommitInfos

        Testsuite.Dump("Proposal:")
        infos.each do |info|
          text = info.fetch(:text, "")
          if info.fetch(:destructive, false)
            text += " [destructive]"
          end
          Testsuite.Dump(text)
        end

        Testsuite.Dump("")

        Testsuite.Dump("Target Map Excerpt:")
        prop["target"].each do |device, container|

          if Storage.IsDiskType(container.fetch("type", :CT_UNKNOWN))

            line = "device:#{container["device"]}"

            if container.fetch("label", "") != ""
              line << " label:#{container["label"]}"
            end

            Testsuite.Dump(line)

          end

          container["partitions"].each do |volume|

            line = "device:#{volume["device"]}"

            if volume.fetch("fsid", 0) != 0
              line << " fsid:0x#{volume["fsid"].to_s(16)}"
            end

            if !volume.fetch("userdata", {}).empty?
              line << " userdata:#{volume["userdata"]}"
            end

            Testsuite.Dump(line)

          end

        end

      else
        Testsuite.Dump("No proposal.")
      end

      Storage.FinishLibstorage
    end

  end
end
