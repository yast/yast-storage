// Maintainer: fehr@suse.de

#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include <dirent.h>
#include <fstream>
#include <sys/ioctl.h>
#include <sys/stat.h>

#include <string>
#include <list>
#include <ycp/y2log.h>


#include "AppUtil.h"
#include "AsciiFile.h"
#include "FdiskAcc.h"
#include "LvmAccess.h"

#include "MdAccess.h"

MdAccess::MdAccess()
    {
    y2milestone( "Konstruktor MdAccess" );
    SystemCmd Cmd_Ci;
    Cmd_Ci.Execute( "/sbin/raidautorun" );
    ReadMdData();
    y2debug( "End Konstruktor MdAccess" );
    }

MdAccess::~MdAccess()
    {
    List_C.clear();
    }

void MdAccess::ReadMdData()
    {
    std::ifstream File_Ci( "/proc/mdstat" );
    std::ifstream Tab_Ci( "/etc/raidtab" );
    string Line_Ci;
    MdInfo Elem_ri;

    List_C.clear();
    getline( File_Ci, Line_Ci );
    while( File_Ci.good() )
	{
	string Tmp_Ci;
	Tmp_Ci = ExtractNthWord( 0, Line_Ci );
	y2debug( "Line=\"%s\" Word=\"%s\"", Line_Ci.c_str(), 
	         Tmp_Ci.c_str() );
	if( Tmp_Ci.length()>2 && Tmp_Ci.find( "md" )==0 && 
	    isdigit(Tmp_Ci[2]) && isdigit(Tmp_Ci[Tmp_Ci.length()-1]) )
	    {
	    bool ReadOnly_bi = false;
	    Elem_ri.DevList_C.clear();
	    Elem_ri.Nr_i = 0;
	    Elem_ri.ChunkSize_l = 0;
	    Elem_ri.Blocks_l = 0;
	    Elem_ri.RaidType_C = "";
	    Elem_ri.ParityAlg_C = "";
	    sscanf( Tmp_Ci.c_str()+2, "%d", &Elem_ri.Nr_i );
	    Elem_ri.Name_C = "/dev/" + Tmp_Ci;
	    y2debug( "Device=\"%s\"", Elem_ri.Name_C.c_str() );
	    Line_Ci.erase( 0, Line_Ci.find( ":" )+1 );
	    Tmp_Ci = ExtractNthWord( 0, Line_Ci );
	    if( Tmp_Ci.length()>0 && Tmp_Ci[0]=='(' && 
	        Tmp_Ci[Tmp_Ci.length()-1]==')' )
		{
		ReadOnly_bi = Tmp_Ci.find( "read-only" )!=string::npos;
		Line_Ci.erase( 0, Line_Ci.find( Tmp_Ci )+Tmp_Ci.length() );
		}
	    Tmp_Ci = ExtractNthWord( 0, Line_Ci );
	    if( Tmp_Ci == "active" && !ReadOnly_bi )
		{
		string::size_type Pos_ii;
		int Idx_ii = 2;
		int Tmp_ii;
		Elem_ri.RaidType_C = ExtractNthWord( 1, Line_Ci );
		Tmp_Ci = ExtractNthWord( Idx_ii++, Line_Ci );
		while( Tmp_Ci.find('[')!=string::npos )
		    {
		    if( (Pos_ii=Tmp_Ci.find_first_of( "[(" ))!=string::npos )
			{
			Tmp_Ci.erase( Pos_ii );
			}
		    Tmp_Ci = "/dev/" + Tmp_Ci;
		    y2debug( "used Device=\"%s\"", Tmp_Ci.c_str() );
		    Elem_ri.DevList_C.push_back( Tmp_Ci );
		    Tmp_Ci = ExtractNthWord( Idx_ii++, Line_Ci );
		    }
		if( Tmp_Ci.length()>0 )
		    {
		    Line_Ci = ExtractNthWord( --Idx_ii, Line_Ci, true );
		    y2debug( "rest Line=\"%s\"", Line_Ci.c_str() );
		    }
		if( Line_Ci.find("blocks")==string::npos )
		    {
		    Line_Ci.erase();
		    }
		y2debug( "rest Line=\"%s\"", Line_Ci.c_str() );
		if( Line_Ci.length()==0 )
		    {
		    getline( File_Ci, Line_Ci );
		    y2debug( "new Line=\"%s\"", Line_Ci.c_str() );
		    }
		Tmp_Ci = ExtractNthWord( 0, Line_Ci );
		sscanf( Tmp_Ci.c_str(), "%ld", &Elem_ri.Blocks_l );
		Pos_ii = Line_Ci.find( "chunk" );
		y2debug( "Pos chunk:%d", Pos_ii );
		if( Pos_ii != string::npos && Pos_ii>0 )
		    {
		    Pos_ii--;
		    while( Pos_ii>0 && isspace(Line_Ci[Pos_ii]) )
			{
			Pos_ii--;
			}
		    while( Pos_ii>0 && !isspace(Line_Ci[Pos_ii]) )
			{
			Pos_ii--;
			}
		    if( Pos_ii>0 )
			{
			sscanf( Line_Ci.c_str()+Pos_ii+1, "%ld", 
			        &Elem_ri.ChunkSize_l );
			}
		    }
		Pos_ii = Line_Ci.find( "algori" );
		y2debug( "Pos algo:%d", Pos_ii );
		if( Pos_ii != string::npos && 
		    (Pos_ii=Line_Ci.find_first_of( "0123456789", Pos_ii )))
		    {
		    Tmp_ii = -1;
		    sscanf( Line_Ci.c_str()+Pos_ii, "%d", &Tmp_ii );
		    switch( Tmp_ii )
			{
			case 0:
			    Elem_ri.ParityAlg_C = "left-asymmetric";
			    break;
			case 1:
			    Elem_ri.ParityAlg_C = "right-asymmetric";
			    break;
			case 2:
			    Elem_ri.ParityAlg_C = "left-symmetric";
			    break;
			case 3:
			    Elem_ri.ParityAlg_C = "right-symmetric";
			    break;
			default:
			    break;
			}
		    }
		if( Pos_ii==string::npos )
		    {
		    Pos_ii = 0;
		    }
		Pos_ii = Line_Ci.find( "[", Pos_ii );
		y2debug( "Pos [:%d", Pos_ii );
		if( Pos_ii != string::npos && 
		    (Pos_ii=Line_Ci.find_first_of( "0123456789", Pos_ii )))
		    {
		    Tmp_ii = 1;
		    sscanf( Line_Ci.c_str()+Pos_ii, "%d", &Tmp_ii );
		    Elem_ri.ValDisks_i = Tmp_ii;
		    }
		if( Pos_ii==string::npos )
		    {
		    Pos_ii = 0;
		    }
		Pos_ii = Line_Ci.find( "/", Pos_ii );
		y2debug( "Pos /:%d", Pos_ii );
		if( Pos_ii != string::npos && 
		    (Pos_ii=Line_Ci.find_first_of( "0123456789", Pos_ii )))
		    {
		    Tmp_ii = 1;
		    sscanf( Line_Ci.c_str()+Pos_ii, "%d", &Tmp_ii );
		    Elem_ri.UsedDisks_i = Tmp_ii;
		    }
		if( Elem_ri.RaidType_C=="raid0" )
		    {
		    Elem_ri.UsedDisks_i = Elem_ri.ValDisks_i = 
			Elem_ri.DevList_C.size();
		    }
		List_C.push_back( Elem_ri );
		}
	    }
	getline( File_Ci, Line_Ci );
	}
    y2milestone( "Read /etc/raidtab" );
    getline( Tab_Ci, Line_Ci );
    while( Tab_Ci.good() )
	{
	string Key_Ci;
	y2debug( "Line=\"%s\"", Line_Ci.c_str() );
	if( ExtractNthWord( 0, Line_Ci )=="raiddev" )
	    {
	    list<MdInfo>::iterator P_Ci = FindMd( ExtractNthWord(1, Line_Ci) );
	    if( P_Ci != List_C.end() )
		{
		string Device_Ci;
		getline( Tab_Ci, Line_Ci );
		Key_Ci = ExtractNthWord( 0, Line_Ci );
		y2debug( "Key=\"%s\" P=%p End:%p", Key_Ci.c_str(), &(*P_Ci), 
			 &(*List_C.end()) );
		while( Tab_Ci.good() && Key_Ci!="raiddev" )
		    {
		    y2debug( "Key=\"%s\" Line:\"%s\"", Key_Ci.c_str(), 
		             Line_Ci.c_str() );
		    if( Key_Ci=="persistent-superblock" )
			{
			P_Ci->PersistentSuper_b = 
			    ExtractNthWord(1,Line_Ci)=="1";
			}
		    else if( Key_Ci=="spare-disk" )
			{
			P_Ci->DevList_C.push_back( Device_Ci );
			}
		    else if( Key_Ci=="device" )
			{
			Device_Ci = ExtractNthWord(1,Line_Ci);
			}
		    getline( Tab_Ci, Line_Ci );
		    Key_Ci = ExtractNthWord( 0, Line_Ci );
		    }
		}
	    else
		getline( Tab_Ci, Line_Ci );
	    }
	else
	    {
	    getline( Tab_Ci, Line_Ci );
	    }
	}
    }

