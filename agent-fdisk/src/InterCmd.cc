// Maintainer: fehr@suse.de

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <string>
#include <errno.h>

#include "AppUtil.h"
#include "InterCmd.h"

#include <ycp/y2log.h>

InterCmd::InterCmd( string Command_Cv, bool UseTmp_bv ) :
	SystemCmd( UseTmp_bv ),
	Pipe_pr(NULL)
    {
    DBG( App_pC->Dbg() << "Konstruktor InterCmd:\"" << Command_Cv << "\"\n"; )
    Execute( Command_Cv );
    }

InterCmd::InterCmd( bool UseTmp_bv ) :
	SystemCmd( UseTmp_bv ),
	Pipe_pr(NULL)
    {
    y2debug( "Konstruktor InterCmd\n" );
    }

InterCmd::~InterCmd()
    {
    if( Pipe_pr )
	{
	pclose( Pipe_pr );
	}
    }

bool
InterCmd::SendInput( string Input_Cv, string Sign_Cv,
                     const unsigned MaxTime_iv )
    {
    y2debug("input:%s sign:%s max:%d", Input_Cv.c_str(), Sign_Cv.c_str(), 
            MaxTime_iv );
    bool Ret_bi = true;
    if( Pipe_pr )
	{
	Invalidate();
	y2debug( "Sending Input:\"%s\"", Input_Cv.c_str() );
	fprintf( Pipe_pr, "%s\n", Input_Cv.c_str() );
  	fflush( Pipe_pr );
	if( Sign_Cv != "" )
	    {
	    Ret_bi = CheckOutput( Sign_Cv, MaxTime_iv );
	    }
	}
    else
	{
	  y2error("SendInput() failed, Pipe_pr == 0");
	}
    return( Ret_bi );
    }

void
InterCmd::Execute( string Cmd_Cv )
    {
    string Cmd_Ci;
    int Rest_ii = 60*1000000;

    InitCmd( Cmd_Cv, Cmd_Ci );
    Pipe_pr = popen(Cmd_Ci.c_str(), "w" );
    if( Pipe_pr == NULL )
	{
	  y2error("popen (%s) failed with %s", Cmd_Ci.c_str(), strerror (errno));
	}
    y2debug("popen (%s) ok", Cmd_Ci.c_str());
    while( access( FileName_aC[IDX_STDOUT].c_str(), R_OK ) == -1 && Rest_ii>0 )
	{
	Delay( 100000 );
	Rest_ii -= 100000;
	}
    while( access( FileName_aC[IDX_STDERR].c_str(), R_OK ) == -1 && Rest_ii>0 )
	{
	Delay( 100000 );
	Rest_ii -= 100000;
	}
    if( Rest_ii < 0 )
	{
	  y2error("access timeout in Execute");
	}
    OpenFiles();
    }

bool
InterCmd::CheckOutput( string Sign_Cv, const unsigned MaxTime_iv )
    {
    bool Found_bi = false;
    bool First_bi = true;
    unsigned int Idx_ii = 0;
    int Rest_ii = MaxTime_iv*1000000;
    string Ok_Ci = Sign_Cv;
    string Error_Ci;

    if( Ok_Ci.find( '|' ) != string::npos )
	{
	Error_Ci = Ok_Ci.substr(Ok_Ci.find('|')+1);
	Ok_Ci.erase(Ok_Ci.find('|'));
	}
    Lines_aC[IDX_STDOUT].clear();
    Delay( 10000 );
    do
	{
	string *Line_pCi;

	y2debug( "Reading Stdout" );
	GetUntilEOF( File_aC[IDX_STDOUT], Lines_aC[IDX_STDOUT], 
	             NewLineSeen_ab[IDX_STDOUT], false );
	while( !Found_bi && Idx_ii<Lines_aC[IDX_STDOUT].size() )
	    {
	    Line_pCi = &Lines_aC[IDX_STDOUT][Idx_ii++];
	    if( Line_pCi->find( Ok_Ci ) != string::npos )
		{
		Found_bi = First_bi = true;
		}
	    else if( Line_pCi->find( Error_Ci ) != string::npos )
		{
		Found_bi = true;
		First_bi = false;
		}
	    }
	if( !Found_bi )
	    {
	    Delay( 50000 );
	    Rest_ii -= 50000;
	    y2debug( "Stdout At EOF Rest:%d", Rest_ii );
	    }
	}
    while( !Found_bi && Rest_ii>0 );
    if( !Found_bi )
	{
	  y2error("CheckOutput timed out");
	  string last_output;
	  for (Idx_ii = 0; Idx_ii < Lines_aC[IDX_STDOUT].size(); Idx_ii++)
	    {
	      last_output += Lines_aC[IDX_STDOUT][Idx_ii];
	      last_output += '\n';
	    }
	  y2error( "Last output: %s", last_output.c_str());
	}
    Lines_aC[IDX_STDERR].clear();
    y2debug( "Reading Stderr" );
    GetUntilEOF( File_aC[IDX_STDERR], Lines_aC[IDX_STDERR],
		 NewLineSeen_ab[IDX_STDERR], true );
    return( Found_bi && First_bi );
    }

