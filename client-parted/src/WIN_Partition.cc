#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include "WIN_Partition.h"
#include <ycp/y2log.h>
#include <y2util/ExternalDataSource.h>

#define PROGRESS_MSG		"Progress:"
#define DIRECTORY_MSG		"Directory:"


// Win partiton constructor
//
WIN_Partition::WIN_Partition( string partition_name )
   : partition(partition_name), process(0), exit_code(-1)
{
   // split e.g. /dev/sda1 into /dev/sda and 1 (parted requirements)
   string::size_type minor_start = partition.find_first_of( "0123456789" );

   if ( minor_start != string::npos )
   {
      partition_device = partition.substr( 0, minor_start );
      partition_minor  = partition.substr( minor_start );
   }
   else
   {
      y2error ("invalid partition name: <%s>", partition.c_str() );
   }

   y2milestone ("partition       : <%s>", partition.c_str());
   y2milestone ("partition_device: <%s>", partition_device.c_str());
   y2milestone ("partition_minor : <%s>", partition_minor.c_str());
}

// Win partition destructor
//
WIN_Partition::~WIN_Partition()
{
   delete process;
}


// Return the exit status of the parted process, closing the connection if
// not already done.
//
int
WIN_Partition::status()
{
   y2debug ("status()");

   // close process and receive exit code
   if (exit_code == -1) exit_code = process->close();
   
   return exit_code;
}


// Forcably kill the parted process.
// This _MUST_NOT_ be done during resize because killing the resize
// process leaves a corrupted FAT partition behind.
// (commented out but left in for information)
//
// void
// WIN_Partition::kill_resize()
// {
//    if (process) process->kill();
// }


// Get the progress status from the parted process.
// Returns:	true 	- call again
//		false	- don't call again, ready
//
bool
WIN_Partition::get_progress_status( string &message_progress,
				    string &message_directory,
				    string &message_exception )
{
   bool   retval = true;
   string output_line("");
   

   while ( retval && ( output_line = process->receiveLine() ) != "" )
   {
      if ( output_line.find( PROGRESS_MSG ) != string::npos )
      {
	 // *** parted output is a progress message (Progress: 30)
	 // Isolate the percentage value string and forward to caller
	 //
	 string::size_type num_start = output_line.find_first_of( "0123456789" );
	 
	 if ( num_start != string::npos )
	 {
	    message_progress = output_line.substr( num_start );
	    
	    y2debug ("progress: <%s>", message_progress.c_str() );
	    
	    return retval;	// deliver output
	 }
	 else
	 {
	    y2error ("invalid progress value: <%s>", output_line.c_str() );
	    continue;	// get next output
	 }
      }
      else if ( output_line.find( DIRECTORY_MSG ) != string::npos   )
      {
	 // *** parted output is a directory message
	 // Isolate the directory string and forward to caller
	 //
	 string::size_type num_start = output_line.find_first_of( " " );
	 
	 if ( num_start != string::npos )
	 {
	    message_directory = output_line.substr( num_start + 1 );
	    
	    y2debug ("directory: <%s>", message_directory.c_str() );
	    
	    return retval;	// deliver output
	 }
	 else
	 {
	    y2error ("invalid directory value: <%s>", output_line.c_str() );
	    continue;	// get next output
	 }
      }
      else	// other output from parted
      {
	 // *** parted output is something not expected
	 // There is nothing to isolate here. The output _IS_ the message.
	 //
	 message_exception = output_line;	// forward other message to caller
	 
	 y2error ("unexpected message: <%s>", message_exception.c_str() );
	 
	 return retval;	// deliver output
      }
   }	

   // if nothing is left to read don't call me again
   
   if ( output_line == "" ) retval = false;
   
   return retval;
}	// End of get_progress_status()

   
// Run parted with the specified arguments, handling stderr as specified by disp
//
void
WIN_Partition::resize( string partition_start,
		       string partition_length,
		       ExternalProgram::Stderr_Disposition disp )
{
   y2milestone ("resize: start <%s> length <%s>", partition_start.c_str(), partition_length.c_str() );
  
   exit_code = -1;
   int argc = 8;		// parted device resize -s minor# start end NULL
  
   const char *argv[argc];	// Create the argument array
  
   int i = 0;
   int k = 0;
   string command;
   double new_end = 0.0;
   char pe_buf[100];

   // We need to caculate the new end dependig on the partition_length.

   new_end = atof( partition_start.c_str() ) + atof( partition_length.c_str() );
   sprintf( pe_buf, "%f", new_end );
   partition_end = pe_buf;
  
   argv[i++] = "/usr/sbin/parted";
   argv[i++] = "-s";				// script mode
   argv[i++] = partition_device.c_str();	// e.g. /dev/sda
   argv[i++] = "resize";			// do resize
   argv[i++] = partition_minor.c_str();		// e.g. 1
   argv[i++] = partition_start.c_str();		// e.g. 245.7
   argv[i++] = partition_end.c_str();		// e.g. 728.3
   argv[i]   = NULL;				// terminate

   command = argv[0];
  
   for ( k = 1; k < i; k++) command = command + " " + argv[k];

   y2milestone ("command: <%s>", command.c_str() );
  
   // Launch the program
   process = new ExternalProgram(argv, disp);
}	// End of resize()
