// Maintainer: fehr@suse.de

#include <stdio.h>
#include <unistd.h>
#include <dirent.h>
#include <fstream>
#include <sstream>
#include <sys/ioctl.h>
#include <sys/stat.h>

#include <string>
#include <list>
#include <ycp/y2log.h>

#include "MdAccess.h"

#include "AppUtil.h"
#include "AsciiFile.h"
#include "DiskAcc.h"
#include "LvmAccess.h"

LvmAccess::LvmAccess( bool Expensive_bv ) :
	LvmCmd_C( true )
    {
    y2milestone( "Konstruktor LvmAccess Expensive:%d", Expensive_bv );

    LvmVersion_i = 1;
    if( access( "/sbin/vgs", R_OK )==0 )
	{
	LvmVersion_i = 2;
	}
    y2milestone( "Ver %d", LvmVersion_i );

    ActivateLvm();
    LvmCmd_C.SetCombine();
    ScanLvmStatus();
    Expensive_b = false;
    DidVgchangeA_b = false;
    if( Expensive_bv )
	{
	DoExpensive();
	Expensive_b = true;
	}
    ProcessMd();
    y2debug( "End Konstruktor LvmAccess" );
    }

LvmAccess::~LvmAccess()
    {
    }

list<string> LvmAccess::PhysicalDeviceList()
    {
    list<string> List_Ci;
    list<VgIntern>::iterator Pix_Ci = VgList_C.begin();
    while( Pix_Ci != VgList_C.end() )
	{
	list<PvInfo*>::iterator Pv_Ci = Pix_Ci->Pv_C.begin();
	while( Pv_Ci != Pix_Ci->Pv_C.end() )
	    {
	    if( (*Pv_Ci)->RealDevList_C.size()>0 )
		{
		List_Ci.insert( List_Ci.end(), (*Pv_Ci)->RealDevList_C.begin(),
		                (*Pv_Ci)->RealDevList_C.end() );
		}
	    else
		{
		List_Ci.push_back( (*Pv_Ci)->Name_C );
		}
	    Pv_Ci++;
	    }
	Pix_Ci++;
	}
    y2debug( "len:%d", List_Ci.size() );
    return List_Ci;
    }

string LvmAccess::GetErrorText()
    {
    return LvmOutput_C;
    }

string LvmAccess::GetCmdLine()
    {
    return CmdLine_C;
    }

void LvmAccess::ActivateLvm()
    {
    PrepareLvmCmd();
    bool Activate_bi = true;
    if( RunningFromSystem() )
	{
	if( !Lvm2() )
	    {
	    DIR *Dir_pri;
	    struct dirent *Entry_pri;
	    if( (Dir_pri=opendir( "/proc/lvm/VGs" ))!=NULL )
		{
		while( Activate_bi && (Entry_pri=readdir( Dir_pri ))!=NULL ) 
		    {
		    if( strcmp( Entry_pri->d_name, "." )!=0 &&
			strcmp( Entry_pri->d_name, ".." ) != 0 )
			{
			Activate_bi = false;
			}
		    }
		closedir( Dir_pri );
		}
	    }
	else
	    {
	    Activate_bi = false;
	    }
	}
    if( Activate_bi )
	{
	ExecuteLvmCmd( "/sbin/vgscan" );
	string Cmd_Ci = "/sbin/vgchange -a y";
	ExecuteLvmCmd( Cmd_Ci );
	DidVgchangeA_b = true;
	}
    if( !Lvm2() )
	{
	ScanLvmStatus();
	}
    }

bool LvmAccess::ActivateVGs( bool Activate_bv )
    {
    string Cmd_Ci = "/sbin/vgchange -a ";
    Cmd_Ci += Activate_bv?"y":"n";
    return( ExecuteLvmCmd( Cmd_Ci ) );
    if( Activate_bv && !Lvm2() )
	{
	ScanLvmStatus();
	}
    }


bool 
LvmAccess::MountRamdisk( const string& Path_Cv, unsigned SizeMb_iv )
    {
    bool Ok_bi = false;
    int Num_ii = 3;
    string Tmp_Ci;
    string Device_Ci;
    AsciiFile Mount_Ci( "/proc/mounts" );

    while( !Ok_bi && Num_ii<10 )
	{
	Device_Ci = (string)"/dev/ram" + dec_string(Num_ii);
	Ok_bi = access( Device_Ci.c_str(), W_OK )==0 && 
	        !SearchFile( Mount_Ci, (string)"^"+Device_Ci, Tmp_Ci );
	Num_ii++;
	}
    if( Ok_bi )
	{
	SystemCmd Cmd_Ci;
	Tmp_Ci = (string)"mke2fs -F " + Device_Ci + ' ' + 
                 dec_string(SizeMb_iv*1024);
	y2milestone( "mke2fs:\"%s\"", Tmp_Ci.c_str() );
	Ok_bi = Cmd_Ci.Execute( Tmp_Ci )==0;
	Tmp_Ci = (string)"mount -t ext2 " + Device_Ci + ' ' + Path_Cv;
	y2milestone( "mount:\"%s\"", Tmp_Ci.c_str() );
	Ok_bi = Ok_bi && Cmd_Ci.Execute( Tmp_Ci )==0;
	}
    y2milestone( "MountRamdisk:%d", Ok_bi );
    return( Ok_bi );
    }



void
LvmAccess::DoExpensive()
    {
    if( !Expensive_b )
	{
	ScanForDisks();
	if( !Lvm2() && RunningFromSystem() && !DidVgchangeA_b )
	    ScanForInactiveVg();
	Expensive_b = true;
	}
    }

int 
LvmAccess::GetPvIdx( const string& Name_Cv )
    {
    int Idx_ii=0;
    list<PvInfo>::iterator Pix_Ci = PvList_C.begin();
    while( Pix_Ci!=PvList_C.end() && Pix_Ci->Name_C!=Name_Cv )
	{
	Idx_ii++;
	Pix_Ci++;
	}
    return( Pix_Ci!=PvList_C.end()?Idx_ii:-1 );
    }

