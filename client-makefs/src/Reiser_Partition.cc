

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <ycp/y2log.h>
#include <ycp/YCPString.h>
#include <y2util/ExternalDataSource.h>

#include "Reiser_Partition.h"


Reiser_Partition::Reiser_Partition (string partition_name)
    : Partition (partition_name)
{
    y2milestone ("partition: <%s>", partition_name.c_str ());
}


// Get the progress status from the mkreiserfs process

bool
Reiser_Partition::get_progress_status (double &percent)
{
    bool retval = true;
    bool go = true;

    char buf_1[1];

    char *seperator = NULL;

    static char buf_2[100];
    static char *buf_2_p = buf_2;

    size_t nread = 0;

    static enum { InValues, InDots, InGarbage }
    state = InGarbage;

    /*
     * The mkreiserfs command outputs sequential progress values on one
     * single line
     * ( e.g. "... 0%....20%....40%....60%....80%....100%  .... ")
     * All this output results in one big line (\n), so we can not use
     * process->receiveLine for this purpose.
     * => we scan the input stream one character at a time.
     */

    // read all the characters in the queue
    while (nread = process->receive (buf_1, sizeof (buf_1)), nread != 0 && go) {
	switch (state) {

	case InValues:
	    if (buf_1[0] != '%' && !(buf_1[0] >= '0' && buf_1[0] <= '9')) {

		/*
		 * State transition: InValues-->InDots (multiple)
		 */

		state = InDots;

		*buf_2_p = '\0';	// terminate buffer
		buf_2_p = buf_2;	// scanning complete
		if ((seperator = strchr (buf_2, '%')) == NULL)
		    continue;
		*(seperator++) = '\0';	// seperate values
		percent = (double) atoi (buf_2) * 0.8;

		y2debug ("progress: %f percent", percent);

		go = false;	// we got a new value --> stop scanning

	    } else {	// continue InValues

		/*
		 * store current character
		 */

		*(buf_2_p++) = buf_1[0];

	    }

	    break;

	case InDots:
	    if (buf_1[0] != '.') {	// no more Dotss
		if (buf_1[0] == '\n') {	// "\nSyncing"
		    /*
		     * Last state transition: InDots-->InGarbage (only once)
		     */

		    state = InGarbage;
		    retval = false;
		} else {	// values
		    /*
		     *  State transition: InDots-->InValues (multiple)
		     */

		    *(buf_2_p++) = buf_1[0];	// first character of values
		    state = InValues;
		}
	    }
	    continue;
	    break;

	default:	// InGarbage
	    /*
	     * First state transition: InGarbage-->InDots (only once)
	     */

	    if (buf_1[0] == '%')
		state = InDots;
	    continue;
	    break;
	}
    }

    // if nothing is left to read don't call me again

    if (nread == 0)
	retval = false;

    return retval;
}


// Run mkreiserfs with the specified arguments, handling stderr as specified
// by disp

void
Reiser_Partition::format (YCPList options,
			  ExternalProgram::Stderr_Disposition disp)
{
    y2milestone ("mkreiserfs");

    // Create the argument array

    const int argc = 10 + options->size ();	// maximum
    const char *argv[argc];

    int i = 0;
    argv[i++] = "/sbin/mkreiserfs";
    argv[i++] = "-f";		// batch mode, dont ask questions
    argv[i++] = "-f";

    for (int j = 0; j < options->size (); j++)
    {
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
    process->send ("y\n");
}
