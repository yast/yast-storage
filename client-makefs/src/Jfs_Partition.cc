/*
    Jfs_Partition.cc


    Maintainer: Klaus Kaempf <kkaempf@suse.de>

    $Id$

 */


#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <ycp/y2log.h>
#include <ycp/YCPString.h>
#include <y2/ExternalDataSource.h>

#include "Jfs_Partition.h"


Jfs_Partition::Jfs_Partition (string partition_name)
    : Partition (partition_name)
{
    y2milestone ("partition: <%s>", partition_name.c_str ());
}


// Get the progress status from the mkfs.jfs process

bool
Jfs_Partition::get_progress_status (double &percent)
{
    percent = 42.0;    // What else ?
    return false;      // immediate end
}


// Run mkfs.jfs with the specified arguments, handling stderr as specified
// by disp

void
Jfs_Partition::format (YCPList options,
			ExternalProgram::Stderr_Disposition disp)
{
    y2milestone ("mkfs.jfs");

    // Create the argument array

    const int argc = 10 + options->size ();	// maximum
    const char *argv[argc];

    int i = 0;
    argv[i++] = "/sbin/mkfs.jfs";
    argv[i++] = "-q";		// do not ask for confirmation

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
