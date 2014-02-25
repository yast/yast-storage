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

        Testsuite.Dump("Extra Data:")
        prop["target"].each do |device, container|
          container["partitions"].each do |volume|
            if !volume.fetch("userdata", {}).empty?
              Testsuite.Dump("device:#{volume["device"]} userdata:#{volume["userdata"]}")
            end
          end
        end

      else
        Testsuite.Dump("No proposal.")
      end

      Storage.FinishLibstorage
    end

  end
end