void
LvmAccess::ScanForInactiveVg()
    {
    SystemCmd Cmd_Ci;
    string Tmp_Ci;
    Cmd_Ci.Execute( "/sbin/vgscan" );
    Cmd_Ci.Select( "found inactive" );
    list<string> VgList_Ci;
    int Cnt_ii = Cmd_Ci.NumLines( true );
    y2debug( "inactive vg cnt %d", Cnt_ii );
    for( int I_ii=0; I_ii<Cnt_ii; I_ii++ )
	{
	Tmp_Ci = *Cmd_Ci.GetLine( I_ii, true );
	Tmp_Ci.erase( 0, Tmp_Ci.find( "volume group" )+12 );
	Tmp_Ci = ExtractNthWord( 0, Tmp_Ci );
	string::iterator i = Tmp_Ci.begin();
	while( i!=Tmp_Ci.end() )
	    {
	    if( *i == '"' )
		Tmp_Ci.erase( i );
	    else
		i++;
	    }
	y2debug( "inactive vg name %s", Tmp_Ci.c_str() );
	if( FindVg( Tmp_Ci )==VgList_C.end() )
	    {
	    VgList_Ci.push_back( Tmp_Ci );
	    }
	}
    for( list<string>::iterator Idx_Ci=VgList_Ci.begin(); 
         Idx_Ci!=VgList_Ci.end(); Idx_Ci++ )
	{
	y2debug( "inactive vg name %s", Idx_Ci->c_str() );
	VgIntern VgElem_ri;
	LvInfo LvElem_ri;
	unsigned long Val_ii;
	Cmd_Ci.Execute( "/sbin/vgdisplay -D -v " + *Idx_Ci );
	VgElem_ri.Pv_C.clear();
	VgElem_ri.Lv_C.clear();
	VgElem_ri.Name_C = *Idx_Ci;
	VgElem_ri.Active_b = false;
	VgElem_ri.Lvm2_b = false;
	bool Ok_bi = true;

	Cmd_Ci.Select( "PE Size" );
	Ok_bi = Ok_bi && Cmd_Ci.NumLines(true)>0;
	if( Ok_bi )
	    {
	    Tmp_Ci = *Cmd_Ci.GetLine( 0, true );
	    Tmp_Ci = ExtractNthWord( 2, Tmp_Ci, true );
	    Val_ii = 4;
	    sscanf( Tmp_Ci.c_str(), "%lu", &Val_ii );
	    Val_ii *= UnitToValue( ExtractNthWord( 1, Tmp_Ci ) );
	    VgElem_ri.PeSize_l = Val_ii;
	    }

	Cmd_Ci.Select( "Total PE" );
	Ok_bi = Ok_bi && Cmd_Ci.NumLines(true)>0;
	if( Ok_bi )
	    {
	    Tmp_Ci = *Cmd_Ci.GetLine( 0, true );
	    Tmp_Ci = ExtractNthWord( 2, Tmp_Ci );
	    Val_ii = 0;
	    sscanf( Tmp_Ci.c_str(), "%lu", &Val_ii );
	    VgElem_ri.Blocks_l = Val_ii*VgElem_ri.PeSize_l;
	    }

	Cmd_Ci.Select( "Free  PE" );
	Ok_bi = Ok_bi && Cmd_Ci.NumLines(true)>0;
	if( Ok_bi )
	    {
	    Tmp_Ci = *Cmd_Ci.GetLine( 0, true );
	    Tmp_Ci = ExtractNthWord( 4, Tmp_Ci );
	    Val_ii = 0;
	    sscanf( Tmp_Ci.c_str(), "%lu", &Val_ii );
	    VgElem_ri.Free_l = Val_ii*VgElem_ri.PeSize_l;
	    }
	int Line_ii=0;
	while( Ok_bi && Line_ii<Cmd_Ci.NumLines() )
	    {
	    Tmp_Ci = *Cmd_Ci.GetLine( Line_ii++ );
	    if( Tmp_Ci.find( "LV Name" )==0 )
		{
		y2debug( "Name Line:%s", Tmp_Ci.c_str() );
		LvElem_ri.VgName_C = VgElem_ri.Name_C;
		LvElem_ri.Name_C = ExtractNthWord( 2, Tmp_Ci );
		Line_ii++;

		Tmp_Ci = ExtractNthWord( 3, *Cmd_Ci.GetLine( Line_ii++ ) );
		LvElem_ri.Writable_b = Tmp_Ci.find( "write" )!=string::npos;
		y2debug( "Write Line:%s", Tmp_Ci.c_str() );
		Tmp_Ci = ExtractNthWord( 2, *Cmd_Ci.GetLine( Line_ii++ ) );
		LvElem_ri.Active_b = Tmp_Ci=="available";
		y2debug( "Avail Line:%s", Tmp_Ci.c_str() );

		Line_ii += 4;
		Tmp_Ci = ExtractNthWord( 2, *Cmd_Ci.GetLine( Line_ii++ ) );
		y2debug( "Size Line:%s", Tmp_Ci.c_str() );
		Val_ii = 0;
		sscanf( Tmp_Ci.c_str(), "%lu", &Val_ii );
		LvElem_ri.Blocks_l = Val_ii*VgElem_ri.PeSize_l;

		LvElem_ri.Stripe_l = 1;
		Line_ii += 1;
		Tmp_Ci = *Cmd_Ci.GetLine(Line_ii++);
		if( Tmp_Ci.find( "Stripe" )!=string::npos )
		    {
		    y2debug( "Stripe Line:%s", Tmp_Ci.c_str() );
		    Tmp_Ci = ExtractNthWord( 1, Tmp_Ci );
		    sscanf( Tmp_Ci.c_str(), "%lu", &LvElem_ri.Stripe_l );
		    Line_ii += 1;
		    Tmp_Ci = *Cmd_Ci.GetLine(Line_ii++);
		    }
		y2debug( "Alloc Line:%s", Tmp_Ci.c_str() );
		Tmp_Ci = ExtractNthWord( 2, Tmp_Ci );
		LvElem_ri.AllocCont_b = Tmp_Ci.find( "next" )!=string::npos;
		LvList_C.push_back( LvElem_ri );
		list<LvInfo>::reverse_iterator Pix_Ci = LvList_C.rbegin();
		y2debug( "Append LV Name:%s VG Name:%s "
		         "Act:%d Wri:%d AlCnt:%d Stripe:%ld Blocks:%ld", 
		         LvElem_ri.Name_C.c_str(), LvElem_ri.VgName_C.c_str(),
		         LvElem_ri.Active_b, LvElem_ri.Writable_b,
		         LvElem_ri.AllocCont_b, LvElem_ri.Stripe_l,
		         LvElem_ri.Blocks_l );
		VgElem_ri.Lv_C.push_back( &(*Pix_Ci) );
		}
	    }
	Line_ii=0;
	while( Ok_bi && Line_ii<Cmd_Ci.NumLines() )
	    {
	    Tmp_Ci = *Cmd_Ci.GetLine( Line_ii++ );
	    if( Tmp_Ci.find( "PV Name" )==0 )
		{
		y2debug( "Name Line:%s", Tmp_Ci.c_str() );
		list<PvInfo>::iterator Pix_Ci = 
		    FindPv( ExtractNthWord( 3, Tmp_Ci ) );
		if( Pix_Ci!=PvList_C.end() )
		    {
		    Pix_Ci->VgName_C = VgElem_ri.Name_C;
		    Pix_Ci->Created_b = true;
		    Tmp_Ci = *Cmd_Ci.GetLine( Line_ii++ );
		    y2debug( "Active Line:%s", Tmp_Ci.c_str() );
		    Pix_Ci->Active_b = 
			ExtractNthWord( 2, Tmp_Ci )=="available";
		    Pix_Ci->Allocatable_b = true;
			ExtractNthWord( 4, Tmp_Ci )=="allocatable";
		    Tmp_Ci = *Cmd_Ci.GetLine( Line_ii++ );
		    y2debug( "Size Line:%s", Tmp_Ci.c_str() );
		    Val_ii = 0;
		    sscanf( ExtractNthWord(5,Tmp_Ci).c_str(), "%lu", &Val_ii );
		    Pix_Ci->Blocks_l = Val_ii*VgElem_ri.PeSize_l;
		    Val_ii = 0;
		    sscanf( ExtractNthWord(7,Tmp_Ci).c_str(), "%lu", &Val_ii );
		    Pix_Ci->Free_l = Val_ii*VgElem_ri.PeSize_l;
		    y2debug( "Changed PV Name:%s VG Name:%s Act:%d All:%d "
			     "Blocks:%ld Free:%ld", 
			     Pix_Ci->Name_C.c_str(), LvElem_ri.VgName_C.c_str(),
			     Pix_Ci->Active_b, Pix_Ci->Allocatable_b,
			     Pix_Ci->Blocks_l, Pix_Ci->Free_l );
		    VgElem_ri.Pv_C.push_back( &(*Pix_Ci) );
		    }
		}
	    }
	if( Ok_bi )
	    {
	    VgList_C.push_back( VgElem_ri );
	    y2milestone( "Append VG Name:%s Act:%d PE:%ld Blocks:%ld Free:%ld "
		     "Num PV:%d Num LV:%d", VgElem_ri.Name_C.c_str(),
		     VgElem_ri.Active_b, VgElem_ri.PeSize_l, VgElem_ri.Blocks_l,
		     VgElem_ri.Free_l, VgElem_ri.Pv_C.size(), 
		     VgElem_ri.Lv_C.size() );
	    }
	}
    }

