// -*- C++ -*-

#ifndef Y2PartedComponent_h
#define Y2PartedComponent_h

#include <Y2.h>

/**
 * @short
 */
class Y2PartedComponent : public Y2Component
{
private:
   // Name of macros to call for progress indication.

   string module;
   string progress_symbol;
   string directory_symbol;
   string exception_symbol;

   Y2Namespace* report_macro;

   string partition;		// partition to resize
   string partition_start;	// start of the partition in MB on disk
   string partition_length;	// new size of the partition in MB


public:
   /**
    * Create a new parted component
    */
   Y2PartedComponent::Y2PartedComponent()
      : module(""),
        progress_symbol(""),
	directory_symbol(""),
	exception_symbol(""),
	report_macro(NULL),
	partition(""),
	partition_start(""),
	partition_length(""){}

   /**
    * What I'm called: "parted"
    */
   static string component_name() { return "parted"; }
   string name() const { return component_name(); }

   /**
    * Do the actual work of resizing
    */
   YCPValue doActualWork(const YCPList& options, Y2Component *displayserver);

   /**
    * Set the client arguments:
    * <progress_macro>		- macro to adjust progress bar
    * <directory_macro>		- macro to display directory information
    * <exception_macro>		- macro to display exception information
    * "/dev/sda1"		- partition to be resized
    * "0.0"			- new start of partition in MB on disk
    * "200.3"			- length of partition im MB on disk
    */

private:
   YCPValue report_progress(Y2Component *displayserver, string message_progress );
   YCPValue report_directory(Y2Component *displayserver, string message_directory );
   YCPValue report_exception(Y2Component *displayserver, string message_exception );
};

#endif // Y2PartedComponent_h