unsigned MdAccess::Cnt()
    {
    return List_C.size();
    }

MdInfo MdAccess::GetMd( int Idx_iv )
    {
    MdInfo Info_Ci;
    list<MdInfo>::iterator I_ii = List_C.begin();
    while( Idx_iv>0 && I_ii!=List_C.end() )
	{
	Idx_iv--;
	I_ii++;
	}
    if( I_ii!=List_C.end() )
	{
	Info_Ci = *I_ii;
	}
    return Info_Ci;
    }

list<MdInfo>::iterator MdAccess::FindMd( const string& Device_Cv )
    {
    y2debug( "Device=\"%s\"", Device_Cv.c_str() );
    list<MdInfo>::iterator I_ii = List_C.begin();
    while( I_ii!=List_C.end() && I_ii->Name_C!=Device_Cv )
	{
	I_ii++;
	}
    return( I_ii );
    }

bool MdAccess::GetMd( const string& Device_Cv, MdInfo& Val_Cr )
    {
    MdInfo Info_Ci;
    list<MdInfo>::iterator I_ii = FindMd( Device_Cv );
    if( I_ii!=List_C.end() )
	{
	Val_Cr = *I_ii;
	}
    return( I_ii!=List_C.end() );
    }

bool MdAccess::ActivateMDs( bool Activate_bv )
    {
    SystemCmd Cmd_Ci;
    if( Activate_bv )
	{
	Cmd_Ci.Execute( "/sbin/raidautorun" );
	ReadMdData();
	}
    else
	{
	ReadMdData();
	list<MdInfo>::iterator I_ii = List_C.begin();
	while( I_ii!=List_C.end() )
	    {
	    string CmdLine_Ci = "/sbin/raidstop ";
	    if( access( "/etc/raidtab", R_OK ) != 0 )
		{
		CmdLine_Ci += "-c /dev/null ";
		}
	    CmdLine_Ci += I_ii->Name_C;
	    Cmd_Ci.Execute( CmdLine_Ci );
	    I_ii++;
	    }
	}
    return( true );
    }

