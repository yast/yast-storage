// -*- C++ -*-

#ifndef WIN_Partition_h
#define WIN_Partition_h

#include <YCP.h>
#include <y2/ExternalProgram.h>

/**
 * @short Interface to the parted program
 */

class WIN_Partition
{
public:
   /**
    * Create an new instance.
    */
   WIN_Partition( string partition_name );

   /**
    * Clean up.
    */
   ~WIN_Partition();

   /**
    * Return the exit status of the parted process, closing the connection if
    * not already done.
    */
   int status();

   /**
    * Forcably kill the parted process.
    * This _MUST_NOT_ be done during resize because killing the resize
    * process leaves a corrupted FAT partition behind.
    * (commented out but left in for information)
    */
   // void kill_resize();

   /**
    * Read progress indication of the parted process.
    */
   bool get_progress_status( string &message_progress,
			     string &message_directory,
			     string &message_exception );

   /**
    * Run parted with the specified arguments and route stderr to stdout.
    */
   void resize( string partition_start,
		string partition_length,
		ExternalProgram::Stderr_Disposition stderr_disp =
		ExternalProgram::Stderr_To_Stdout );

private:

   /**
    * The full name of the partition e.g. /dev/sda1
    */
   string partition;

   /**
    * The device of the partition e.g. /dev/sda
    */
   string partition_device;

   /**
    * The minor number of the partition e.g. 1
    */
   string partition_minor;

   /**
    * New start of partition in MB on device (as provided by caller)
    */
   string partition_start;

   /**
    * New end of partition in MB on device (will be calculated)
    */
   string partition_end;
   

   /**
    * The connection to the parted process.
    */
   ExternalProgram *process;

   /**
    * The exit code of the parted process, or -1 if not yet known.
    */
   int exit_code;
};

#endif
