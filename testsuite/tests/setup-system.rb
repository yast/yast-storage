# encoding: utf-8

module Yast
  module SetupSystemInclude
    def initialize_setup_system(include_target)

    end

    def setup_system(name)
      SCR.Execute(path(".target.bash"), "mkdir -p tmp")
      SCR.Execute(path(".target.bash"), "rm -rf tmp/*")

      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("cp data/%1/*.info tmp", name)
      )

      nil
    end
  end
end
