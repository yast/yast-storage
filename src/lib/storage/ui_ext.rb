require "yast"

module Yast
  import "UI"

  module UI
    extend UIShortcuts
    def self.arrange_buttons(buttons)
      # Unfortunately the UI does not provide functionality to rearrange
      # buttons in two or more lines if the available space is
      # limited. This implementation in YCP has several drawbacks, e.g. it
      # does not know anything about the font size, the font metric, the
      # button frame size, the actually available space nor is it run when
      # the dialog is resized. Also see fate #314971.

      display_info = GetDisplayInfo()
      textmode = display_info["TextMode"]
      width = display_info["DefaultWidth"] || 1024

      limited_size = textmode ? 140 : 1280

      max_buttons = 6
      max_buttons = 2 if width <= limited_size

      ret = VBox()

      line = HBox()

      i = 0
      j = 0

      Builtins.foreach(buttons) do |button|
        line.params << Yast.deep_copy(button)
        i += 1
        if [:PushButton, :MenuButton].include? button.value
          j += 1

          if j == max_buttons
            line.params << HStretch() if i != Builtins.size(buttons)

            ret.params << line
            line = HBox()
            j = 0
          end
        end
      end

      ret.params << line
      ret
    end
  end
end
