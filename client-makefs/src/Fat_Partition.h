// -*- c++ -*-

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#ifndef Fat_Partition_h
#define Fat_Partition_h


#include "Partition.h"


/**
 * @short Interface to the mkdosfs program
 */

class Fat_Partition : public Partition
{
    bool Fat32;
    
public:
    
    /**
     * Create an new instance.
     */
    Fat_Partition (string partition_name, bool as_fat32);
    
    /**
     * Run mkdosfs with the specified arguments and handle stderr.
     */
    void format (YCPList options,
		 ExternalProgram::Stderr_Disposition stderr_disp =
		 ExternalProgram::Stderr_To_Stdout);
    
};


#endif // Fat_Partition_h
