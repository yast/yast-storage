// -*- c++ -*-

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#ifndef Reiser_Partition_h
#define Reiser_Partition_h


#include "Partition.h"


/**
 * @short Interface to the mkreiserfs program
 */

class Reiser_Partition : public Partition
{
    
public:
    
    /**
     * Create an new instance.
     */
    Reiser_Partition (string partition_name);
    
    /**
     * Read progress indicator of the mkreiserfs process.
     */
    bool get_progress_status (double &percent);
    
    /**
     * Run mkreiserfs with the specified arguments and handle stderr.
     */
    void format (YCPList options,
		 ExternalProgram::Stderr_Disposition stderr_disp =
		 ExternalProgram::Stderr_To_Stdout);
    
};

#endif // Reiser_Partition_h
