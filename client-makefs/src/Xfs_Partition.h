// -*- c++ -*-

/*
 *  Maintainer: Klaus Kaempf <kkaempf@suse.de>
 */


#ifndef Xfs_Partition_h
#define Xfs_Partition_h


#include "Partition.h"


/**
 * @short Interface to the mkxfs program
 */

class Xfs_Partition : public Partition
{

public:

    /**
     * Create an new instance.
     */
    Xfs_Partition (string partition_name);

    /**
     * Read progress indicator of the mkfs.xfs process.
     */
    bool get_progress_status (double &percent);

    /**
     * Run mkfs.xfs with the specified arguments and handle stderr.
     */
    void format (YCPList options,
		 ExternalProgram::Stderr_Disposition stderr_disp =
		 ExternalProgram::Stderr_To_Stdout);

};


#endif // Xfs_Partition_h
