

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <ycp/y2log.h>
#include <y2/ExternalDataSource.h>

#include "Ext2_Partition.h"


Ext2_Partition::Ext2_Partition (string partition_name)
    : Partition (partition_name)
{
    y2milestone ("partition: <%s>", partition_name.c_str ());
}


// Get the progress status from the mke2fs process

bool
Ext2_Partition::get_progress_status (double &percent)
{
    bool retval = true;
    bool go = true;

    char buf_1[1];

    char *seperator = NULL;

    static char buf_2[100];
    static char *buf_2_p = buf_2;

    size_t nread = 0;

    static enum { InValues, InBackspace, InGarbage }
    state = InGarbage;

    /*
     * The mke2fs command outputs sequential progress values on one
     * single line using backspaces to overwrite the former output
     * ( e.g. "...121/123^H^H^H^H^H^H^H122/123^H^H^H^H^H^H^Hdone..." ).
     * All this output results in one big line (\n), so we can not use
     * process->receiveLine for this purpose.
     * => we scan the input stream one character at a time.
     */

    // read all the characters in the queue
    while (nread = process->receive (buf_1, sizeof (buf_1)), nread != 0 && go) {
	switch (state) {

	case InValues:
	    if (buf_1[0] == '\b') {
		/*
		 * State transition: InValues-->InBackspace (multiple)
		 */

		state = InBackspace;

		*buf_2_p = '\0';	// terminate buffer
		buf_2_p = buf_2;	// scanning complete
		if ((seperator = strchr (buf_2, '/')) == NULL)
		    continue;
		*(seperator++) = '\0';	// seperate values
		percent = (double) atoi (buf_2) / (double) atoi (seperator) * 100.0;
		y2debug ("progress: %f percent", percent);

		go = false;	// we got a new value --> stop scanning

	    } else {		// continue InValues

		/*
		 * store current character
		 */

		*(buf_2_p++) = buf_1[0];
	    }

	    break;

	case InBackspace:
	    if (buf_1[0] != '\b') {	// no more backspaces
		if (buf_1[0] == 'd') {	// "done"
		    /*
		     * Last state transition: InBackspace-->InGarbage (only once)
		     */

		    state = InGarbage;
		    retval = false;
		} else {	// values
		    /*
		     * State transition: InBackspace-->InValues (multiple)
		     */

		    *(buf_2_p++) = buf_1[0];	// first character of values
		    state = InValues;
		}
	    }
	    continue;
	    break;

	default:	// InGarbage
	    /*
	     * First state transition: InGarbage-->InBackspace (only once)
	     */

	    if (buf_1[0] == '\b')
		state = InBackspace;
	    continue;
	    break;
	}
    }

    // if nothing is left to read don't call me again

    if (nread == 0)
	retval = false;

    return retval;
}


// Run mke2fs with the specified arguments, handling stderr as specified
// by disp

void
Ext2_Partition::format (YCPList options,
			ExternalProgram::Stderr_Disposition disp)
{
    y2milestone ("mke2fs");

    // Create the argument array

    const int argc = 10 + options->size ();	// maximum
    const char *argv[argc];

    int i = 0;
    argv[i++] = "/sbin/mke2fs";
    argv[i++] = "-v";		// be verbose

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
