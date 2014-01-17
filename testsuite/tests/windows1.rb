# encoding: utf-8

# testedfiles: helper1b.yh
module Yast
  class Windows1Client < Client
    def main
      Yast.include self, "setup-system.rb"

      setup_system("windows")

      Yast.include self, "helper1a.rb"

      Yast.import "ProductFeatures"

      ProductFeatures.SetBooleanFeature("partitioning", "try_separate_home", true)
      ProductFeatures.SetBooleanFeature("partitioning", "proposal_lvm", false)
      ProductFeatures.SetBooleanFeature("partitioning", "proposal_snapshots", false)
      ProductFeatures.SetStringFeature("partitioning", "root_max_size", "20 GB")
      ProductFeatures.SetStringFeature("partitioning", "root_base_size", "15 GB")

      Yast.include self, "helper1b.rb"

      nil
    end
  end
end

Yast::Windows1Client.new.main
