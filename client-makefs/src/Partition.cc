

/*
 *  Author:	Arvin Schnell <arvin@suse.de>
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#include <ycp/y2log.h>

#include "Partition.h"


int
Partition::status ()
{
    y2debug ("status ()");
    if (exit_code == -1)
	exit_code = process->close ();
    return exit_code;
}


void
Partition::kill_format ()
{
    if (process)
	process->kill ();
}


bool
Partition::get_progress_status (double &percent)
{
    percent = 42.0;		// :-)
    return false;
}

