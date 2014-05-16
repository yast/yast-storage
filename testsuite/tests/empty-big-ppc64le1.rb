# encoding: utf-8

# testedfiles: helper1b.yh
module Yast
  class Empty1Client < Client

    def main
      Yast.include self, "setup-system.rb"

      setup_system("empty-big-ppc64le")

      Yast.include self, "helper1a.rb"

      Yast.import "ProductFeatures"

      ProductFeatures.SetBooleanFeature("partitioning", "try_separate_home", false)
      ProductFeatures.SetBooleanFeature("partitioning", "proposal_lvm", false)
      ProductFeatures.SetBooleanFeature("partitioning", "proposal_snapshots", false)
      ProductFeatures.SetStringFeature("partitioning", "vm_desired_size", "30 GB")
      ProductFeatures.SetStringFeature("partitioning", "root_base_size", "20 GB")

      Yast.include self, "helper1b.rb"

      nil
    end

  end
end

Yast::Empty1Client.new.main
