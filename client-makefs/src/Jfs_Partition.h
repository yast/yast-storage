// -*- c++ -*-

/*
 *  Maintainer: Klaus Kaempf <kkaempf@suse.de>
 */


#ifndef Jfs_Partition_h
#define Jfs_Partition_h


#include "Partition.h"


/**
 * @short Interface to the mkjfs program
 */

class Jfs_Partition : public Partition
{
    
public:
    
    /**
     * Create an new instance.
     */
    Jfs_Partition (string partition_name);
    
    /**
     * Read progress indicator of the mkfs.jfs process.
     */
    bool get_progress_status (double &percent);
    
    /**
     * Run mkfs.jfs with the specified arguments and handle stderr.
     */
    void format (YCPList options,
		 ExternalProgram::Stderr_Disposition stderr_disp =
		 ExternalProgram::Stderr_To_Stdout);
    
};


#endif // Jfs_Partition_h
