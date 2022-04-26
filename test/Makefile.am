#
# Makefile.am for storage/test
#

TESTS = \
	format_target_map_test.rb					 \
	filesystems_test.rb						 \
	storage_snapper_configure_snapper_test.rb			 \
	storage_get_disk_partition_test.rb				 \
	storage_boot_on_raid1_test.rb 					 \
	partitions_test.rb 						 \
	include/partitioning_custom_part_check_generated_include_test.rb \
	include/ep-lvm-lib_test.rb 					 \
	subvol_test.rb 							 \
        ro_text_test.rb

TEST_EXTENSIONS = .rb
RB_LOG_COMPILER = rspec
VERBOSE = 1
EXTRA_DIST = $(TESTS)