void LvmAccess::UpdateDisk( list<PartInfo>& Part_Cv, const string& Disk_Cv )
    {
    list<PvInfo>::iterator Search_Ci;
    list<PartInfo>::iterator Pix_Ci;
    PvInfo PvElem_Ci;
    PvElem_Ci.Allocatable_b = false;
    PvElem_Ci.Active_b = false;
    PvElem_Ci.Created_b = false;
    y2debug( "Disk %s", Disk_Cv.c_str() );
    for( Pix_Ci=Part_Cv.begin(); Pix_Ci!=Part_Cv.end(); Pix_Ci++ )
	{
	y2debug( "1 Process: %s", Pix_Ci->Device_C.c_str() );
	if( Pix_Ci->PType_e!=PAR_TYPE_EXTENDED )
	    {
	    Search_Ci = FindPv( Pix_Ci->Device_C );
	    if( Search_Ci!=PvList_C.end() )
		{
		Search_Ci->PartitionId_i = Pix_Ci->Id_i;
		if( Search_Ci->Blocks_l!=Pix_Ci->Blocks_l )
		    {
		    Search_Ci->Blocks_l = Pix_Ci->Blocks_l;
		    Search_Ci->Free_l = Pix_Ci->Blocks_l;
		    }
		}
	    else
		{
		PvElem_Ci.Name_C = Pix_Ci->Device_C;
		PvElem_Ci.PartitionId_i = Pix_Ci->Id_i;
		PvElem_Ci.Blocks_l = Pix_Ci->Blocks_l;
		PvElem_Ci.Free_l = PvElem_Ci.Blocks_l;
		PvElem_Ci.RealDevList_C.clear();
		PvElem_Ci.RealDevList_C.push_back( PvElem_Ci.Name_C );
		SortIntoPvList( PvElem_Ci );
		}
	    }
	}
    list<PvInfo>::iterator Pv_Ci=PvList_C.begin();
    list<PartInfo>::iterator Search2_Ci=Part_Cv.begin();
    while( Pv_Ci!=PvList_C.end() )
	{
	y2debug( "2 Process: %s", Pv_Ci->Name_C.c_str() );
	if( Pv_Ci->Name_C.find(Disk_Cv)==0 )
	    {
	    Search2_Ci=Part_Cv.begin();
	    while( Search2_Ci!=Part_Cv.end() && 
	           Search2_Ci->Device_C!=Pv_Ci->Name_C )
		{
		Search2_Ci++;
		}
	    if( Search2_Ci==Part_Cv.end() )
		{
		y2debug( "Delete: %s", Pv_Ci->Name_C.c_str() );
		PvList_C.erase(Pv_Ci);
		}
	    else
		{
		Pv_Ci++;
		}
	    }
	else
	    {
	    Pv_Ci++;
	    }
	}
    if( Part_Cv.size()==0 )
	{
	DiskAccess Fdisk_Ci( Disk_Cv );
	PvElem_Ci.Name_C = Disk_Cv;
	PvElem_Ci.PartitionId_i = 0;
	PvElem_Ci.Blocks_l = PvElem_Ci.Free_l = Fdisk_Ci.CapacityInKb();
	PvElem_Ci.RealDevList_C.clear();
	PvElem_Ci.RealDevList_C.push_back( Disk_Cv );
	SortIntoPvList( PvElem_Ci );
	}
    }

void
LvmAccess::ScanForDisks()
    {
    bool Add_bi;
    string Line_Ci;
    ifstream File_Ci( "/proc/partitions" );
    PvInfo PvElem_ri;
    int Major_ii, Minor_ii;
    unsigned long Blocks_ui;
    string Device_Ci;

    getline( File_Ci, Line_Ci );
    while( File_Ci.good() )
	{
	std::istringstream Data_Ci( Line_Ci );
	Device_Ci.erase();
	Major_ii = Minor_ii = Blocks_ui = 0;
	Data_Ci >> Major_ii >> Minor_ii >> Blocks_ui >> Device_Ci;
	Device_Ci = "/dev/" + Device_Ci;
	y2debug( "Maj:%d Min:%d Blocks:%ld Device:%s", Major_ii, Minor_ii, 
	         Blocks_ui, Device_Ci.c_str() );
	Add_bi = Major_ii>0 && DiskAccess::IsKnownDevice( Device_Ci );
	if( Device_Ci.find( "/dev/md" )==0 )
	    {
	    Add_bi = true;
	    }
	Add_bi = Add_bi && Blocks_ui>10;
	if( Add_bi )
	    {
	    Add_bi = FindPv( Device_Ci )==PvList_C.end();
	    }
	y2debug( "Add:%d", Add_bi );
	if( Add_bi )
	    {
	    PvElem_ri.RealDevList_C.clear();
	    PvElem_ri.Created_b = false;
	    PvElem_ri.Active_b = false;
	    PvElem_ri.PartitionId_i = LVM_PART_ID;
	    PvElem_ri.Allocatable_b = false;
	    PvElem_ri.Name_C = Device_Ci;
	    PvElem_ri.RealDevList_C.push_back( PvElem_ri.Name_C );
	    PvElem_ri.Blocks_l = Blocks_ui;
	    PvElem_ri.Free_l = PvElem_ri.Blocks_l;
	    y2milestone( "Append PV Name: %s VG Name:%s Act:%d All:%d Crt:%d "
			 "Id:%x Blocks:%ld Free:%ld", PvElem_ri.Name_C.c_str(), 
			 PvElem_ri.VgName_C.c_str(), PvElem_ri.Active_b, 
			 PvElem_ri.Allocatable_b, PvElem_ri.Created_b, 
			 PvElem_ri.PartitionId_i, PvElem_ri.Blocks_l,
			 PvElem_ri.Free_l );
	    SortIntoPvList( PvElem_ri );
	    }
	getline( File_Ci, Line_Ci );
	}
    ProcessMd();
    y2debug( "End" );
    }

unsigned long long LvmAccess::UnitToValue( const string& Unit_Cv )
    {
    unsigned long long Ret_li = 1;
    y2debug( "Unit:%s", Unit_Cv.c_str() );
    if( Unit_Cv.size()>0 )
	{
	switch( toupper(Unit_Cv[0]) )
	    {
	    case 'T':
		Ret_li = 1024*1024*1024;
		break;
	    case 'G':
		Ret_li = 1024*1024;
		break;
	    case 'M':
		Ret_li = 1024;
		break;
	    case 'K':
	    default:
		break;
	    }
	}
    y2debug( "Ret:%lld", Ret_li );
    return( Ret_li );
    }

void
LvmAccess::ProcessMd()
    {
    string Tmp_Ci;
    MdAccess *Md_pCi = NULL;
    list<PvInfo>::iterator Pix_Ci = PvList_C.begin();

    while( Pix_Ci != PvList_C.end() )
	{
	if( Pix_Ci->RealDevList_C.size()==1 )
	    {
	    Tmp_Ci = Pix_Ci->Name_C;
	    if( Tmp_Ci.find( "/dev/md" )==0 || 
	        Tmp_Ci==DiskAccess::GetDiskName(Tmp_Ci) )
		{
		Pix_Ci->PartitionId_i = 0;
		y2debug( "Zero Id of %s", Pix_Ci->Name_C.c_str() );
		}
	    if( Tmp_Ci.find( "/dev/md" )==0 )
		{
		MdInfo Info_Ci;
		if( Md_pCi==NULL )
		    {
		    Md_pCi = new MdAccess();
		    }
		if( Md_pCi->GetMd( Tmp_Ci, Info_Ci ) && 
		    Info_Ci.DevList_C.size()>0 )
		    {
		    Pix_Ci->RealDevList_C.clear();
		    list<string>::iterator El_Ci = Info_Ci.DevList_C.begin();
		    while( El_Ci != Info_Ci.DevList_C.end() )
			{
			Pix_Ci->RealDevList_C.push_back( *El_Ci );
			El_Ci++;
			}
		    }
		}
	    }
	Pix_Ci++;
	}
    delete Md_pCi;
    }

unsigned LvmAccess::VgCnt()
    {
    return VgList_C.size();
    }

unsigned LvmAccess::LvCnt()
    {
    return LvList_C.size();
    }

unsigned LvmAccess::PvCnt()
    {
    return PvList_C.size();
    }

VgInfo LvmAccess::GetVg( int Idx_iv )
    {
    VgInfo Info_Ci;
    list<VgIntern>::iterator I_ii = VgList_C.begin();
    while( Idx_iv>0 && I_ii!=VgList_C.end() )
	{
	Idx_iv--;
	I_ii++;
	}
    if( I_ii!=VgList_C.end() )
	{
	Info_Ci = *I_ii;
	}
    return Info_Ci;
    }

void LvmAccess::ChangeId( int Idx_iv, int Id_iv )
    {
    list<PvInfo>::iterator I_ii = PvList_C.begin();
    while( Idx_iv>0 && I_ii!=PvList_C.end() )
	{
	Idx_iv--;
	I_ii++;
	}
    if( I_ii!=PvList_C.end() )
	{
	I_ii->PartitionId_i = Id_iv;
	}
    }

void LvmAccess::ChangePvVgName( const string& Device_Cv, const string& Name_Cv )
    {
    list<PvInfo>::iterator Pix_Ci = FindPv( Device_Cv );
    if( Pix_Ci!=PvList_C.end() )
	{
	Pix_Ci->VgName_C = Name_Cv;
	}
    }

PvInfo LvmAccess::GetPv( int Idx_iv )
    {
    PvInfo Info_Ci;
    list<PvInfo>::iterator I_ii = PvList_C.begin();
    while( Idx_iv>0 && I_ii!=PvList_C.end() )
	{
	Idx_iv--;
	I_ii++;
	}
    if( I_ii!=PvList_C.end() )
	{
	Info_Ci = *I_ii;
	}
    return Info_Ci;
    }

LvInfo LvmAccess::GetLv( int Idx_iv )
    {
    LvInfo Info_Ci;
    list<LvInfo>::iterator I_ii = LvList_C.begin();
    while( Idx_iv>0 && I_ii!=LvList_C.end() )
	{
	Idx_iv--;
	I_ii++;
	}
    if( I_ii!=LvList_C.end() )
	{
	Info_Ci = *I_ii;
	}
    return Info_Ci;
    }

