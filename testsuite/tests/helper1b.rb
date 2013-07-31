# encoding: utf-8

module Yast
  module Helper1bInclude
    def initialize_helper1b(include_target)
      Yast.import "Storage"
      Yast.import "StorageProposal"
      Yast.import "Testsuite"

      Storage.InitLibstorage(false)

      StorageProposal.GetControlCfg

      @target_map = Storage.GetTargetMap
      @prop = StorageProposal.get_inst_prop(@target_map)

      if Ops.get_boolean(@prop, "ok", false)
        Storage.SetTargetMap(Ops.get_map(@prop, "target", {}))

        @infos = Storage.GetCommitInfos

        Testsuite.Dump("Proposal:")
        Builtins.foreach(@infos) do |info|
          text = Ops.get_string(info, :text, "")
          if Ops.get_boolean(info, :destructive, false)
            text = Ops.add(text, " [destructive]")
          end
          Testsuite.Dump(text)
        end
      else
        Testsuite.Dump("No proposal.")
      end

      Storage.FinishLibstorage
    end
  end
end
