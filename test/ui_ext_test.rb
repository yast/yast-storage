#! /usr/bin/env ruby
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "minitest/autorun"
require "yast"
require "storage/ui_ext"

describe Yast::UI do
  describe "when call arrange_buttons" do
    include Yast::UIShortcuts

    describe "when call in textmode with limited width" do

      before do
        @display_info_params = {
          "TextMode"      => true,
          "DefaultWidth"  => 64
        }
      end

      it "place on one line if it fits there" do
        buttons = Array.new(2) { PushButton() }

        expected_result = VBox(HBox(*buttons))

        Yast::UI.stub :GetDisplayInfo, @display_info_params do
          Yast::UI.arrange_buttons(buttons).must_equal expected_result
        end
      end

      it "place on more lines if it is bigger" do
        buttons = Array.new(7) { PushButton() }

        lines = Array.new(3) { HBox(PushButton(), PushButton(), HStretch()) }
        lines << HBox(PushButton())
        expected_result = VBox(*lines)

        Yast::UI.stub :GetDisplayInfo, @display_info_params do
          Yast::UI.arrange_buttons(buttons).must_equal expected_result
        end
      end
    end

    describe "when call in textmode with enough width" do

      before do
        @display_info_params = {
          "TextMode"      => true,
          "DefaultWidth"  => 160
        }
      end

      it "place on one line if it fits there" do
        buttons = Array.new(3) { PushButton() }

        expected_result = VBox(HBox(*buttons))

        Yast::UI.stub :GetDisplayInfo, @display_info_params do
          Yast::UI.arrange_buttons(buttons).must_equal expected_result
        end
      end

      it "place on more lines if it is bigger" do
        buttons = Array.new(7) { PushButton() }

        push_buttons = Array.new(6) { PushButton() }
        lines = [HBox(*push_buttons, HStretch()) ]
        lines << HBox(PushButton())
        expected_result = VBox(*lines)

        Yast::UI.stub :GetDisplayInfo, @display_info_params do
          Yast::UI.arrange_buttons(buttons).must_equal expected_result
        end
      end
    end
  end
end