list<LvmAccess::VgIntern>::iterator LvmAccess::FindVg( const string& Name_Cv )
    {
    list<VgIntern>::iterator Pix_Ci = VgList_C.begin();
    while( Pix_Ci!=VgList_C.end() && Pix_Ci->Name_C!=Name_Cv )
	{
	y2debug( "VG Name:%s Cur:%s", Name_Cv.c_str(), Pix_Ci->Name_C.c_str() );
	Pix_Ci++;
	}
    return( Pix_Ci );
    }

list<PvInfo>::iterator LvmAccess::FindPv( const string& Name_Cv )
    {
    list<PvInfo>::iterator Pix_Ci = PvList_C.begin();
    while( Pix_Ci!=PvList_C.end() && Pix_Ci->Name_C!=Name_Cv )
	{
	Pix_Ci++;
	}
    return( Pix_Ci );
    }

list<LvInfo>::iterator LvmAccess::FindLv( const string& Name_Cv )
    {
    list<LvInfo>::iterator Pix_Ci = LvList_C.begin();
    while( Pix_Ci!=LvList_C.end() && Pix_Ci->Name_C!=Name_Cv )
	{
	Pix_Ci++;
	}
    return( Pix_Ci );
    }

bool LvmAccess::CreatePv( const string& PvName_Cv, bool NewMeta_bv )
    {
    y2milestone( "PV Name:%s", PvName_Cv.c_str() );
    list<PvInfo>::iterator Pix_Ci = PvList_C.begin();
    while( Pix_Ci!=PvList_C.end() && Pix_Ci->Name_C!=PvName_Cv )
	{
	y2debug( "PV Name:%s", Pix_Ci->Name_C.c_str() );
	Pix_Ci++;
	}
    bool Ret_bi=false;
    PrepareLvmCmd();
    y2debug( "Pix:%p end:%p", &(*Pix_Ci), &(*PvList_C.end()) );
    if( Pix_Ci==PvList_C.end() )
	{
	y2error( "Device %s not found", PvName_Cv.c_str() );
	}
    if( Pix_Ci!=PvList_C.end() && 
        DiskAccess::GetDiskName( Pix_Ci->Name_C ) == Pix_Ci->Name_C )
	{
	char Buf_ti[1024];
	memset( Buf_ti, 0, sizeof(Buf_ti) );
	std::ofstream File_Ci( Pix_Ci->Name_C.c_str() );
	File_Ci.write( Buf_ti, sizeof(Buf_ti) );
	File_Ci.close();
	}
    string PvCmd_Ci = "/sbin/pvcreate -ff ";
    if( Lvm2() )
	{
	PvCmd_Ci += NewMeta_bv ? "-M2 " : "-M1 ";
	}
    PvCmd_Ci += PvName_Cv;
    Ret_bi = ExecuteLvmCmd( PvCmd_Ci );
    if( Ret_bi && Pix_Ci!=PvList_C.end() )
	{
	Pix_Ci->Created_b = true;
	Pix_Ci->Allocatable_b = true;
	Pix_Ci->Active_b = true;
	}
    return( Ret_bi );
    }

bool LvmAccess::ExtendVg( const string& VgName_Cv, const string& PvName_Cv )
    {
    list<PvInfo>::iterator Pv_Ci = PvList_C.begin();
    while( Pv_Ci!=PvList_C.end() && Pv_Ci->Name_C!=PvName_Cv )
	{
	Pv_Ci++;
	}
    if( Pv_Ci==PvList_C.end() )
	{
	y2error( "Device %s not found", PvName_Cv.c_str() );
	}
    bool Ret_bi=false;
    PrepareLvmCmd();
    string Cmd_Ci = (string)"vgextend ";
    if( !RunningFromSystem() )
	{
	Cmd_Ci += " -A n";
	}
    Cmd_Ci += ' ';
    Cmd_Ci += VgName_Cv;
    Cmd_Ci += ' ';
    if( Pv_Ci!=PvList_C.end() )
	{
	Cmd_Ci += Pv_Ci->Name_C;
	}
    Ret_bi = ExecuteLvmCmd( Cmd_Ci );
    if( Ret_bi )
	{
	ScanLvmStatus();
	}
    return( Ret_bi );
    }

bool LvmAccess::CreateVg( const string& VgName_Cv, unsigned long PeSize_lv,
                          bool NewMeta_bv, list<string>& Devices_Cv )
    {
    y2milestone( "LvmAccess::CreateVg VG Name:%s PESize:%ld DevLen:%d",
                 VgName_Cv.c_str(), PeSize_lv, Devices_Cv.size() );
    bool Ret_bi=false;
    PrepareLvmCmd();
    string Device_Ci = "/dev/";
    string Cmd_Ci = (string)"vgcreate";
    if( Lvm2() )
	{
	Cmd_Ci += NewMeta_bv ? " -M2" : " -M1";
	}
    if( !RunningFromSystem() )
	{
	Cmd_Ci += " -A n";
	}
    list<VgIntern>::iterator Vg_Ci = FindVg( VgName_Cv );
    if( Vg_Ci!=VgList_C.end() )
	{
	y2error( "Volume group %s already exists", VgName_Cv.c_str() );
	}
    Cmd_Ci += " -s ";
    Cmd_Ci += dec_string(PeSize_lv);
    Cmd_Ci += "k ";
    Cmd_Ci += VgName_Cv;
    Device_Ci += VgName_Cv;
    for( list<string>::iterator Pix_Ci=Devices_Cv.begin(); 
	 Pix_Ci!=Devices_Cv.end(); Pix_Ci++ )
	{
	Cmd_Ci += ' ';
	Cmd_Ci += *Pix_Ci;
	}
    Device_Ci += "/group";
    if( access( Device_Ci.c_str(), R_OK )==0 )
	{
	string Tmp_Ci = "rm -rf /dev/" + VgName_Cv;
	system( Tmp_Ci.c_str() );
	}
    Ret_bi = ExecuteLvmCmd( Cmd_Ci );
    if( Ret_bi )
	{
	ScanLvmStatus();
	}
    return( Ret_bi );
    }

bool LvmAccess::ShrinkVg( const string& VgName_Cv, const string& PvName_Cv )
    {
    list<PvInfo>::iterator Pv_Ci = PvList_C.begin();
    while( Pv_Ci!=PvList_C.end() && Pv_Ci->Name_C!=PvName_Cv )
	{
	Pv_Ci++;
	}
    list<VgIntern>::iterator Vg_Ci = FindVg( VgName_Cv );
    if( Pv_Ci==PvList_C.end() )
	{
	y2error( "Device %s not found", PvName_Cv.c_str() );
	}
    if( Vg_Ci==VgList_C.end() )
	{
	y2error( "Volume group %s not found", PvName_Cv.c_str() );
	}
    bool Ret_bi=false;
    PrepareLvmCmd();
    string Cmd_Ci = (string)"vgreduce ";
    if( !RunningFromSystem() )
	{
	Cmd_Ci += " -A n ";
	}
    Cmd_Ci += VgName_Cv;
    Cmd_Ci += " ";
    if( Pv_Ci!=PvList_C.end() )
	{
	Cmd_Ci += Pv_Ci->Name_C;
	}
    Ret_bi = ExecuteLvmCmd( Cmd_Ci );
    if( Ret_bi && Pv_Ci!=PvList_C.end() )
	{
	ScanLvmStatus();
	Pv_Ci->VgName_C.erase();
	}
    return( Ret_bi );
    }

bool LvmAccess::DeleteVg( const string& VgName_C )
    {
    list<VgIntern>::iterator Vg_Ci = VgList_C.begin();
    int Idx_iv = 0;
    while( Vg_Ci!=VgList_C.end() && Vg_Ci->Name_C!=VgName_C )
	{
	Idx_iv++;
	Vg_Ci++;
	}
    bool Ret_bi=false;
    PrepareLvmCmd();
    if( Vg_Ci==VgList_C.end() )
	{
	y2error( "Volume group %s not found", VgName_C.c_str() );
	}
    if( Vg_Ci!=VgList_C.end() && !Vg_Ci->Active_b || 
        ChangeActive( Vg_Ci->Name_C, false ) )
	{
	Ret_bi = ExecuteLvmCmd( "/sbin/vgremove " + Vg_Ci->Name_C );
	}
    if( Ret_bi && Vg_Ci!=VgList_C.end() )
	{
	for( list<PvInfo>::iterator Pv_Ci=PvList_C.begin(); 
	     Pv_Ci!=PvList_C.end(); Pv_Ci++ )
	    {
	    if( Pv_Ci->VgName_C==Vg_Ci->Name_C )
		{
		Pv_Ci->VgName_C.erase();
		}
	    }
	VgList_C.erase( Vg_Ci );
	}
    return( Ret_bi );
    }


