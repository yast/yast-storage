// Maintainer: fehr@suse.de

#define PARTEDCMD "/usr/sbin/parted -s "	// blank at end !!

#include <ctype.h>
#include <string>
#include <sstream>
#include <iomanip>

#include <ycp/y2log.h>
#include "AppUtil.h"
#include "SystemCmd.h"
#include "AsciiFile.h"
#include "PartedAcc.h"

PartedAccess::PartedAccess(string Disk_Cv, bool Readonly_bv )
  : DiskAccess(Disk_Cv)
{
  y2debug( "Constructor called Disk:%s Readonly:%d", Disk_Cv.c_str(),
           Readonly_bv );

  GetPartitionList( !Readonly_bv );
}

void PartedAccess::GetPartitionList( bool OnlyLabel_bv )
    {
    string Tmp_Ci = string(PARTEDCMD);
    Tmp_Ci += Disk_C;
    Tmp_Ci += " print | sort -n";
    Label_C.erase();
    Stderr_C.erase();
    y2milestone( "executing cmd:%s", Tmp_Ci.c_str() );
    SystemCmd Cmd_Ci( Tmp_Ci.c_str(), true );
    CheckError( Tmp_Ci, Cmd_Ci );
    if( Cmd_Ci.Select( "Disk label type:" )>0 )
	{
	Tmp_Ci = *Cmd_Ci.GetLine(0, true);
	y2debug( "Label line:%s", Tmp_Ci.c_str() );
	Label_C = ExtractNthWord( 3, Tmp_Ci );
	}
    y2debug( "Label:%s", Label_C.c_str() );
    if( !OnlyLabel_bv )
	{
	CheckOutput(Cmd_Ci, Disk_C);
	}
    }

PartedAccess::~PartedAccess()
{
  y2debug( "Destructor called Disk:%s", Disk_C.c_str() );
}

void
PartedAccess::CheckError( const string& CmdString_Cv, SystemCmd& Cmd_C )
    {
    string Tmp_Ci = *Cmd_C.GetString(IDX_STDERR);
    if( Tmp_Ci.length()>0 )
	{
	y2error( "cmd:%s", CmdString_Cv.c_str() );
	y2error( "err:%s", Tmp_Ci.c_str() );
	}
    if( Cmd_C.Retcode() != 0 )
	{
	y2error( "retcode:%d", Cmd_C.Retcode() );
	}
    Stderr_C += Tmp_Ci;
    }

bool
PartedAccess::NewPartition(const PartitionType Part_e,
			  const unsigned PartNr_iv,
			  string Von_Cv, string Bis_Cv,
			  const unsigned Type_iv,
			  string DefLabel_Cv )
{
  y2milestone( "type:%d nr:%d von:%s bis:%s type:%d", Part_e, PartNr_iv,
               Von_Cv.c_str(), Bis_Cv.c_str(), Type_iv );
  std::ostringstream Buf_Ci;
  bool Ok_bi = true;
  Changed_b = true;
  Stderr_C.erase();
  if( Label_C.length()==0 )
      {
      Buf_Ci << PARTEDCMD << Disk_C << " mklabel " << DefLabel_Cv;
      SystemCmd Cmd_Ci( Buf_Ci.str().c_str(), true );
      CheckError( Buf_Ci.str(), Cmd_Ci );
      Buf_Ci.str( "" );
      }
  Buf_Ci << PARTEDCMD << Disk_C << " mkpart ";
  switch (Part_e)
    {
    case PAR_TYPE_LOGICAL:
      Buf_Ci << "logical ";
      break;
    case PAR_TYPE_PRIMARY:
      Buf_Ci << "primary ";
      break;
      break;
    case PAR_TYPE_EXTENDED:
      Buf_Ci << "extended ";
      break;
    default:
      Ok_bi = false;
      break;
    }
  if( Ok_bi && Part_e != PAR_TYPE_EXTENDED )
      {
      if( Type_iv == 0x82 )
	  {
	  Buf_Ci << "linux-swap ";
	  }
      else if( Type_iv == 0x06 || Type_iv == 0x0c )
	  {
	  Buf_Ci << "fat32 ";
	  }
      else if( Type_iv == 0x102 )
	  {
	  Buf_Ci << "hfs ";
	  }
      else
	  {
	  Buf_Ci << "ext2 ";
	  }
      }
  std::istringstream Data_Ci( Von_Cv );
  unsigned Num_ui;
  Data_Ci >> Num_ui;
  y2debug( "Von:%s von:%u", Von_Cv.c_str(), Num_ui );

  Buf_Ci << std::setprecision(3) 
         << std::setiosflags(std::ios_base::fixed) 
	 << (double)(Num_ui-1)*CylinderToKb(1)/1024 
         << " ";
  Data_Ci.clear();
  Data_Ci.str( Bis_Cv );
  Data_Ci >> Num_ui;
  y2debug( "Bis:%s bis:%u", Bis_Cv.c_str(), Num_ui );
  Buf_Ci << std::setprecision(3) << ((double)Num_ui)*CylinderToKb(1)/1024;
  
  y2milestone( "ok:%d executing cmd:%s", Ok_bi, Buf_Ci.str().c_str() );
  if( Ok_bi )
    {
    SystemCmd Cmd_Ci( Buf_Ci.str().c_str(), true );
    CheckError( Buf_Ci.str(), Cmd_Ci );
    }
  SetType( PartNr_iv, Type_iv );
  return( Ok_bi );
  }

