// -*- c++ -*-

/*
 *  Author:	Arvin Schnell <arvin@suse.de>
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#ifndef Partition_h
#define Partition_h


#include <ycp/YCPList.h>
#include <ycp/YCPString.h>
#include <y2util/ExternalProgram.h>


class Partition
{

public:

    /**
     * Create an new instance.
     */
    Partition (string partition_name) :
	partition_name (partition_name),
	process (0),
	exit_code (-1)
    {
    }

    /**
     * Clean up.
     */
    virtual ~Partition ()
    {
	delete process;
    }

    /**
     * Return the exit status of the makefs process, closing the connection
     * if not already done.
     */
    virtual int status ();

    /**
     * Forcably kill the makefs process
     */
    virtual void kill_format ();

    /**
     * Read progress indicator of the makefs process. Range of percent is
     * from 0.0 to 100.0.
     */
    virtual bool get_progress_status (double &percent);

    /**
     * Run mke2fs with the specified arguments and handle stderr.
     */
    virtual void format (YCPList options,
			 ExternalProgram::Stderr_Disposition stderr_disp =
			 ExternalProgram::Stderr_To_Stdout) = 0;

protected:

    /**
     * The name of the partition.
     */
    string partition_name;

    /**
     * The connection to the makefs process.
     */
    ExternalProgram *process;

    /**
     * The exit code of the makefs process, or -1 if not yet known.
     */
    int exit_code;

};


#endif // Partition_h