bool LvmAccess::CreateLv( const string& LvName_Cv, const string& VgName_Cv,
                          unsigned long Size_lv, unsigned long Stripe_lv,
                          unsigned long StripeSize_lv )
    {
    y2milestone( "LvmAccess::CreateLv LV Name:%s VG Name:%s Size:%ld Stripe:%ld",
	         LvName_Cv.c_str(), VgName_Cv.c_str(), Size_lv, Stripe_lv );
    list<VgIntern>::iterator Vg_Ci = FindVg( VgName_Cv );
    bool Ret_bi=false;
    PrepareLvmCmd();
    if( Vg_Ci==VgList_C.end() )
	{
	y2error( "Volume group %s not found", VgName_Cv.c_str() );
	}
    string Tmp_Ci = "lvcreate";
    if( !RunningFromSystem() )
	{
	Tmp_Ci += " -A n";
	}
    if( Stripe_lv>1 )
	{
	Tmp_Ci += " -i ";
	Tmp_Ci += dec_string(Stripe_lv);
	if( StripeSize_lv>0 )
	    {
	    Tmp_Ci += " -I ";
	    Tmp_Ci += dec_string(StripeSize_lv);
	    }
	}
    Tmp_Ci += " -n ";
    string Name_Ci = LvName_Cv;
    if( Name_Ci.find( '/' )!=string::npos )
	{
	Name_Ci.erase( 0, Name_Ci.rfind( '/' )+1 );
	}
    Tmp_Ci += Name_Ci;
    Tmp_Ci += " -l ";
    unsigned long Size_li = 123;
    if( Vg_Ci!=VgList_C.end() )
	{
	Size_li = (Size_lv+Vg_Ci->PeSize_l-1)/Vg_Ci->PeSize_l;
	y2debug( "Size:%lu Free:%lu", Size_li, Vg_Ci->Free_l );
	if( Size_li > Vg_Ci->Free_l/Vg_Ci->PeSize_l )
	    {
	    unsigned long Diff_li = Size_li - Vg_Ci->Free_l/Vg_Ci->PeSize_l;
	    y2debug( "Diff:%lu", Diff_li );
	    if( Diff_li<=10 || Diff_li<Vg_Ci->Blocks_l/Vg_Ci->PeSize_l/50)
		{
		Size_li = Vg_Ci->Free_l/Vg_Ci->PeSize_l;
		y2debug( "New Size:%lu", Size_li );
		}
	    }
	}
    Tmp_Ci += dec_string(Size_li);
    Tmp_Ci += " ";
    Tmp_Ci += VgName_Cv;

    Ret_bi = ExecuteLvmCmd( Tmp_Ci );
    if( Ret_bi )
	{
	ScanLvmStatus();
	}
    return( Ret_bi );
    }

bool LvmAccess::DeleteLv( const string& LvName_Cv )
    {
    y2milestone( "LvmAccess::DeleteLv LV Name:%s", LvName_Cv.c_str() );
    bool Ret_bi = false;
    PrepareLvmCmd();
    string Cmd_Ci = "lvremove -f ";
    if( !RunningFromSystem() )
	{
	Cmd_Ci += "-A n ";
	}
    Cmd_Ci += LvName_Cv;
    Ret_bi = ExecuteLvmCmd( Cmd_Ci );
    if( Ret_bi )
	{
	list<LvInfo>::iterator Pix_Ci;
	if( (Pix_Ci=FindLv( LvName_Cv ))!=LvList_C.end() )
	    {
	    LvList_C.erase( Pix_Ci );
	    }
	else
	    {
	    y2error( "Logical volume %s not found", LvName_Cv.c_str() );
	    }
	ScanLvmStatus();
	}
    return( Ret_bi );
    }

bool LvmAccess::ChangeLvSize( const string& LvName_Cv, unsigned long Size_lv )
    {
    y2milestone( "LvmAccess::ChangeLvSize LV Name:%s Size:%ld",
                 LvName_Cv.c_str(), Size_lv );
    bool Ret_bi = false;
    list<LvInfo>::iterator Lv_Ci = FindLv( LvName_Cv );
    string VgName_Ci = LvName_Cv;
    VgName_Ci.erase( 0, VgName_Ci.find( "/", 1 )+1 );
    VgName_Ci.erase( VgName_Ci.rfind( "/" ) );
    y2debug( "VgName:%s", VgName_Ci.c_str() );
    list<VgIntern>::iterator Vg_Ci = FindVg( VgName_Ci );
    if( Vg_Ci == VgList_C.end() )
	{
	y2error( "Volume group %s not found", VgName_Ci.c_str() );
	}
    if( Lv_Ci == LvList_C.end() )
	{
	y2error( "Logical volume %s not found", LvName_Cv.c_str() );
	}
    unsigned long PeSize_li = 4096;
    if( Vg_Ci != VgList_C.end() )
	{
	PeSize_li = Vg_Ci->PeSize_l;
	}
    PrepareLvmCmd();
    unsigned long NewPe_li = (Size_lv+PeSize_li-1)/PeSize_li;
    unsigned long OldPe_li = 0;
    if( Lv_Ci!=LvList_C.end() )
	{
	OldPe_li = (Lv_Ci->Blocks_l+PeSize_li-1)/PeSize_li;
	y2debug( "Size:%ld Blocks:%ld", Size_lv, Lv_Ci->Blocks_l );
	}
    y2debug( "NewPe:%ld OldPe:%ld", NewPe_li, OldPe_li );
    if( NewPe_li < OldPe_li )
	{
	string Tmp_Ci = "lvreduce -f ";
	if( !RunningFromSystem() )
	    {
	    Tmp_Ci += "-A n ";
	    }
	Tmp_Ci += "-l ";
	Tmp_Ci += dec_string(NewPe_li);
	Tmp_Ci += " ";
	Tmp_Ci += LvName_Cv;
	Ret_bi = ExecuteLvmCmd( Tmp_Ci );
	if( Ret_bi )
	    {
	    ScanLvmStatus();
	    }
	}
    else if( NewPe_li > OldPe_li )
	{
	string Tmp_Ci = "lvextend ";
	if( !RunningFromSystem() )
	    {
	    Tmp_Ci += "-A n ";
	    }
	Tmp_Ci += "-l ";
	Tmp_Ci += dec_string(NewPe_li);
	Tmp_Ci += " ";
	Tmp_Ci += LvName_Cv;
	Ret_bi = ExecuteLvmCmd( Tmp_Ci );
	if( Ret_bi )
	    {
	    ScanLvmStatus();
	    }
	}
    else
	{
	Ret_bi = true;
	}
    return( Ret_bi );
    }

bool LvmAccess::ChangeActive( const string& Name_Cv, bool Active_bv )
    {
    list<VgIntern>::iterator Vg_Ci = VgList_C.begin();
    while( Vg_Ci!=VgList_C.end() && Vg_Ci->Name_C!=Name_Cv )
	{
	Vg_Ci++;
	}
    bool Ret_bi=false;
    if( Vg_Ci == VgList_C.end() )
	{
	y2error( "Volume group %s not found", Name_Cv.c_str() );
	}
    PrepareLvmCmd();
    if( Vg_Ci!=VgList_C.end() && Vg_Ci->Active_b==Active_bv )
	{
	Ret_bi = true;
	}
    else
	{
	string Tmp_Ci = "vgchange -a ";
	Tmp_Ci += Active_bv?'y':'n';
	Tmp_Ci += ' ';
	if( Vg_Ci!=VgList_C.end() )
	    {
	    Tmp_Ci += Vg_Ci->Name_C;
	    }
	Ret_bi = ExecuteLvmCmd( Tmp_Ci );
	if( Ret_bi )
	    {
	    if( Active_bv )
		{
		if( !Lvm2() )
		    {
		    ScanLvmStatus();
		    }
		}
	    else
		{
		Vg_Ci->Active_b = false;
		}
	    }
	}
    return( Ret_bi );
    }