void
PartedAccess::SetType(const unsigned Part_iv, const unsigned Type_iv)
  {
  std::ostringstream Buf_Ci;
  Buf_Ci << PARTEDCMD << Disk_C << " set " << Part_iv << " ";
  bool SetType_bi = true;
  if( Type_iv == 0x82 )
    {
    Buf_Ci << " swap on";
    }
  else if( Type_iv == 0x8e )
    {
    Buf_Ci << " lvm on";
    }
  else if( Type_iv == 0xfd )
    {
    Buf_Ci << " raid on";
    }
  else if( Type_iv == 0x83 )
    {
    Buf_Ci << " raid off";
    }
  else
    {
    SetType_bi = false;
    }
  SystemCmd Cmd_Ci( true );
  if( SetType_bi )
    {
    y2milestone( "executing cmd:%s", Buf_Ci.str().c_str() );
    Cmd_Ci.Execute( Buf_Ci.str().c_str() );
    CheckError( Buf_Ci.str(), Cmd_Ci );
    if( Type_iv == 0x83 )
	{
	Buf_Ci.str( "" );
        Buf_Ci << PARTEDCMD << Disk_C << " set " << Part_iv << " lvm off";
	y2milestone( "executing cmd:%s", Buf_Ci.str().c_str() );
	Cmd_Ci.Execute( Buf_Ci.str().c_str() );
	CheckError( Buf_Ci.str(), Cmd_Ci );
	}
    }
  Buf_Ci.str( "" );
  Buf_Ci << PARTEDCMD << Disk_C << " set " << Part_iv << " type " << Type_iv;
  y2milestone( "executing cmd:%s", Buf_Ci.str().c_str() );
  Cmd_Ci.Execute( Buf_Ci.str().c_str() );
}

string
PartedAccess::GetPartitionNumber(int Part_iv)
{
#if !defined(__sparc__)
  if (BsdLabel_b)
    return string (1, char('a' + Part_iv - 1));
  else
#endif
    return dec_string(Part_iv);
}

