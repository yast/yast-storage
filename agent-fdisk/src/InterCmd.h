// -*- C++ -*-
// Maintainer: schwab@suse.de

#ifndef _InterCmd_h
#define _InterCmd_h


#include <stdio.h>
#include <fstream>
#include <string>

#define DBG(x)

#include "SystemCmd.h"

class InterCmd : public SystemCmd
    {
    public:
	InterCmd( string Command_Cv, bool UseTmp_bv=false );
	InterCmd( bool UseTmp_bv=false );
	virtual ~InterCmd();
	void Execute( string Command_Cv );
	bool SendInput( string Input_Cv, string Sign_Cv="",
	                const unsigned MaxTime_iv=60 );
	bool CheckOutput( string Sign_Cv, const unsigned MaxTime_iv=60 );
    protected:
	FILE *Pipe_pr;
    };

#endif