string 
LvmAccess::GetPvDevicename( const string& VgName_Cv, const string& FDev_Cv,
                            const string& Dev_Cv, int Num_iv, int Mp_iv )
    {
    string Ret_Ci = "/dev/" + Dev_Cv;
    DIR *Dir_pri;
    struct dirent *Entry_pri;
    string DirName_Ci = "/proc/lvm/VGs/" + VgName_Cv + "/PVs";
    bool Found_bi = false;

    y2milestone( "VG:%s FDev:%s Dev:%s Num:%d MP:%d", VgName_Cv.c_str(), 
                 FDev_Cv.c_str(), Dev_Cv.c_str(), Num_iv, Mp_iv );
    if( (Dir_pri=opendir( DirName_Ci.c_str() ))!=NULL )
	{
	while( !Found_bi && (Entry_pri=readdir( Dir_pri ))!=NULL )
	    {
	    string Name_Ci = Entry_pri->d_name;
	    string Line_Ci;
	    if( Name_Ci.find( FDev_Cv )==0 )
		{
		string Tmp_Ci = DirName_Ci + "/" + Name_Ci;
		AsciiFile File_Ci( Tmp_Ci.c_str() );
		if( SearchFile( File_Ci, "^number:", Line_Ci ) )
		    {
		    Tmp_Ci = ExtractNthWord( 1, Line_Ci );
		    if( atoi( Tmp_Ci.c_str() )==Num_iv )
			{
			SearchFile( File_Ci, "^name:", Line_Ci );
			Ret_Ci = ExtractNthWord( 1, Line_Ci );
			Found_bi = true;
			}
		    }
		if( Mp_iv>0 )
		    {
		    int Line_ii = 0;
		    if( SearchFile( File_Ci, "^Path", Line_Ci, Line_ii ))
			{
			Line_Ci = File_Ci[Line_ii+Mp_iv+1];
			y2milestone( "Mp Line %s", Line_Ci.c_str() );
			Ret_Ci = ExtractNthWord( 4, Line_Ci );
			Found_bi = true;
			}
		    }
		}
	    }
	closedir( Dir_pri );
	}
    y2milestone( "Ret:%s", Ret_Ci.c_str() );
    return( Ret_Ci );
    }

void LvmAccess::ScanLvmStatus()
    {
    if( Lvm2() )
	{
	ScanVgdisplayOutput();
	}
    else
	{
	ScanProcLvm();
	}
    }

void LvmAccess::ScanVgdisplayOutput()
    {
    string Line_Ci;
    VgIntern VgElem_ri;
    PvInfo PvElem_ri;
    LvInfo LvElem_ri;
    string Tmp_Ci;
    SystemCmd Cmd_Ci;
    int Cnt_ii;

    Cmd_Ci.Execute( "LC_ALL=POSIX /sbin/vgdisplay -v" );
    Cnt_ii = Cmd_Ci.NumLines();
    int I_ii = 0;
    while( I_ii<Cnt_ii )
	{
	Line_Ci = *Cmd_Ci.GetLine( I_ii++ );
	if( Line_Ci.find( "Volume group" )!=string::npos )
	    {
	    VgElem_ri.Pv_C.clear();
	    VgElem_ri.Lv_C.clear();
	    VgElem_ri.Lvm2_b = false;
	    VgElem_ri.Active_b = true;
	    Line_Ci = *Cmd_Ci.GetLine( I_ii++ );
	    while( Line_Ci.find( "Logical volume" )==string::npos &&
	           Line_Ci.find( "Physical volume" )==string::npos &&
		   I_ii<Cnt_ii )
		{
		if( Line_Ci.find( "VG Name" )!=string::npos )
		    {
		    VgElem_ri.Name_C = ExtractNthWord( 2, Line_Ci );
		    }
		if( Line_Ci.find( "Format" )!=string::npos )
		    {
		    VgElem_ri.Lvm2_b = ExtractNthWord( 1, Line_Ci )=="lvm2";
		    }
		if( Line_Ci.find( "PE Size" )!=string::npos )
		    {
		    double Val_fi = 0.0;
		    Tmp_Ci = ExtractNthWord( 2, Line_Ci );
		    sscanf( Tmp_Ci.c_str(), "%lf", &Val_fi );
		    Tmp_Ci = ExtractNthWord( 3, Line_Ci );
		    switch( *Tmp_Ci.c_str() )
			{
			case 'M':
			case 'm':
			    Val_fi = Val_fi * 1024;
			    break;
			case 'G':
			case 'g':
			    Val_fi = Val_fi * 1024 * 1024;
			    break;
			case 'T':
			case 't':
			    Val_fi = Val_fi * 1024 * 1024 * 1024;
			    break;
			default:
			    break;
			}
		    VgElem_ri.PeSize_l = (unsigned long)Val_fi;
		    }
		if( Line_Ci.find( "Total PE" )!=string::npos )
		    {
		    Tmp_Ci = ExtractNthWord( 2, Line_Ci );
		    sscanf( Tmp_Ci.c_str(), "%ld", &VgElem_ri.Blocks_l );
		    VgElem_ri.Blocks_l *= VgElem_ri.PeSize_l;
		    }
		if( Line_Ci.find( "Alloc PE" )!=string::npos )
		    {
		    Tmp_Ci = ExtractNthWord( 4, Line_Ci );
		    unsigned long Val_li;
		    sscanf( Tmp_Ci.c_str(), "%ld", &Val_li );
		    Val_li *= VgElem_ri.PeSize_l;
		    VgElem_ri.Free_l = VgElem_ri.Blocks_l - Val_li;
		    }
		Line_Ci = *Cmd_Ci.GetLine( I_ii++ );
		}
	    LvElem_ri.Name_C.erase();
	    LvElem_ri.VgName_C = VgElem_ri.Name_C;
	    LvElem_ri.Active_b = true;
	    LvElem_ri.Writable_b = true;
	    LvElem_ri.Stripe_l = 1;
	    while( Line_Ci.find( "Physical volume" )==string::npos &&
		   I_ii<Cnt_ii )
		{
		if( Line_Ci.find( "Current LE" )!=string::npos )
		    {
		    Tmp_Ci = ExtractNthWord( 2, Line_Ci );
		    sscanf( Tmp_Ci.c_str(), "%ld", &LvElem_ri.Blocks_l );
		    LvElem_ri.Blocks_l *= VgElem_ri.PeSize_l;
		    }
		if( Line_Ci.find( "LV Write Access" )!=string::npos )
		    {
		    LvElem_ri.Writable_b = ExtractNthWord( 3, Line_Ci ) == 
		                           "read/write";
		    }
		if( Line_Ci.find( "LV Name" )!=string::npos )
		    {
		    LvElem_ri.Name_C = ExtractNthWord( 2, Line_Ci );
		    }
		if( Line_Ci.find( "Allocation" )!=string::npos )
		    {
		    LvElem_ri.AllocCont_b = ExtractNthWord( 1, Line_Ci ) == 
		                            "next";
		    }
		if( Line_Ci.find( "Logical volume" )!=string::npos &&
		    LvElem_ri.Name_C.size()>0 )
		    {
		    LvIntoList( VgElem_ri, LvList_C, LvElem_ri );
		    LvElem_ri.Name_C.erase();
		    }
		Line_Ci = *Cmd_Ci.GetLine( I_ii++ );
		}
	    if( LvElem_ri.Name_C.size()>0 )
		{
		LvIntoList( VgElem_ri, LvList_C, LvElem_ri );
		LvElem_ri.Name_C.erase();
		}
	    PvElem_ri.Name_C.erase();
	    PvElem_ri.RealDevList_C.clear();
	    PvElem_ri.Allocatable_b = true;
	    PvElem_ri.Active_b = true;
	    PvElem_ri.Created_b = true;
	    PvElem_ri.Multipath_b = false;
	    PvElem_ri.PartitionId_i = LVM_PART_ID;
	    PvElem_ri.VgName_C = VgElem_ri.Name_C;
	    while( I_ii<Cnt_ii && Line_Ci.find( "Volume group" )==string::npos )
		{
		if( Line_Ci.find( "PV Status" )!=string::npos )
		    {
		    PvElem_ri.Allocatable_b = ExtractNthWord( 2, Line_Ci ) == 
					      "allocatable";
		    }
		if( Line_Ci.find( "Total PE" )!=string::npos )
		    {
		    Tmp_Ci = ExtractNthWord( 5, Line_Ci );
		    sscanf( Tmp_Ci.c_str(), "%ld", &PvElem_ri.Blocks_l );
		    PvElem_ri.Blocks_l *= VgElem_ri.PeSize_l;
		    Tmp_Ci = ExtractNthWord( 7, Line_Ci );
		    sscanf( Tmp_Ci.c_str(), "%ld", &PvElem_ri.Free_l );
		    PvElem_ri.Free_l *= VgElem_ri.PeSize_l;
		    }
		if( Line_Ci.find( "PV Name" )!=string::npos )
		    {
		    if( PvElem_ri.RealDevList_C.size()>0 )
			{
			PvIntoList( VgElem_ri, PvList_C, PvElem_ri );
			PvElem_ri.Name_C.erase();
			PvElem_ri.RealDevList_C.clear();
			}
		    PvElem_ri.Name_C = ExtractNthWord( 2, Line_Ci );
		    PvElem_ri.RealDevList_C.push_back( PvElem_ri.Name_C );
		    }
		Line_Ci = *Cmd_Ci.GetLine( I_ii++ );
		}
	    if( PvElem_ri.RealDevList_C.size()>0 )
		{
		PvIntoList( VgElem_ri, PvList_C, PvElem_ri );
		PvElem_ri.Name_C.erase();
		PvElem_ri.RealDevList_C.clear();
		}
	    list<VgIntern>::iterator Pix_Ci;
	    if( (Pix_Ci=FindVg( VgElem_ri.Name_C ))!=VgList_C.end() )
		{
		*Pix_Ci=VgElem_ri;
		y2debug( "Replace VG Name:%s", VgElem_ri.Name_C.c_str() );
		}
	    else
		{
		VgList_C.push_back( VgElem_ri );
		y2debug( "Append VG Name:%s", VgElem_ri.Name_C.c_str() );
		}
	    y2debug( "Lvm2:%d Act:%d PE:%ld Blocks:%ld Free:%ld Num PV:%d "
	             "Num LV:%d", VgElem_ri.Lvm2_b, VgElem_ri.Active_b, 
		     VgElem_ri.PeSize_l, VgElem_ri.Blocks_l,
		     VgElem_ri.Free_l, VgElem_ri.Pv_C.size(),
		     VgElem_ri.Lv_C.size() );
	    if( Line_Ci.find( "Volume group" )!=string::npos )
		{
		I_ii--;
		}
	    }
	}
    }