bool
PartedAccess::Resize(const unsigned Part_iv, const unsigned NewCylCnt_iv )
{
  Changed_b = true;
  bool ret = false;
  GetPartitionList(false);
  std::ostringstream Buf_Ci;
  Buf_Ci << PARTEDCMD << Disk_C << " resize " << Part_iv << " ";
  vector<PartInfo>::iterator I_ii = Part_C.begin();
  while( I_ii != Part_C.end() && I_ii->Num_i != Part_iv )
    {
    I_ii++;
    }
  if( I_ii != Part_C.end() )
    {
    Buf_Ci << std::setprecision(3) 
           << std::setiosflags(std::ios_base::fixed) 
	   << (double)I_ii->Start_i*CylinderToKb(1)/1024 << " "
           << ((double)NewCylCnt_iv+I_ii->Start_i-0.1)*CylinderToKb(1)/1024 << " ";
    Stderr_C.erase();
    y2milestone( "executing cmd:%s", Buf_Ci.str().c_str() );
    SystemCmd Cmd_Ci( Buf_Ci.str().c_str(), true );
    CheckError( Buf_Ci.str(), Cmd_Ci );
    ret = Cmd_Ci.Retcode()==0;
    }
  return( ret );
}

void
PartedAccess::Delete(const unsigned Part_iv)
{
  Changed_b = true;
  std::ostringstream Buf_Ci;
  Buf_Ci << PARTEDCMD << Disk_C << " rm " << Part_iv;
  Stderr_C.erase();
  y2milestone( "executing cmd:%s", Buf_Ci.str().c_str() );
  SystemCmd Cmd_Ci( Buf_Ci.str().c_str(), true );
  CheckError( Buf_Ci.str(), Cmd_Ci );
}

void
PartedAccess::DeleteAll()
{
  vector<PartInfo>::reverse_iterator Pix_Ci = Part_C.rbegin();
  while (Pix_Ci != Part_C.rend())
    {
      Delete(Pix_Ci->Num_i);
      ++Pix_Ci;
    }
}

