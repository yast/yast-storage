/*
    Xfs_Partition.cc


    Maintainer: Klaus Kaempf <kkaempf@suse.de>

    $Id$

 */


#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <ycp/y2log.h>
#include <y2util/ExternalDataSource.h>

#include "Xfs_Partition.h"


Xfs_Partition::Xfs_Partition (string partition_name)
    : Partition (partition_name)
{
    y2milestone ("partition: <%s>", partition_name.c_str ());
}


// Get the progress status from the mkfs.xfs process

bool
Xfs_Partition::get_progress_status (double &percent)
{
    percent = 42.0;    // What else ?
    return false;      // immediate end
}


// Run mkfs.xfs with the specified arguments, handling stderr as specified
// by disp

void
Xfs_Partition::format (YCPList options,
			ExternalProgram::Stderr_Disposition disp)
{
    y2milestone ("mkfs.xfs");

    // Create the argument array

    const int argc = 10 + options->size ();	// maximum
    const char *argv[argc];

    int i = 0;
    argv[i++] = "/sbin/mkfs.xfs";
    argv[i++] = "-q";		// don't print parameters of fs
    argv[i++] = "-f";		// ???

    for (int j = 0; j < options->size (); j++) {
	YCPValue value = options->value (j);
	if (value->isString ())
	    argv[i++] = value->asString ()->value_cstr ();
	else
	    y2error ("option is no string");
    }

    argv[i++] = partition_name.c_str ();
    argv[i] = NULL;

    string command = argv[0];
    for (int k = 1; k < i; k++)
	command = command + " " + argv[k];
    y2milestone ("command: <%s>", command.c_str ());

    // Launch the program

    exit_code = -1;
    process = new ExternalProgram (argv, disp);
}