void LvmAccess::PvIntoList( VgIntern& VgElem_rr, list<PvInfo>& PvList_Cr,
                            const PvInfo& PvElem_rv )
    {
    list<PvInfo>::iterator Pix_Ci = SortIntoPvList( PvElem_rv );
    y2debug( "VG Name:%s Act:%d All:%d Crt:%d Id:%x Blocks:%ld Free:%ld", 
	     PvElem_rv.VgName_C.c_str(), PvElem_rv.Active_b, 
	     PvElem_rv.Allocatable_b, PvElem_rv.Created_b, 
	     PvElem_rv.PartitionId_i, PvElem_rv.Blocks_l, PvElem_rv.Free_l );
    VgElem_rr.Pv_C.push_back( &(*Pix_Ci) );
    }

void LvmAccess::LvIntoList( VgIntern& VgElem_rr, list<LvInfo>& LvList_Cr,
                            const LvInfo& LvElem_rv )
    {
    y2debug( "before FindLv:%s", LvElem_rv.Name_C.c_str() );
    list<LvInfo>::iterator Pix_Ci;
    if( (Pix_Ci=FindLv( LvElem_rv.Name_C ))!=LvList_Cr.end() )
	{
	*Pix_Ci=LvElem_rv;
	y2debug( "Replace LV Name:%s", LvElem_rv.Name_C.c_str() );
	}
    else
	{
	LvList_Cr.push_back( LvElem_rv );
	Pix_Ci = FindLv( LvElem_rv.Name_C );
	y2debug( "Append LV Name:%s", LvElem_rv.Name_C.c_str() );
	}
    y2debug( "VG Name:%s AlCnt:%d Act:%d Wri:%d Stripe:%ld Blocks:%ld", 
             LvElem_rv.VgName_C.c_str(), LvElem_rv.Active_b, 
	     LvElem_rv.AllocCont_b, LvElem_rv.Writable_b, 
	     LvElem_rv.Stripe_l, LvElem_rv.Blocks_l );
    VgElem_rr.Lv_C.push_back( &(*Pix_Ci) );
    }

void LvmAccess::ScanProcLvm()
    {
    std::ifstream File_Ci( "/proc/lvm/global" );
    string Line_Ci;
    VgIntern VgElem_ri;
    PvInfo PvElem_ri;
    LvInfo LvElem_ri;
    string Tmp_Ci;

    getline( File_Ci, Line_Ci );
    while( File_Ci.good() )
	{
	if( Line_Ci.find( "VG:" )==0 )
	    {
	    VgElem_ri.Pv_C.clear();
	    VgElem_ri.Lv_C.clear();
	    VgElem_ri.Lvm2_b = false;
	    Tmp_Ci = ExtractNthWord( 1, Line_Ci );
	    if( Tmp_Ci.find('I')==0 )
		{
		Tmp_Ci.erase( 0, 1 );
		VgElem_ri.Active_b = false;
		}
	    else
		{
		VgElem_ri.Active_b = true;
		}
	    VgElem_ri.Name_C = Tmp_Ci;
	    Tmp_Ci = Line_Ci;
	    Tmp_Ci.erase( 0, Tmp_Ci.find( "PE Size:" )+8 );
	    VgElem_ri.PeSize_l = 0;
	    sscanf( Tmp_Ci.c_str(), "%ld", &VgElem_ri.PeSize_l );
	    getline( File_Ci, Tmp_Ci );
	    Tmp_Ci.erase( 0, Tmp_Ci.find( "]:" )+2 );
	    VgElem_ri.Blocks_l = 0;
	    sscanf( Tmp_Ci.c_str(), "%ld", &VgElem_ri.Blocks_l );
	    Tmp_Ci.erase( 0, Tmp_Ci.find( "used" )+4 );
	    VgElem_ri.Free_l = 0;
	    sscanf( Tmp_Ci.c_str(), "%ld", &VgElem_ri.Free_l );

	    getline( File_Ci, Line_Ci );
	    Tmp_Ci = ExtractNthWord( 0, Line_Ci );
	    bool Start_b = false;
	    int Num_ii = 0;
	    while( File_Ci.good() && Tmp_Ci.find( "LV" )!=0 )
		{
		Start_b = Start_b || Tmp_Ci.find( "PV" )==0;
		string ShortName_Ci;
		if( Start_b )
		    {
		    Num_ii++;
		    PvElem_ri.RealDevList_C.clear();
		    PvElem_ri.VgName_C = VgElem_ri.Name_C;
		    PvElem_ri.Created_b = true;
		    PvElem_ri.Active_b = false;
		    PvElem_ri.PartitionId_i = LVM_PART_ID;
		    Line_Ci.erase( 0, Line_Ci.find( '[' )+1 );
		    PvElem_ri.Active_b = Line_Ci.find( 'A' )==0;
		    Line_Ci.erase( 0, 1 );
		    PvElem_ri.Allocatable_b = false;
		    PvElem_ri.Multipath_b = false;
		    PvElem_ri.Allocatable_b = Line_Ci.find( 'A' )==0;
		    Line_Ci.erase( 0, Line_Ci.find( ']' )+1 );
		    ShortName_Ci = ExtractNthWord( 0, Line_Ci );
		    PvElem_ri.Name_C =
			GetPvDevicename( PvElem_ri.VgName_C, ShortName_Ci,
			                 ShortName_Ci, Num_ii, 0 );
		    PvElem_ri.RealDevList_C.push_back( PvElem_ri.Name_C );
		    Tmp_Ci = ExtractNthWord( 1, Line_Ci );
		    PvElem_ri.Blocks_l = 0;
		    sscanf( Tmp_Ci.c_str(), "%ld", &PvElem_ri.Blocks_l );
		    Tmp_Ci = ExtractNthWord( 5, Line_Ci );
		    PvElem_ri.Free_l = 0;
		    sscanf( Tmp_Ci.c_str(), "%ld", &PvElem_ri.Free_l );
		    PvIntoList( VgElem_ri, PvList_C, PvElem_ri );
		    }
		getline( File_Ci, Line_Ci );
		y2milestone( "MP Line %s", Line_Ci.c_str() );
		int Mp_ii = 1;
		while( File_Ci.good() && Line_Ci.find( "+--" )!=string::npos )
		    {
		    PvElem_ri.Name_C =
			GetPvDevicename( PvElem_ri.VgName_C, ShortName_Ci,
			                 ExtractNthWord( 1, Line_Ci ), Num_ii,
					 Mp_ii );
		    PvElem_ri.Multipath_b = true;
		    PvElem_ri.RealDevList_C.clear();
		    PvElem_ri.RealDevList_C.push_back( PvElem_ri.Name_C );
		    y2milestone( "MP add Name:%s", PvElem_ri.Name_C.c_str() );
		    PvIntoList( VgElem_ri, PvList_C, PvElem_ri );
		    getline( File_Ci, Line_Ci );
		    Mp_ii++;
		    }
		Tmp_Ci = ExtractNthWord( 0, Line_Ci );
		}
	    while( File_Ci.good() && Tmp_Ci.find( "VG:" )!=0 )
		{
		y2debug( "Scan LV Tmp:%s Line:%s", Tmp_Ci.c_str(),
		         Line_Ci.c_str() );
		if( Line_Ci.find( '[' )!=string::npos )
		    {
		    Line_Ci.erase( 0, Line_Ci.find( '[' )+1 );
		    LvElem_ri.VgName_C = VgElem_ri.Name_C;
		    LvElem_ri.Active_b = Line_Ci.find( 'A' )==0;
		    Line_Ci.erase( 0, 1 );
		    LvElem_ri.Writable_b = Line_Ci.find( 'W' )==0;
		    Line_Ci.erase( 0, 1 );
		    LvElem_ri.AllocCont_b = Line_Ci[0] != 'D';
		    Line_Ci.erase( 0, 1 );
		    LvElem_ri.Stripe_l = 1;
		    if( Line_Ci.find( 'S' )==0 )
			{
			Line_Ci.erase( 0, 1 );
			sscanf( Line_Ci.c_str(), "%ld", &LvElem_ri.Stripe_l );
			}
		    Line_Ci.erase( 0, Line_Ci.find( ']' )+1 );
		    Tmp_Ci = ExtractNthWord( 0, Line_Ci );
		    LvElem_ri.Name_C = "/dev/";
		    LvElem_ri.Name_C += LvElem_ri.VgName_C + '/' + Tmp_Ci;
		    LvElem_ri.Blocks_l = 0;
		    Tmp_Ci = ExtractNthWord( 1, Line_Ci );
		    sscanf( Tmp_Ci.c_str(), "%ld", &LvElem_ri.Blocks_l );
		    Tmp_Ci = ExtractNthWord( 5, Line_Ci );
		    LvIntoList( VgElem_ri, LvList_C, LvElem_ri );
		    }
		getline( File_Ci, Line_Ci );
		Tmp_Ci = ExtractNthWord( 0, Line_Ci );
		y2debug( "Append LV Name:%s", LvElem_ri.Name_C.c_str() );
		}
	    list<VgIntern>::iterator Pix_Ci;
	    if( (Pix_Ci=FindVg( VgElem_ri.Name_C ))!=VgList_C.end() )
		{
		*Pix_Ci=VgElem_ri;
		y2debug( "Replace VG Name:%s", VgElem_ri.Name_C.c_str() );
		}
	    else
		{
		VgList_C.push_back( VgElem_ri );
		y2debug( "Append VG Name:%s", VgElem_ri.Name_C.c_str() );
		}
	    y2debug( "Act:%d PE:%ld Blocks:%ld Free:%ld Num PV:%d Num LV:%d",
		     VgElem_ri.Active_b, VgElem_ri.PeSize_l, VgElem_ri.Blocks_l,
		     VgElem_ri.Free_l, VgElem_ri.Pv_C.size(),
		     VgElem_ri.Lv_C.size() );
	    }
	if( Line_Ci.find( "VG:" ) != 0 )
	    {
	    getline( File_Ci, Line_Ci );
	    }
	}
    }