bool
PartedAccess::ScanLine(string Line_Cv, PartInfo& Part_rr)
{
  int Num_ii=0;
  double Start_fi, End_fi;
  string PType_Ci, Type_Ci;

  y2debug( "Line: %s", Line_Cv.c_str() );
  std::istringstream Data_Ci( Line_Cv );

  Start_fi = End_fi = 0.0;
  if( Label_C != "mac" )
      {
      Data_Ci >> Num_ii >> Start_fi >> End_fi >> PType_Ci;
      }
  else
      {
      Data_Ci >> Num_ii >> Start_fi >> End_fi;
      PType_Ci = "primary";
      }
  char c;
  Type_Ci = ",";
  Data_Ci.unsetf(ifstream::skipws);
  Data_Ci >> c;
  char last_char = ',';
  while( !Data_Ci.eof() )
      {
      if( !isspace(c) )
	{
	Type_Ci += c;
	last_char = c;
	}
      else
        {
	if( last_char != ',' )
	    {
	    Type_Ci += ",";
	    last_char = ',';
	    }
	}
      Data_Ci >> c;
      }
  Type_Ci += ",";
  y2debug( "Fields Num:%d Start:%5.2f End:%5.2f PType:%s Type:%s",
	   Num_ii, Start_fi, End_fi, PType_Ci.c_str(), Type_Ci.c_str() );
  int Add_ii = CylinderToKb(1)*2/5;
  if( Num_ii>0 )
    {
    Part_rr.Num_i = Num_ii;
    Part_rr.Device_C = GetPartDeviceName(Num_ii);
    Part_rr.Start_i = KbToCylinder( (unsigned long)(Start_fi*1024)+Add_ii );
    Part_rr.End_i = KbToCylinder( (unsigned long)(End_fi*1024)+Add_ii ) - 1;
    Part_rr.Blocks_l = CylinderToKb( Part_rr.End_i-Part_rr.Start_i+1 );
    Part_rr.PType_e = PAR_TYPE_LINUX;
    Part_rr.Id_i = PART_ID_LINUX_NATIVE;
    Part_rr.Info_C = "";
    string OrigType_Ci = Type_Ci;
    for( string::iterator i=Type_Ci.begin(); i!=Type_Ci.end(); i++ )
	{
	*i = tolower(*i);
	}
    if( PType_Ci == "extended" )
	{
	Part_rr.PType_e = PAR_TYPE_EXTENDED;
	Part_rr.Id_i = 0x0f;
	}
    else if( Type_Ci.find( ",fat" )!=string::npos )
	{
	Part_rr.PType_e = PAR_TYPE_DOS;
	Part_rr.Id_i = 0x0b;
	}
    else if( Type_Ci.find( ",ntfs," )!=string::npos )
	{
	Part_rr.PType_e = PAR_TYPE_HPFS;
	Part_rr.Id_i = 0x07;
	}
    else if( Type_Ci.find( "swap," )!=string::npos )
	{
	Part_rr.PType_e = PAR_TYPE_SWAP;
	Part_rr.Id_i = PART_ID_LINUX_SWAP;
	}
    else if( Type_Ci.find( ",raid," )!=string::npos )
	{
	Part_rr.PType_e = PAR_TYPE_RAID_PV;
	Part_rr.Id_i = 0xFD;
	}
    else if( Type_Ci.find( ",lvm," )!=string::npos )
	{
	Part_rr.PType_e = PAR_TYPE_LVM_PV;
	Part_rr.Id_i = 0x8E;
	}
    string::size_type pos = Type_Ci.find( ",type=" );
    if( pos != string::npos )
	{
	string val;
	int id = 0;
	if( Label_C != "mac" )
	    {
	    val = Type_Ci.substr( pos+6, 2 );
	    Data_Ci.clear();
	    Data_Ci.str( val );
	    Data_Ci >> std::hex >> id;
	    y2debug( "val=%s id=%d", val.c_str(), id );
	    if( id>0 )
		{
		Part_rr.Id_i = id;
		}
	    }
	if( Label_C == "mac" )
	    {
	    pos = OrigType_Ci.find("type=");
	    val = OrigType_Ci.substr( pos+5 );
	    if( (pos=val.find_first_of( ", \t\n" )) != string::npos )
		{
		val = val.substr( 0, pos );
		}
	    Part_rr.Info_C = val;
	    if( Part_rr.Id_i == PART_ID_LINUX_NATIVE )
		{
		if( val.find( "Apple_partition" ) != string::npos || 
		    val.find( "Apple_Driver" ) != string::npos ||
		    val.find( "Apple_Loader" ) != string::npos ||
		    val.find( "Apple_Boot" ) != string::npos ||
		    val.find( "Apple_ProDOS" ) != string::npos ||
		    val.find( "Apple_FWDriver" ) != string::npos ||
		    val.find( "Apple_Patches" ) != string::npos )
		    {
		    Part_rr.Id_i = 0x101;
		    }
		else if( val.find( "Apple_HFS" ) != string::npos )
		    {
		    Part_rr.Id_i = 0x102;
		    }
		}
	    }
	}
    y2debug( "Fields Num:%d Id:%x Ptype:%d Start:%d End:%d Block:%lu",
	     Part_rr.Num_i, Part_rr.Id_i, Part_rr.PType_e, Part_rr.Start_i,
	     Part_rr.End_i, Part_rr.Blocks_l );
    y2debug( "Fields Device:%s Info:%s",
	     Part_rr.Device_C.c_str(), Part_rr.Info_C.c_str() );
    }
 return( Num_ii>0 );
}

void
PartedAccess::CheckOutput(SystemCmd& Cmd_C, string Pat_Cv)
{
  int Cnt_ii;
  int Idx_ii;
  string Line_Ci;
  string Tmp_Ci;
  PartInfo Part_ri;
  vector<PartInfo> New_Ci;

  Cnt_ii = Cmd_C.NumLines();
  for(Idx_ii = 0; Idx_ii < Cnt_ii; Idx_ii++)
    {
      Line_Ci = *Cmd_C.GetLine(Idx_ii);
      Tmp_Ci = ExtractNthWord( 0, Line_Ci );
      if( Tmp_Ci.length()>0 && isdigit(Tmp_Ci[0]) )
	  {
	  Part_ri.PType_e = PAR_TYPE_OTHER;
	  if( ScanLine(Line_Ci, Part_ri))
	      New_Ci.push_back(Part_ri);
	  }
    }
  Part_C = New_Ci;
}


