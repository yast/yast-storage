#
# Makefile.am for storage/storage/src/modules
#

YCPCFLAGS = -M ../../../libstorage/bindings/ycp

YCPC_LD_LIBRARY_PATH = ../../../libstorage/src/.libs
YCPC_Y2DIR = ../../../libstorage/src/.libs

module_DATA =				\
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
