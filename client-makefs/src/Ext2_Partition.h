// -*- c++ -*-

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#ifndef Ext2_Partition_h
#define Ext2_Partition_h


#include "Partition.h"


/**
 * @short Interface to the mke2fs program
 */

class Ext2_Partition : public Partition
{
    
public:
    
    /**
     * Create an new instance.
     */
    Ext2_Partition (string partition_name);
    
    /**
     * Read progress indicator of the mke2fs process.
     */
    bool get_progress_status (double &percent);
    
    /**
     * Run mke2fs with the specified arguments and handle stderr.
     */
    void format (YCPList options,
		 ExternalProgram::Stderr_Disposition stderr_disp =
		 ExternalProgram::Stderr_To_Stdout);
    
};


#endif // Ext2_Partition_h
