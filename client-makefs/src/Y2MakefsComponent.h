// -*- c++ -*-

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#ifndef Y2MakefsComponent_h
#define Y2MakefsComponent_h


#include <Y2.h>
#include <ycp/YCPList.h>

/**
 * @short Install and uninstall packages
 */
class Y2MakefsComponent:public Y2Component
{

private:

    /**
     * A namespace to provide progress bar, or NULL if quiet or error
     */
    Y2Namespace* report_macro;
    
    string module;
    
    string symbol;

    /**
     * type of partition (e.g. "ext2", "reiserfs", ...)
     */
    string partition_type;

    /**
     * name of partition
     */
    string partition_name;

    /**
     * options for partiton
     */
    YCPList partition_options;

public:

    /**
     * Create a new makefs component
     */
    Y2MakefsComponent::Y2MakefsComponent ()
	: report_macro (NULL),
	  module (""),
	  symbol (""),
	  partition_type (""),
	  partition_name (""),
	  partition_options ()
    {
    }

    /**
     * What I'm called: "makefs"
     */
    static string component_name () { return "makefs"; }
    string name () const { return component_name (); }

    /**
     * Do the actual work of formatting.
     *
     * makefs (macro, partition_type, partition_name, partition_options)
     *
     * - macro is either nil or a symbol that is called during
     *   formatting as macro (partitionname, percent)
     *     - partitionname	name of current partiton
     *     - percent		how much of the current partition is formatted
     *
     * - partition_type
     *     either "ext2", "reiserfs", "fat", "xfs" or "jfs"
     *
     * - partition_name
     *
     * - partition_options
     *     a list of strings with some options
     */
    YCPValue doActualWork (const YCPList & options, Y2Component * displayserver);

private:

    YCPValue report_progress (Y2Component * displayserver, double percent);

};


#endif // Y2MakefsComponent_h
