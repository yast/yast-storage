# encoding: utf-8

# Copyright (c) 2012 Novell, Inc.
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

# File:	DualMultiSelectionBox.ycp
# Package:	yast2-storage
# Summary:	Expert Partitioner
# Authors:	Arvin Schnell <aschnell@suse.de>
#
# The items must have the `id() as their first element.
require "yast"

module Yast
  class DualMultiSelectionBoxClass < Module
    def main
      Yast.import "UI"

      Yast.import "Label"
      Yast.import "Event"
      Yast.import "Popup"
      Yast.import "Storage"

      textdomain "storage"


      @items = []

      @selected = []
      @item_map = {}
      @classified = {}
      @keep_order = false
    end

    def GetUnselectedItems
      Builtins.filter(@items) do |item|
        id = Ops.get(item, [0, 0])
        !Builtins.contains(@selected, id)
      end
    end


    def GetSelectedItems
      Builtins.y2milestone("selected:%1", @selected)
      if @keep_order
        return Builtins.maplist(@selected) do |id|
          Ops.get(@item_map, id, Empty())
        end
      else
        return Builtins.filter(@items) do |item|
          id = Ops.get(item, [0, 0])
          Builtins.contains(@selected, id)
        end
      end
    end



    def Create(header, new_items, new_selected, unselected_label, selected_label, unselected_rp, selected_rp, can_change_order)
      header = deep_copy(header)
      new_items = deep_copy(new_items)
      new_selected = deep_copy(new_selected)
      unselected_rp = deep_copy(unselected_rp)
      selected_rp = deep_copy(selected_rp)
      @items = deep_copy(new_items)
      @selected = deep_copy(new_selected)
      @item_map = Builtins.listmap(new_items) do |item|
        { Ops.get_string(item, [0, 0], "") => item }
      end
      @keep_order = can_change_order
      sel_header = deep_copy(header)
      if can_change_order
        sel_header = Builtins.add(sel_header, Center(_("Class")))
      end
      sel_term = Table(
        Id(:selected),
        Opt(:keepSorting, :multiSelection, :notify),
        sel_header,
        GetSelectedItems()
      )
      if can_change_order
        order_buttons = VBox(
          PushButton(Id(:top), _("Top")),
          VSpacing(0.5),
          PushButton(Id(:up), _("Up")),
          VSpacing(0.5),
          PushButton(Id(:down), _("Down")),
          VSpacing(0.5),
          PushButton(Id(:bottom), _("Bottom")),
          VSpacing(1.5),
          PushButton(Id(:classify), _("Classify"))
        )
        sel_term = HBox(sel_term, order_buttons)
      end
      HBox(
        HWeight(
          1,
          VBox(
            Left(Label(unselected_label)),
            Table(
              Id(:unselected),
              Opt(:keepSorting, :multiSelection, :notify),
              header,
              GetUnselectedItems()
            ),
            ReplacePoint(Id(:unselected_rp), unselected_rp)
          )
        ),
        MarginBox(
          1,
          1,
          HSquash(
            VBox(
              # push button text
              PushButton(
                Id(:add),
                Opt(:hstretch),
                Ops.add(_("Add") + " ", UI.Glyph(:ArrowRight))
              ),
              # push button text
              PushButton(
                Id(:add_all),
                Opt(:hstretch),
                Ops.add(_("Add All") + " ", UI.Glyph(:ArrowRight))
              ),
              VSpacing(1),
              # push button text
              PushButton(
                Id(:remove),
                Opt(:hstretch),
                Ops.add(Ops.add(UI.Glyph(:ArrowLeft), " "), _("Remove"))
              ),
              # push button text
              PushButton(
                Id(:remove_all),
                Opt(:hstretch),
                Ops.add(Ops.add(UI.Glyph(:ArrowLeft), " "), _("Remove All"))
              )
            )
          )
        ),
        HWeight(
          1,
          VBox(
            Left(Label(selected_label)),
            sel_term,
            ReplacePoint(Id(:selected_rp), selected_rp)
          )
        )
      )
    end


    def GetSelected
      deep_copy(@selected)
    end

    def ScanPatternFile(fname)
      ret = []
      txt = ""
      Builtins.y2milestone("ScanPatternFile fname:%1", fname)
      d = Convert.to_map(SCR.Read(path(".target.stat"), fname))
      Builtins.y2milestone("ScanPatternFile stat:%1", d)
      ok = true
      if !Ops.get_boolean(d, "isreg", false)
        # error popup text
        txt = Builtins.sformat(_("File %1 is not a regular file!"), fname)
        Popup.Error(txt)
        ok = false
      elsif Ops.greater_than(Ops.get_integer(d, "size", 0), 1024 * 1024)
        # error popup text
        txt = Builtins.sformat(_("File %1 is too big!"), fname)
        Popup.Error(txt)
        ok = false
      end
      sl = []
      fl = []
      if ok
        bo = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), Ops.add("cat ", fname))
        )
        sl = Builtins.filter(
          Builtins.splitstring(Ops.get_string(bo, "stdout", ""), "\n")
        ) { |s| !Builtins.isempty(s) }
        fl = Builtins.filter(Builtins.splitstring(Ops.get(sl, 0, ""), " \t")) do |s|
          !Builtins.isempty(s)
        end
        Builtins.y2milestone(
          "ScanPatternFile fline:%1 size:%2",
          fl,
          Builtins.size(fl)
        )
        if Builtins.isempty(sl) || Builtins.size(fl) != 2 ||
            Builtins.size(Ops.get(fl, 1, "")) != 1
          # error popup text
          txt = _(
            "Pattern file has invalid format!\n" +
              "\n" +
              "The file needs to contain lines with a regular expression and a class name\n" +
              "per line. Example:"
          )
          txt = Ops.add(txt, "\nsda.* A\nsdb.* B")
          Popup.Error(txt)
          ok = false
        end
      end
      if ok
        Builtins.foreach(sl) do |s|
          fl = Builtins.filter(Builtins.splitstring(s, " \t")) do |f|
            !Builtins.isempty(f)
          end
          if !Builtins.isempty(Ops.get(fl, 0, "")) &&
              Builtins.size(Ops.get(fl, 1, "")) == 1
            ret = Builtins.add(
              ret,
              [Ops.get(fl, 0, ""), Builtins.toupper(Ops.get(fl, 1, ""))]
            )
          end
        end
        # popup text
        txt = _("Detected following pattern lines:") + "\n"
        Builtins.foreach(ret) do |l|
          txt = Ops.add(
            Ops.add(
              Ops.add(Ops.add(txt, "\n"), Ops.get_string(l, 0, "")),
              " : "
            ),
            Ops.get_string(l, 1, "")
          )
        end
        txt = Ops.add(txt, "\n\n")
        txt = Ops.add(
          txt,
          _("Ok to match devices to classes with these patterns?")
        )
        ok = Popup.YesNo(txt)
        ret = [] if !ok
      end
      Builtins.y2milestone("ScanPatternFile ret:%1", ret)
      deep_copy(ret)
    end

    def FindDeviceMatches(dc, plst)
      plst = deep_copy(plst)
      tg = Storage.GetTargetMap
      dc.value = Builtins.mapmap(dc.value) do |d, c|
        p = Storage.GetPartition(tg, d)
        Builtins.y2milestone("FindDeviceMatches %1 is %2", d, p)
        match = Builtins.find(plst) do |m|
          found = Builtins.regexpmatch(d, Ops.get_string(m, 0, ""))
          if !found
            found = Builtins.regexpmatch(
              Ops.get_string(p, "device", ""),
              Ops.get_string(m, 0, "")
            )
          end
          if !found
            id = Builtins.find(Ops.get_list(p, "udev_id", [])) do |s|
              Builtins.regexpmatch(
                Ops.add("/dev/disk/by-id/", s),
                Ops.get_string(m, 0, "")
              )
            end
            found = id != nil
          end
          if !found
            found = Builtins.regexpmatch(
              Ops.add("/dev/disk/by-path/", Ops.get_string(p, "udev_path", "")),
              Ops.get_string(m, 0, "")
            )
          end
          found
        end
        Builtins.y2milestone("FindDeviceMatches match %1 is %2", d, match)
        c = Ops.get_string(match, 1, "") if match != nil
        { d => c }
      end

      nil
    end

    def ClassifyPopup(selected)
      selected = deep_copy(selected)
      # button text
      txt_sort = "Sorted"
      # button text
      txt_inter = "Interleaved"
      # button text
      txt_pat = "Pattern File"
      _SymToLetter = lambda do |sym|
        lbl = Builtins.tostring(sym)
        Builtins.substring(lbl, Ops.subtract(Builtins.size(lbl), 1))
      end
      _SymToLabel = lambda do |sym, hint|
        # button text
        Ops.add(_("Class") + (hint ? " &" : ""), _SymToLetter.call(sym))
      end
      _ClassifyHelpText = lambda do
        # dialog help text
        txt = _(
          "<p>This dialog is for defining classes for the raid devices\n" +
            "contained in the raid. Available classes are A, B, C, D and E but for many cases\n" +
            "fewer classes are needed (e.g. only A and B). </p>"
        )
        # dialog help text
        txt = Ops.add(
          txt,
          Builtins.sformat(
            _(
              "<p>You can put a device into a class by right-clicking on the\n" +
                "device and choosing the appropriate class from context menu. By pressing the \n" +
                "Ctrl  or Shift key you can select multiple devices and put them into a class in\n" +
                "one step. One can also use the buttons labeled \"%1\" to \"%2\" to put currently \n" +
                "selected devices into this class.</p>"
            ),
            _SymToLabel.call(:class_A, false),
            _SymToLabel.call(:class_E, false)
          )
        )
        # dialog help text
        txt = Ops.add(
          txt,
          Builtins.sformat(
            _(
              "<p>After choosing classes for devices you can order the \ndevices by pressing one of the buttons labeled \"%1\" or \"%2\"."
            ),
            txt_sort,
            txt_inter
          )
        )
        txt = Ops.add(txt, " ")
        # dialog help text
        txt = Ops.add(
          txt,
          _(
            "<b>Sorted</b> puts all devices of class A before all devices\nof class B and so on."
          )
        )
        txt = Ops.add(txt, " ")
        # dialog help text
        txt = Ops.add(
          txt,
          _(
            "<b>Interleaved</b> uses first device of class A, then first device of \n" +
              "class B, then all the following classes with assigned devices. Then the \n" +
              "second device of class A, the second device of class B, and so on will follow."
          )
        )
        txt = Ops.add(txt, " ")
        # dialog help text
        txt = Ops.add(
          txt,
          _(
            "All devices without a class are sorted to the end of devices list.\n" +
              "When you leave the pop-up the current order of the devices is used as the \n" +
              "order in the RAID to be created.</p>"
          )
        )
        # dialog help text
        txt = Ops.add(
          txt,
          Builtins.sformat(
            _(
              "By pressing button \"<b>%1</b>\" you can select a file that contains\n" +
                "lines with a regular expression and a class name (e.g. \"sda.*  A\"). All devices that match \n" +
                "the regular expression will be put into the class on this line. The regular expression is \n" +
                "matched against the kernel name (e.g. /dev/sda1), \n" +
                "the udev path name (e.g. /dev/disk/by-path/pci-0000:00:1f.2-scsi-0:0:0:0-part1) and the\n" +
                "the udev id (e.g. /dev/disk/by-id/ata-ST3500418AS_9VMN8X8L-part1). \n" +
                "The first match finally determines the class if a devices name matches more then one\n" +
                "regular expression.</p>"
            ),
            txt_pat
          )
        )
        txt
      end

      if Builtins.isempty(@classified)
        @classified = Builtins.listmap(
          Convert.convert(selected, :from => "list", :to => "list <string>")
        ) { |s| { s => "" } }
      end
      Builtins.y2milestone("ClassifyPopup select:%1", selected)
      Builtins.y2milestone("ClassifyPopup classified:%1", @classified)
      itl = Builtins.maplist(
        Convert.convert(selected, :from => "list", :to => "list <string>")
      ) { |s| Item(Id(s), s, Ops.get(@classified, s, "")) }
      Builtins.y2milestone("ClassifyPopup items:%1", itl)
      classes = [:class_A, :class_B, :class_C, :class_D, :class_E]
      cb = HBox()
      Builtins.foreach(classes) do |s|
        lbl = Builtins.tostring(s)
        lbl = Builtins.substring(lbl, Ops.subtract(Builtins.size(lbl), 1))
        cb = Builtins.add(cb, PushButton(Id(s), _SymToLabel.call(s, true)))
      end
      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          MinHeight(
            15,
            Table(
              Id(:classtab),
              Opt(
                :keepSorting,
                :immediate,
                :notify,
                :multiSelection,
                :notifyContextMenu
              ),
              # headline text
              Header(_("Device"), Center(_("Class"))),
              itl
            )
          ),
          cb,
          HBox(
            PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
            PushButton(Id(:sorted), Ops.add(txt_sort, " (AAABBBCCC)")),
            PushButton(Id(:interleaved), Ops.add(txt_inter, " (ABCABCABC)")),
            PushButton(Id(:pattern), txt_pat)
          ),
          VSpacing(0.5),
          ButtonBox(
            PushButton(Id(:cancel), Opt(:cancelButton), Label.CancelButton),
            PushButton(Id(:ok), Opt(:okButton), Label.OKButton)
          )
        )
      )
      UI.ChangeWidget(:help, :HelpText, _ClassifyHelpText.call)
      ret = nil
      ctx = Builtins.maplist(classes) do |s|
        Item(Id(s), _SymToLabel.call(s, false))
      end
      begin
        ev = UI.WaitForEvent
        ret = Event.IsWidgetActivatedOrSelectionChanged(ev)
        ret = Event.IsWidgetValueChanged(ev) if ret == nil
        ret = Event.IsWidgetContextMenuActivated(ev) if ret == nil
        Builtins.y2milestone("ClassifyPopup event:%1 ret:%2", ev, ret)
        if ret == :classtab
          if Event.IsWidgetContextMenuActivated(ev) != nil
            UI.OpenContextMenu(term(:menu, ctx))
            value = UI.UserInput
            ret = Convert.to_symbol(value) if Convert.to_symbol(value) != nil
            Builtins.y2milestone("ClassifyPopup value:%1", value)
          end
        end
        if Builtins.contains(classes, ret)
          ls = Convert.convert(
            UI.QueryWidget(Id(:classtab), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          )
          Builtins.y2milestone("ClassifyPopup ls:%1", ls)
          let = _SymToLetter.call(ret)
          Builtins.y2milestone("ClassifyPopup class:%1", let)
          itl = Convert.convert(
            UI.QueryWidget(Id(:classtab), :Items),
            :from => "any",
            :to   => "list <term>"
          )
          itl = Builtins.maplist(itl) do |t|
            if Builtins.contains(ls, Ops.get_string(t, 1, ""))
              Ops.set(t, 2, let)
            end
            deep_copy(t)
          end
          UI.ChangeWidget(Id(:classtab), :Items, itl)
          UI.ChangeWidget(Id(:classtab), :SelectedItems, ls)
        elsif ret == :interleaved
          itl = Convert.convert(
            UI.QueryWidget(Id(:classtab), :Items),
            :from => "any",
            :to   => "list <term>"
          )
          ll = Builtins.filter(itl) do |a|
            Ops.less_than(Ops.get_string(a, 2, ""), "A")
          end
          itl = Builtins.filter(itl) do |a|
            Ops.greater_or_equal(Ops.get_string(a, 2, ""), "A")
          end
          sl = []
          tll = []
          cidx = 0
          while Ops.less_than(cidx, Builtins.size(classes))
            let = _SymToLetter.call(Ops.get(classes, cidx, :none))
            sl = Builtins.filter(itl) { |t| Ops.get_string(t, 2, "") == let }
            tll = Builtins.add(tll, sl) if !Builtins.isempty(sl)
            cidx = Ops.add(cidx, 1)
          end
          sl = []
          mpty = Item(Id(0), "-")
          while !Builtins.isempty(tll)
            cidx = 0
            while Ops.less_than(cidx, Builtins.size(tll))
              sl = Builtins.add(sl, Ops.get(tll, [cidx, 0], mpty))
              Ops.set(tll, cidx, Builtins.remove(Ops.get(tll, cidx, []), 0))
              if !Builtins.isempty(Ops.get(tll, cidx, []))
                cidx = Ops.add(cidx, 1)
              else
                tll = Builtins.remove(tll, cidx)
              end
            end
          end
          itl = Convert.convert(
            Builtins.union(sl, ll),
            :from => "list",
            :to   => "list <term>"
          )
          UI.ChangeWidget(Id(:classtab), :Items, itl)
        elsif ret == :sorted
          itl = Convert.convert(
            UI.QueryWidget(Id(:classtab), :Items),
            :from => "any",
            :to   => "list <term>"
          )
          ll = Builtins.filter(itl) do |a|
            Ops.less_than(Ops.get_string(a, 2, ""), "A")
          end
          itl = Builtins.sort(Builtins.filter(itl) do |t|
            Ops.greater_or_equal(Ops.get_string(t, 2, ""), "A")
          end) do |a, b|
            Ops.less_than(Ops.get_string(a, 2, " "), Ops.get_string(b, 2, " "))
          end
          itl = Convert.convert(
            Builtins.union(itl, ll),
            :from => "list",
            :to   => "list <term>"
          )
          UI.ChangeWidget(Id(:classtab), :Items, itl)
        elsif ret == :pattern
          # headline text
          fname = UI.AskForExistingFile(".", "", _("Pattern File"))
          Builtins.y2milestone("ClassifyPopup file:%1", fname)
          plst = []
          plst = ScanPatternFile(fname) if fname != nil
          if !Builtins.isempty(plst)
            itl = Convert.convert(
              UI.QueryWidget(Id(:classtab), :Items),
              :from => "any",
              :to   => "list <term>"
            )
            dc = {}
            dc = Builtins.listmap(itl) { |t| { Ops.get_string(t, 1, "") => "" } }
            Builtins.y2milestone("ClassifyPopup dc:%1", dc)
            dc_ref = arg_ref(dc)
            FindDeviceMatches(dc_ref, plst)
            dc = dc_ref.value
            Builtins.y2milestone("ClassifyPopup dc:%1", dc)
            itl = Builtins.maplist(itl) do |t|
              Ops.set(t, 2, Ops.get(dc, Ops.get_string(t, 1, ""), ""))
              deep_copy(t)
            end
            UI.ChangeWidget(Id(:classtab), :Items, itl)
          end
        end
      end while !Builtins.contains([:ok, :cancel], ret)
      if ret == :cancel
        selected = nil
      else
        itl = Convert.convert(
          UI.QueryWidget(Id(:classtab), :Items),
          :from => "any",
          :to   => "list <term>"
        )
        selected = Builtins.maplist(itl) { |t| Ops.get_string(t, 1, "") }
        Builtins.foreach(itl) do |t|
          Ops.set(
            @classified,
            Ops.get_string(t, 1, ""),
            Ops.get_string(t, 2, "")
          )
        end
        Builtins.y2milestone("ClassifyPopup classified:%1", @classified)
      end
      UI.CloseDialog
      Builtins.y2milestone("ClassifyPopup return:%1", selected)
      deep_copy(selected)
    end


    def reverse(v)
      v = deep_copy(v)
      siz = Builtins.size(v)
      i = 0
      while Ops.less_than(i, Ops.divide(siz, 2))
        v = Builtins::List.swap(v, i, Ops.subtract(Ops.subtract(siz, 1), i))
        i = Ops.add(i, 1)
      end
      deep_copy(v)
    end

    def Handle(widget)
      sel = []
      case widget
        when :add, :unselected
          tmp1 = Convert.to_list(
            UI.QueryWidget(Id(:unselected), :SelectedItems)
          )
          @selected = Builtins.flatten([@selected, tmp1])
          sel = Convert.convert(
            UI.QueryWidget(Id(:selected), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          )
          Builtins.y2milestone("selected:%1", @selected)
        when :remove, :selected
          tmp1 = Convert.to_list(UI.QueryWidget(Id(:selected), :SelectedItems))
          @selected = Builtins.filter(@selected) do |tmp2|
            !Builtins.contains(tmp1, tmp2)
          end
          sel = Convert.convert(
            UI.QueryWidget(Id(:selected), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          )
          sel = Convert.convert(
            Builtins.filter(sel) { |tmp2| !Builtins.contains(tmp1, tmp2) },
            :from => "list",
            :to   => "list <string>"
          )
          Builtins.y2milestone("selected:%1", @selected)
        when :add_all
          tmp1 = Builtins.maplist(@items) do |item|
            id = Ops.get(item, [0, 0])
            deep_copy(id)
          end
          tmp1 = Builtins.filter(
            Convert.convert(tmp1, :from => "list", :to => "list <string>")
          ) { |s| !Builtins.contains(@selected, s) }
          @selected = Builtins.merge(@selected, tmp1)
          sel = Convert.convert(
            UI.QueryWidget(Id(:selected), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          )
          Builtins.y2milestone("selected:%1", @selected)
        when :remove_all
          @selected = []
          @classified = {}
          @items = Builtins.maplist(@items) do |t|
            Ops.set(t, 5, "")
            Ops.set(@item_map, Ops.get_string(t, 1, ""), t)
            deep_copy(t)
          end
          Builtins.y2milestone("selected:%1", @selected)
        when :classify
          Builtins.y2milestone("selected:%1", @selected)
          l = ClassifyPopup(@selected)
          if l != nil
            @selected = deep_copy(l)
            Builtins.y2milestone("selected:%1", @selected)
            @items = Builtins.maplist(@items) do |t|
              Ops.set(t, 5, Ops.get(@classified, Ops.get_string(t, 1, ""), ""))
              Ops.set(@item_map, Ops.get_string(t, 1, ""), t)
              deep_copy(t)
            end
          end
        when :down, :up
          up = widget == :up
          sel = Convert.convert(
            UI.QueryWidget(Id(:selected), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          )
          cnt = -1
          siz = Ops.subtract(Builtins.size(@selected), 1)
          sm = Builtins.listmap(
            Convert.convert(@selected, :from => "list", :to => "list <string>")
          ) do |s|
            cnt = Ops.add(cnt, 1)
            { s => cnt }
          end
          cnt = 0
          diff = up ? -1 : 1
          sel = reverse(sel) if !up
          Builtins.foreach(sel) do |s|
            idx = Ops.get(sm, s, 0)
            if up && Ops.greater_than(idx, cnt) ||
                !up && Ops.less_than(idx, Ops.subtract(siz, cnt))
              @selected = Builtins::List.swap(
                @selected,
                Ops.add(idx, diff),
                idx
              )
            end
            cnt = Ops.add(cnt, 1)
          end
          Builtins.y2milestone("change:%1 selected:%2", sel, @selected)
        when :bottom, :top
          up = widget == :top
          sel = Convert.convert(
            UI.QueryWidget(Id(:selected), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          )
          @selected = Builtins.filter(
            Convert.convert(@selected, :from => "list", :to => "list <string>")
          ) { |s| !Builtins.contains(sel, s) }
          if up
            @selected = Builtins.merge(sel, @selected)
          else
            @selected = Builtins.merge(@selected, sel)
          end
          Builtins.y2milestone("change:%1 selected:%2", sel, @selected)
      end

      if Builtins.contains(
          [
            :unselected,
            :selected,
            :add,
            :add_all,
            :remove,
            :remove_all,
            :up,
            :down,
            :top,
            :bottom,
            :classify
          ],
          widget
        )
        UI.ChangeWidget(Id(:unselected), :Items, GetUnselectedItems())
        UI.ChangeWidget(Id(:selected), :Items, GetSelectedItems())
        UI.ChangeWidget(Id(:selected), :SelectedItems, sel)
      end

      nil
    end

    publish :function => :Create, :type => "term (term, list <term>, list, string, string, term, term, boolean)"
    publish :function => :GetSelected, :type => "list ()"
    publish :function => :Handle, :type => "void (symbol)"
  end

  DualMultiSelectionBox = DualMultiSelectionBoxClass.new
  DualMultiSelectionBox.main
end