list<PvInfo>::iterator LvmAccess::SortIntoPvList( const PvInfo& PvElem_rv )
    {
    y2debug( "Name:%s", PvElem_rv.Name_C.c_str() );
    list<PvInfo>::iterator Pix_Ci;
    if( (Pix_Ci=FindPv( PvElem_rv.Name_C ))!=PvList_C.end() )
	{
	*Pix_Ci=PvElem_rv;
	y2debug( "Replace PV Name%s", PvElem_rv.Name_C.c_str() );
	if( PvElem_rv.RealDevList_C.size()>0 )
	    {
	    y2debug( "first RealDev:%s last RealDev:%s",
		     PvElem_rv.RealDevList_C.front().c_str(),
		     PvElem_rv.RealDevList_C.back().c_str() );
	    }
	}
    else
	{
	string Disk_Ci = DiskAccess::GetDiskName( PvElem_rv.Name_C );
	int Num_ii = DiskAccess::GetPartNumber( PvElem_rv.Name_C );
	Pix_Ci = PvList_C.begin();
	while( Pix_Ci!=PvList_C.end() && Pix_Ci->Name_C<Disk_Ci )
	    {
	    Pix_Ci++;
	    }
	while( Pix_Ci!=PvList_C.end() && Pix_Ci->Name_C.find(Disk_Ci)==0 &&
	       DiskAccess::GetPartNumber( Pix_Ci->Name_C )<Num_ii )
	    {
	    Pix_Ci++;
	    }
	if( Pix_Ci!=PvList_C.end() )
	    {
	    y2debug( "Insert Before PV Name:%s", Pix_Ci->Name_C.c_str() );
	    PvList_C.insert( Pix_Ci, PvElem_rv );
	    }
	else
	    {
	    PvList_C.push_back( PvElem_rv );
	    y2debug( "Append PV Name:%s", PvElem_rv.Name_C.c_str() );
	    }
	if( PvElem_rv.RealDevList_C.size()>0 )
	    {
	    y2debug( "PV first RealDev:%s last RealDev:%s",
		     PvElem_rv.RealDevList_C.front().c_str(),
		     PvElem_rv.RealDevList_C.back().c_str() );
	    }
	Pix_Ci = FindPv( PvElem_rv.Name_C );
	}
    return( Pix_Ci );
    }

void LvmAccess::PrepareLvmCmd()
    {
    LvmRet_i = 1000;
    LvmOutput_C = "Internal YaST Error";
    }

bool LvmAccess::ExecuteLvmCmd( const string& Cmd_Cv )
    {
    vector<string> Plex_Ci;
    AsciiFile Old_Ci;
    int Idx_ii;
    CmdLine_C  = Cmd_Cv;
    if( !Lvm2() )
	{
	Old_Ci.LoadFile( "/proc/lvm/global" );
	if( (Idx_ii=Old_Ci.Find( 0, (string)"^Global:" )) )
	    {
	    Old_Ci.Delete( Idx_ii, 1 );
	    }
	}
    string Cmd_Ci = ExtractNthWord( 0, Cmd_Cv );
    if( Cmd_Ci == "/sbin/pvcreate" )
	{
	CmdLine_C = "echo y | " + CmdLine_C;
	}
    y2milestone( "lvm cmd execute:%s", CmdLine_C.c_str() );
    LvmCmd_C.Execute( CmdLine_C );
    LvmRet_i = LvmCmd_C.Retcode();
    if( LvmOutput_C.find( "ERROR" )!=string::npos )
	{
	LvmRet_i = 999;
	}
    if( LvmRet_i == 0 && !Lvm2() && 
        Cmd_Ci!="/sbin/pvcreate" && Cmd_Ci!="/sbin/vgremove" )
	{
	AsciiFile New_Ci( "/proc/lvm/global" );
	if( (Idx_ii=New_Ci.Find( 0, (string)"^Global:" )) )
	    {
	    New_Ci.Delete( Idx_ii, 1 );
	    }
	if( Old_Ci.DifferentLine( New_Ci )==-1 )
	    {
	    LvmRet_i = 998;
	    }
	}
    LvmCmd_C.GetStdout( Plex_Ci );
    if( Plex_Ci.size()>0 )
	{
	LvmOutput_C = Plex_Ci[0];
	}
    else
	{
	LvmOutput_C.erase();
	}
    y2milestone( "lvm cmd output:%s", LvmOutput_C.c_str() );
    return( LvmRet_i==0 );
    }

LvmAccess::VgIntern::operator VgInfo()
    {
    VgInfo New_Ci;
    New_Ci.Name_C = Name_C;
    New_Ci.Blocks_l = Blocks_l;
    New_Ci.Free_l = Free_l;
    New_Ci.PeSize_l = PeSize_l;
    New_Ci.Active_b = Active_b;
    New_Ci.Lvm2_b = Lvm2_b;
    for( list<PvInfo*>::iterator I_Ci=Pv_C.begin(); I_Ci!=Pv_C.end(); I_Ci++ )
	{
	New_Ci.Pv_C.push_back(**I_Ci);
	}
    for( list<LvInfo*>::iterator I_Ci=Lv_C.begin(); I_Ci!=Lv_C.end(); I_Ci++ )
	{
	New_Ci.Lv_C.push_back(**I_Ci);
	}
    return New_Ci;
    }

