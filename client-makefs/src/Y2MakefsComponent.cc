/*
    Y2MakefsComponent.cc

    Maintainer: Arvin Schnell <arvin@suse.de>

    $Id$
 */


#include <sys/statvfs.h>
#include <ycp/y2log.h>
#include <y2/Y2ComponentBroker.h>
#include <y2/Y2Component.h>
#include <y2/Y2Namespace.h>
#include <y2/Y2Function.h>

#include "Y2MakefsComponent.h"
#include "Ext2_Partition.h"
#include "Reiser_Partition.h"
#include "Fat_Partition.h"
#include "Xfs_Partition.h"
#include "Jfs_Partition.h"


#define RETURN_OK      YCPSymbol("ok")		// `ok
#define RETURN_ERROR   YCPSymbol("error")	// `error
#define RETURN_CANCEL  YCPSymbol("cancel")	// `cancel


// MakefsComponent

YCPValue
Y2MakefsComponent::doActualWork (const YCPList & options,
				 Y2Component * displayserver)
{
    // get the parameters

    // get the report macro
    string macro = (options->value (0)->isVoid () ? "" :
		    options->value (0)->asString ()->value ());
		    
    // get a way to call the macro
    report_macro = NULL;
    
    string::size_type colonpos = macro.find("::");
    if ( colonpos != string::npos ) {
	module = macro.substr ( 0, colonpos );
        symbol = macro.substr ( colonpos + 2 );
	
	Y2Component* comp = Y2ComponentBroker::getNamespaceComponent (module.c_str ());
	if (comp != NULL)
	{
	    report_macro = comp->import (module.c_str ());
	    if (report_macro == NULL)
	    {
		y2error ("Component does does not provide %s", module.c_str ());
	    }
	}
	else
	{
	    y2error ("Cannot find a component to provide %s", module.c_str ());
	}
    }


    // get partition type
    partition_type = (options->value (1)->isVoid () ? "" :
		      options->value (1)->asString ()->value ());

    // get partition name
    partition_name = (options->value (2)->isVoid () ? "" :
		      options->value (2)->asString ()->value ());

    // get partition options
    partition_options = (options->value (3)->isVoid () ? YCPList () :
			 options->value (3)->asList ());

    // start work

    y2milestone ("Formatting partition: <%s> with <%s>",
		 partition_name.c_str (), partition_type.c_str ());

    // create partition

    Partition * partition = NULL;

    if (partition_type == "ext2")
	partition = new Ext2_Partition (partition_name);
    else if (partition_type == "reiserfs")
	partition = new Reiser_Partition (partition_name);
    else if (partition_type == "fat16")
	partition = new Fat_Partition (partition_name, false);
    else if (partition_type == "fat32")
	partition = new Fat_Partition (partition_name, true);
    else if (partition_type == "xfs")
	partition = new Xfs_Partition (partition_name);
    else if (partition_type == "jfs")
	partition = new Jfs_Partition (partition_name);
    else
    {
	y2error ("unknown partition type");
	return YCPNull ();
    }

    // init progress bar

    YCPValue val = report_progress (displayserver, 0);
    if (!val.isNull () && !val->isVoid ())
	return val;

    // start formatting

    partition->format (partition_options);

    // show progress

    double percent = 0.0;

    while (partition->get_progress_status (percent))
    {
	YCPValue val = report_progress (displayserver, percent);
	if (!val.isNull () && !val->isVoid ())
	{
	    partition->kill_format ();
	    return val;
	}
    }

    // last step manually

    report_progress (displayserver, 100.0);

    // return status

    int makefs_status = partition->status ();
    if (makefs_status != 0)
    {
	y2warning ("makefs returned %d", makefs_status);
	return RETURN_ERROR;
    }

    delete partition;

    return RETURN_OK;
}


YCPValue
Y2MakefsComponent::report_progress (Y2Component* displayserver, double percent)
{
    y2debug ("Reporting progress: %f percent", percent);

    if (report_macro == NULL)
	return YCPVoid ();

    // build command
    Y2Function* t = report_macro->createFunctionCall (symbol);
    
    if (t != NULL)
    {
	t->appendParameter (YCPInteger ((long long) percent));
	
	YCPValue val = t->evaluateCall ();
	
	delete t;

	// check result
	if (!val.isNull () && !val->isVoid ())
	{
	    if (val->isSymbol () && val->asSymbol ()->symbol () == "cancel")
		return val;

	    y2error ("macro returned %s", val->toString ().c_str ());
	    return RETURN_ERROR;
	}
	return val;
    }
    
    return YCPVoid ();

}
