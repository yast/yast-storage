#
# Makefile.am for storage/storage/src
#

SUBDIRS = include modules proposal testsuite

client_DATA =				\
	inst_custom_part.ycp		\
	inst_disk.ycp			\
	inst_disk_proposal.ycp		\
	inst_prepdisk.ycp		\
	inst_resize_ui.ycp		\
	inst_resize_dialog.ycp		\
	inst_target_part.ycp		\
	inst_target_selection.ycp	\
	storage_finish.ycp

EXTRA_DIST = $(client_DATA)

partitioning:
	ln -s include partitioning

ycpchook = partitioning

include $(top_srcdir)/Makefile.am.common
