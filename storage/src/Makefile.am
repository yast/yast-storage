#
# Makefile.am for storage/src
#
# $Id$
#

SUBDIRS = include modules proposal

client_DATA =			\
	inst_custom_part.ycp	\
	inst_disk.ycp		\
	inst_do_resize.ycp	\
	inst_lvm_lv.ycp		\
	inst_lvm_pv.ycp		\
	inst_part_proposal.ycp	\
	inst_prepdisk.ycp	\
	inst_resize_ui.ycp      \
	inst_target_part.ycp	\
	inst_target_selection.ycp 

EXTRA_DIST = $(client_DATA)

partitioning:
	ln -s include partitioning

ycpchook = partitioning

include $(top_srcdir)/Makefile.am.common
