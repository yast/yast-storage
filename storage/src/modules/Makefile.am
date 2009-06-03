#
# Makefile.am for storage/storage/src/modules
#

YCPCFLAGS = -M ../../../bindings/ycp

YCPC_LD_LIBRARY_PATH = ../../../bindings/src/.libs
YCPC_Y2DIR = ../../../bindings/src/.libs

module_DATA =				\
	Partitions.ycp			\
	FileSystems.ycp			\
	Storage.ycp			\
	StorageClients.ycp      	\
	StorageControllers.ycp  	\
	StorageDevices.ycp		\
	StorageFields.ycp		\
	StorageProposal.ycp		\
	StorageSettings.ycp		\
	StorageIcons.ycp		\
	TreePanel.ycp			\
	TabPanel.ycp			\
	MiniWorkflow.ycp		\
	Greasemonkey.ycp		\
	DevicesSelectionBox.ycp		\
	DualMultiSelectionBox.ycp	\
	Region.ycp

EXTRA_DIST = $(module_DATA)

include $(top_srcdir)/Makefile.am.common
