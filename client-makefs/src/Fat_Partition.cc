

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <ycp/y2log.h>
#include <ycp/YCPString.h>
#include <y2/ExternalDataSource.h>

#include "Fat_Partition.h"


Fat_Partition::Fat_Partition (string partition_name, bool as_fat32)
    : Partition (partition_name)
    , Fat32(as_fat32)
{
    y2milestone ("partition: <%s, FAT%d>", partition_name.c_str (), as_fat32?32:16);
}


// Run mkdosfs with the specified arguments, handling stderr as specified
// by disp

void
Fat_Partition::format (YCPList options,
		       ExternalProgram::Stderr_Disposition disp)
{
    y2milestone ("mkdosfs");

    // Create the argument array

    const int argc = 10 + options->size ();	// maximum
    const char *argv[argc];

    int i = 0;
    argv[i++] = "/sbin/mkdosfs";

    // check if fat size already given in options

    bool fat_size_given = false;

    for (int j = 0; j < options->size (); j++)
    {
	YCPValue value = options->value (j);
	if (value->isString ())
	{
	    argv[i] = value->asString ()->value_cstr ();

	    // check for "-F ..." in options

	    if ((argv[i][0] == '-')
		&& (argv[i][1] == 'F'))
	    {
		fat_size_given = true;
	    }
	    i++;
	}
	else
	{
	    y2error ("option is no string");
	}
    }

    // mkdosfs defaults to Fat12/Fat16
    // larger fat sizes must be explicitly given

    if (!fat_size_given
	&& Fat32)
    {
	argv[i++] = "-F 32";
    }

    argv[i++] = partition_name.c_str ();
    argv[i] = NULL;

    string command = argv[0];
    for (int k = 1; k < i; k++)
    {
	command = command + " " + argv[k];
    }
    y2milestone ("command: <%s>", command.c_str ());

    // Launch the program

    exit_code = -1;
    process = new ExternalProgram (argv, ExternalProgram::Discard_Stderr);
}
