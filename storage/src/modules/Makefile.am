#
# Makefile.am for storage/storage/src/modules
#

YCPCFLAGS = -M $(top_builddir)/bindings/ycp

YCPC_LD_LIBRARY_PATH = $(top_builddir)/bindings/src/.libs
YCPC_Y2DIR = $(top_builddir)/bindings/src/.libs

module_DATA =				\
	StorageInit.ycp      		\
	Partitions.ycp			\
	FileSystems.ycp			\
	Storage.ycp			\
	StorageClients.ycp      	\
	StorageControllers.ycp  	\
	StorageDevices.ycp		\
	StorageFields.ycp		\
	StorageIcons.ycp		\
	StorageProposal.ycp		\
	StorageSettings.ycp		\
	StorageUpdate.ycp		\
	TreePanel.ycp			\
	TabPanel.ycp			\
	MiniWorkflow.ycp		\
	Greasemonkey.ycp		\
	DevicesSelectionBox.ycp		\
	DualMultiSelectionBox.ycp	\
	Region.ycp

EXTRA_DIST = $(module_DATA)

include $(top_srcdir)/Makefile.am.common
