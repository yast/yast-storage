// Maintainer: schwab@suse.de

#define FDISKPATH "/usr/lib/YaST2/bin/fdisk "	// blank at end !!

#include "config.h"

#include <ctype.h>
#include <string>
#include <sstream>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/hdreg.h>       /* for HDIO_GETGEO */

#include <ycp/y2log.h>
#include "AppUtil.h"
#include "SystemCmd.h"
#include "InterCmd.h"
#include "AsciiFile.h"
#include "FdiskAcc.h"

#if defined(__sparc__)
#define MINUS_1
#define PLUS_1
#else
#define MINUS_1 -1
#define PLUS_1 +1
#endif

FdiskAccess::FdiskAccess(string Disk_Cv, bool Readonly_bv )
  : Disk_C(Disk_Cv),
    Changed_b(false),
    BsdLabel_b(false),
    Fdisk_pC(NULL)
{
  y2debug( "Constructor called Disk:%s Readonly:%d", Disk_Cv.c_str(),
           Readonly_bv );
#ifdef __alpha__
  AsciiFile CpuInfo_Ci("/proc/cpuinfo");
  string Line_Ci;
  if (SearchFile(CpuInfo_Ci, "system serial", Line_Ci))
    {
      Line_Ci.erase(0, Line_Ci.find(':') + 1);
      BsdLabel_b = Line_Ci.find("MILO") == string::npos;
    }
#endif

  if (Disk_C.length() > 0)
    {
      Head_i = Cylinder_i = Sector_i = 16;
      int Fd_ii = open (Disk_C.c_str(), O_RDONLY);
      if (Fd_ii >= 0)
	{
	  struct hd_geometry SmGeometry_ri;
#if __GLIBC__ > 2 || (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 2)
	  struct hd_big_geometry Geometry_ri;
	  if( ioctl(Fd_ii, HDIO_GETGEO_BIG, &Geometry_ri )==0 )
	    {
	      Head_i = Geometry_ri.heads;
	      Cylinder_i = Geometry_ri.cylinders;
	      Sector_i = Geometry_ri.sectors;
	    }
	  else
#else
#  warning: no support for big disks with GLIBC < 2.2
#endif
	  if( ioctl(Fd_ii, HDIO_GETGEO, &SmGeometry_ri )==0 )
	    {
	      Head_i = SmGeometry_ri.heads;
	      Cylinder_i = SmGeometry_ri.cylinders;
	      Sector_i = SmGeometry_ri.sectors;
	    }
	  close (Fd_ii);
        y2milestone( "Head=%d Sector:%d Cylinder:%d", Head_i, Sector_i, 
	             Cylinder_i );
	}
      ByteCyl_l = Head_i * Sector_i * 512;
    }

  string Tmp_Ci = string(FDISKPATH);
  if( Readonly_bv )
    {
    Tmp_Ci += "-l ";
    Tmp_Ci += Disk_Cv;
    SystemCmd Cmd_Ci( Tmp_Ci.c_str(), true );
    Stderr_C = *Cmd_Ci.GetString(IDX_STDERR);
    CheckOutput(Cmd_Ci, Disk_Cv);
    }
  else
    {
    Tmp_Ci += Disk_Cv;

    Fdisk_pC = new InterCmd(Tmp_Ci, true);
    Fdisk_pC->CheckOutput("Command|BSD disklabel command");
    Stderr_C = *Fdisk_pC->GetString(IDX_STDERR);
#if defined(__sparc__)
    if( !Fdisk_pC->SendInput( "?", "for help|Select" ) )
	{
	Fdisk_pC->SendInput( "0", "Heads" );
	Fdisk_pC->SendInput( "", "Sectors" );
	Fdisk_pC->SendInput( "", "Cylinders" );
	Fdisk_pC->SendInput( "", "Alternate" );
	Fdisk_pC->SendInput( "", "Physical" );
	Fdisk_pC->SendInput( "", "Rotation" );
	Fdisk_pC->SendInput( "", "Interleave" );
	Fdisk_pC->SendInput( "", "Extra" );
	Fdisk_pC->SendInput( "", "Command" );
	}
#else
#ifdef __alpha__
      if (BsdLabel_b)
	{
	  // We have to check each disk for the correct label because there
	  // may be non BSD-disks on an alpha that require at least one BSD
	  // Label for booting.

	  string Label_pI = *Fdisk_pC->GetString();
	  if (Label_pI.find("neither") != string::npos)
	    {
	      // We have neither a DOS nor a BSD disklabel
	      if (!Fdisk_pC->SendInput("b", "BSD disk|create a disklabel"))
		Fdisk_pC->SendInput("y", "BSD disk");
	    }
	  else if (Label_pI.find("OSF/1") == string::npos)
	    {
	      // We (probably) have a DOS disklabel
	      BsdLabel_b = false;
	      y2milestone("DOS Label found.");
	    }
	  Stderr_C = *Fdisk_pC->GetString(IDX_STDERR);  
	}
#endif // __alpha__
#endif // ! __sparc_
    SendPrint();
    }
}

FdiskAccess::~FdiskAccess()
{
  y2debug( "Destructor called Disk:%s Fdisk:%p", Disk_C.c_str(), Fdisk_pC );
  if (Fdisk_pC)
    SendQuit();
}

vector<string>&
FdiskAccess::DiskList()
{
  return DiskList_C;
}

/**
 * Return the hexadecimal representation of the number.
 */
static string hex_string(int number)
{
  std::ostringstream num_str;
  num_str << std::hex << number << std::ends;
  string hexadecimal = num_str.str();
  return hexadecimal;
}

string
FdiskAccess::GetPartDeviceName(int Num_iv)
{
  return GetPartDeviceName(Num_iv, Disk());
}

string
FdiskAccess::GetPartDeviceName(int Num_iv, string Disk_Cv)
{
  if (Disk_Cv.find("/dev/sd") == 0 || Disk_Cv.find("/dev/hd") == 0 ||
      Disk_Cv.find("/dev/ed") == 0)
    return Disk_Cv + dec_string(Num_iv);
  else
    return Disk_Cv + "p" + dec_string(Num_iv);
}

int
FdiskAccess::GetPartNumber( const string& Part_Cv )
    {
    int Ret_ii=0;
    string Tmp_Ci = Part_Cv;
    Tmp_Ci.erase( 0, GetDiskName(Part_Cv).length() );
    if( Tmp_Ci.length()>0 && Tmp_Ci[0]=='p' )
        {
        Tmp_Ci.erase( 0, 1 );
        }
    sscanf( Tmp_Ci.c_str(), "%d", &Ret_ii );
    return( Ret_ii );
    }

bool
FdiskAccess::IsKnownDevice(const string& Part_Cv)
    {
    bool Ret_bi;
    Ret_bi = Part_Cv.find("/dev/sd")==0 || Part_Cv.find("/dev/hd") ||
	     Part_Cv.find("/dev/ed")==0 || Part_Cv.find( "/dev/i2o/hd" )==0 ||
	     Part_Cv.find("/dev/ida/")==0 || Part_Cv.find("/dev/rd/")==0 ||
	     Part_Cv.find("/dev/cciss/") || Part_Cv.find("/dev/dasd")==0;
    return( Ret_bi );
    }

string
FdiskAccess::GetDiskName(string Part_Cv)
{
  string::size_type Idx_ii;

  if (Part_Cv.find("/dev/sd") == 0 || Part_Cv.find("/dev/hd") == 0 ||
      Part_Cv.find("/dev/ed") == 0)
    return Part_Cv.substr(0, 8);
  
  if( Part_Cv.find( "/dev/i2o/hd" ) == 0 )
    return Part_Cv.substr (0, 12);
  
  if( (Part_Cv.find("/dev/ida/")==0
       || Part_Cv.find("/dev/rd/")==0
       || Part_Cv.find("/dev/cciss/")==0) &&
      (Idx_ii=Part_Cv.find('p')) != string::npos)
    return Part_Cv.substr (0, Idx_ii);
  
  if (Part_Cv.find("/dev/dasd")==0 )
    return Part_Cv.substr(0, Part_Cv.length()-1);
  
  return Part_Cv;
}

vector<PartInfo>&
FdiskAccess::Partitions()
{
  return Part_C;
}

string
FdiskAccess::Disk()
{
  return Disk_C;
}

unsigned
FdiskAccess::PartitionCnt()
{
  return Part_C.size();
}

unsigned
FdiskAccess::LogicalCnt()
{
#if !defined (__sparc__)
  if (!BsdLabel_b && Part_C.size() > 0 && Part_C.front().Num_i > 4)
    return Part_C.front().Num_i - 4;
  else
#endif
    return 0;
}

unsigned
FdiskAccess::PrimaryCnt()
{
  return PartitionCnt()-LogicalCnt();
}

PartInfo&
FdiskAccess::operator[](unsigned int Idx_iv)
{
  if (Idx_iv >= Part_C.size())
    {
      // XXX y2log
    }
  return Part_C[Idx_iv];
}

bool
FdiskAccess::SetPossible(const unsigned Idx_iv)
{
  return (Idx_iv < PartitionCnt() &&
	  Part_C[Idx_iv].PType_e != PAR_TYPE_EXTENDED);
}

bool
FdiskAccess::DelPossible(const unsigned Idx_iv)
{
  if (Idx_iv < PartitionCnt() && Part_C[Idx_iv].PType_e == PAR_TYPE_EXTENDED)
    {
      unsigned Max_ii = 0;

      for (vector<PartInfo>::iterator Pix_Ci = Part_C.begin();
	   Pix_Ci != Part_C.end();
	   ++Pix_Ci)
	Max_ii = MAX(Max_ii, Pix_Ci->Num_i);
      return Max_ii <= 4;
    }
  return false;
}

bool
FdiskAccess::NewPossible(const unsigned)
{
  return LogicalPossible() || PrimaryPossible() || ExtendedPossible();
}

bool
FdiskAccess::LogicalPossible()
{
  unsigned Dummy_ii = 0;
#if defined(__sparc__)
  return false;
#else
  return (!BsdLabel_b &&
	  ExtendedIndex()!=Part_C.end() && 
          CheckFreeBlocks(true, Dummy_ii, Dummy_ii) &&
	  LogicalCnt() < 12);
#endif
}

unsigned
FdiskAccess::PrimaryMax()
{
#if defined(__sparc__)
  return 8;
#else
  return BsdLabel_b ? 8 : 4;
#endif
}

bool
FdiskAccess::PrimaryPossible()
{
  unsigned Nr_ii = 1;
  unsigned Dummy_ii = 0;

  while (PrimaryExists(Nr_ii) && Nr_ii <= PrimaryMax())
    Nr_ii++;
  return CheckFreeBlocks(false, Dummy_ii, Dummy_ii) && Nr_ii <= PrimaryMax();
}

bool
FdiskAccess::ExtendedPossible()
{
#if defined(__sparc__)
  return false;
#else
  return( !BsdLabel_b && PrimaryPossible() && ExtendedIndex()==Part_C.end() );
#endif
}

vector<PartInfo>::iterator
FdiskAccess::ExtendedIndex()
{
  vector<PartInfo>::iterator Pix_Ci = Part_C.begin();

  while (Pix_Ci != Part_C.end() && Pix_Ci->PType_e != PAR_TYPE_EXTENDED)
    ++Pix_Ci;
  return Pix_Ci;
}

bool
FdiskAccess::PrimaryExists(const unsigned Nr_iv)
{
  vector<PartInfo>::iterator Pix_Ci = Part_C.begin();
  while (Pix_Ci != Part_C.end() && Pix_Ci->Num_i != Nr_iv)
    ++Pix_Ci;
#if defined (__sparc__)
  return Pix_Ci != Part_C.end() || Nr_iv == 3;
#else
  return Pix_Ci != Part_C.end() || BsdLabel_b && Nr_iv == 3;
#endif
}

bool
FdiskAccess::GetFreeArea(const bool Extended_bv,
			 unsigned& Von_ir, unsigned& Bis_ir)
{
  return CheckFreeBlocks(Extended_bv, Von_ir, Bis_ir);
}

vector<PartInfo>::iterator
FdiskAccess::GetPartitionAfter(const unsigned Nr_iv,
			       const bool IgnoreLogical_bv)
{
  unsigned CurNext_ii = Cylinder_i+1;
  bool DoIgnore_bi;
  vector<PartInfo>::iterator Ret_Ci = Part_C.end();
  vector<PartInfo>::iterator Pix_Ci = Part_C.begin();

  while (Pix_Ci != Part_C.end())
    {
      DoIgnore_bi = (Pix_Ci->Num_i > PrimaryMax()) == IgnoreLogical_bv;
      if (Pix_Ci->Start_i > Nr_iv && !DoIgnore_bi &&
	  CurNext_ii > Pix_Ci->Start_i)
	{
	  Ret_Ci = Pix_Ci;
	  CurNext_ii = Pix_Ci->Start_i;
	}
      ++Pix_Ci;
    }
  return Ret_Ci;
}

unsigned long
FdiskAccess::CapacityInKb()
{
  return (unsigned long long)ByteCyl_l * Cylinder_i / 1024;
}

int
FdiskAccess::KbToCylinder(unsigned long Kb_lv)
{
  int Val_ii = ByteCyl_l / 1024;
  return (Kb_lv + Val_ii - 1) / Val_ii;
}

unsigned long
FdiskAccess::CylinderToKb(int Cylinder_iv)
{
  return (unsigned long long)ByteCyl_l * Cylinder_iv / 1024;
}

int
FdiskAccess::NumCylinder()
{
  return Cylinder_i;
}

bool
FdiskAccess::CheckFreeBlocks(const bool Extended_bv,
			     unsigned& Von_ir, unsigned& Bis_ir)
{
  int Gap_ii;
  PartInfo Entry_Ci;
  vector<PartInfo> Part_Ci;
  vector<PartInfo>::iterator Pix_Ci = Part_C.begin();

  if (Extended_bv)
    {
      while (Pix_Ci != Part_C.end())
	{
	  if (Pix_Ci->Num_i > PrimaryMax())
	    Part_Ci.push_back(*Pix_Ci);
	  ++Pix_Ci;
	}
    }
  else
    {
      while (Pix_Ci != Part_C.end())
	{
	  if (Pix_Ci->Num_i <= 4)
	    Part_Ci.push_back(*Pix_Ci);
	  ++Pix_Ci;
	}
    }

  unsigned Start_ii = 1;
  unsigned End_ii = Cylinder_i;

  Von_ir = Bis_ir = 0;
  if (Extended_bv)
    {
      Pix_Ci = ExtendedIndex();
      if (Pix_Ci != Part_C.end())
	{
	  Start_ii = Pix_Ci->Start_i;
	  End_ii = Pix_Ci->End_i;
	}
      else
	Start_ii = End_ii = 0;
    }
  vector<PartInfo>::iterator Pix2_Ci;
  Pix_Ci = Part_Ci.begin();
  while (Pix_Ci != Part_Ci.end())
    {
      Pix2_Ci = Pix_Ci;
      ++Pix2_Ci;
      while (Pix2_Ci != Part_Ci.end())
	{
	  if (Pix2_Ci->Start_i < Pix_Ci->Start_i)
	    {
	      Entry_Ci = *Pix2_Ci;
	      *Pix2_Ci = *Pix_Ci;
	      *Pix_Ci = Entry_Ci;
	    }
	  ++Pix2_Ci;
	}
      ++Pix_Ci;
    }
  Pix_Ci = Part_Ci.begin();
  if (Pix_Ci == Part_Ci.end())
    {
      Von_ir = Start_ii;
      Bis_ir = End_ii;
    }
  else if (Pix_Ci->Start_i > Start_ii)
    {
      Von_ir = Start_ii;
      Bis_ir = Pix_Ci->Start_i-1;
    }
  Pix2_Ci = Pix_Ci;
  ++Pix2_Ci;
  while (Pix2_Ci != Part_Ci.end())
    {
      if (Pix_Ci->End_i+1 < Pix2_Ci->Start_i )
	{
	  Gap_ii = Pix2_Ci->Start_i MINUS_1 - (Pix_Ci->End_i PLUS_1);
	  if (Gap_ii > int(Bis_ir - Von_ir))
	    {
	      Von_ir = Pix_Ci->End_i PLUS_1;
	      Bis_ir = Pix2_Ci->Start_i MINUS_1;
	    }
	}
      ++Pix2_Ci;
      ++Pix_Ci;
    }
  vector<PartInfo>::reverse_iterator Pixr_Ci = Part_Ci.rbegin();
  if (Pixr_Ci != Part_Ci.rend() && Pixr_Ci->End_i < End_ii)
    {
      Gap_ii = End_ii - (Pixr_Ci->End_i PLUS_1);
      if (Gap_ii > int(Bis_ir - Von_ir))
	{
	  Von_ir = Pixr_Ci->End_i PLUS_1;
	  Bis_ir = End_ii;
	}
    }
  return Von_ir > 0;
}

void
FdiskAccess::SendQuit()
{
  CheckWritable();
  Fdisk_pC->SendInput("q");
  delete Fdisk_pC;
  Fdisk_pC = NULL;
}

bool
FdiskAccess::WritePartitionTable()
{
  CheckWritable();
  Fdisk_pC->SendInput("w", "WARNING|Syncing");
  bool Ret_bi = Fdisk_pC->GetString()->find("Re-read table failed") != string::npos;
  delete Fdisk_pC;
  if (Ret_bi)
    {
    y2error( "Writing partition table failed" );
    }
  Fdisk_pC = NULL;
  return Ret_bi;
}

bool
FdiskAccess::NewPartition(const PartitionType Part_e,
			  const unsigned PartNr_iv,
			  string Von_Cv, string Bis_Cv)
{
#if defined(__sparc__)
  return NewPartitionBsd(PartNr_iv, Von_Cv, Bis_Cv);
#else
  // If BsdLabel_b is true, the user should be asked whether
  // he wants a BSD or DOS Label. We have to make sure we have
  // at least 1 BSD Label in this case.

  if (BsdLabel_b)
    return NewPartitionBsd(PartNr_iv, Von_Cv, Bis_Cv);
  else
    return NewPartitionStd(Part_e, PartNr_iv, Von_Cv, Bis_Cv);
#endif
}

bool
FdiskAccess::NewPartitionStd(const PartitionType Part_e,
			     const unsigned PartNr_iv,
			     string Von_Cv, string Bis_Cv)
{
  string Tmp_Ci;
  bool SendType_bi;
  bool Ok_bi = true;
  bool DelLast_bi = false;

  CheckWritable();
  Changed_b = true;
  SendType_bi = Fdisk_pC->SendInput("n", "action|First", 10);
  switch (Part_e)
    {
    case PAR_TYPE_LOGICAL:
      Tmp_Ci = "l";
      break;
    case PAR_TYPE_PRIMARY:
      Tmp_Ci = "p";
      break;
    case PAR_TYPE_EXTENDED:
      Tmp_Ci = "e";
      break;
    default:
      Ok_bi = false;
      break;
    }
  if (Ok_bi)
    {
      if (Part_e == PAR_TYPE_LOGICAL)
	{
	  if (SendType_bi)
	    Ok_bi = Fdisk_pC->SendInput(Tmp_Ci, "First|Command", 10);
	}
      else
	{
	  if (SendType_bi)
	    Ok_bi = Fdisk_pC->SendInput(Tmp_Ci, "Partition|Command", 10);
	  if (Ok_bi)
	    {
	      Ok_bi = Fdisk_pC->SendInput(dec_string(PartNr_iv),
					  "First|Command", 10);
	    }
	}
    }
  if (Ok_bi)
    {
      int Idx_ii;

      Ok_bi = Fdisk_pC->SendInput(Von_Cv, "Last|First", 10);
      Idx_ii = Fdisk_pC->NumLines() - 1;
      Tmp_Ci = *Fdisk_pC->GetLine(Idx_ii);
      if (Tmp_Ci.find("Command") != 0)
	{
	  Tmp_Ci.erase(0, Tmp_Ci.find_first_of("0123456789"));
	  Tmp_Ci.erase(Tmp_Ci.find_first_not_of("0123456789"));
	  if (!Ok_bi)
	    {
	      Fdisk_pC->SendInput(Tmp_Ci, "Last", 10);
	      Fdisk_pC->SendInput(Tmp_Ci, "Command", 10);
	      DelLast_bi = true;
	    }
	}
    }
  if (Ok_bi)
    {
      Ok_bi = Fdisk_pC->SendInput(Bis_Cv, "Command|Last", 10);
      if (!Ok_bi)
	{
	  Fdisk_pC->SendInput(Tmp_Ci, "Command", 10);
	  DelLast_bi = true;
	}
    }
  y2milestone( "DelLast=%d", DelLast_bi );
  if (DelLast_bi)
    {
      if (Part_e == PAR_TYPE_LOGICAL)
	{
	  SendPrint();
	  Tmp_Ci = Part_C.back().Device_C;
	  Tmp_Ci.erase(0, Tmp_Ci.find_last_not_of("0123456789")+1);
	  Delete(atoi(Tmp_Ci.c_str()));
	}
      else
	Delete(PartNr_iv);
    }
  if (Ok_bi)
    SendPrint();
  y2milestone( "Ok=%d", Ok_bi );
  return Ok_bi;
}

bool
FdiskAccess::NewPartitionBsd(const unsigned PartNr_iv,
			     string Von_Cv, string Bis_Cv)
{
  bool Ok_bi = true;

  CheckWritable();
  Changed_b = true;
  Fdisk_pC->SendInput("n", "Partition", 10);
  Ok_bi = Fdisk_pC->SendInput(GetPartitionNumber(PartNr_iv),
			      "First|Partition", 10);
  if (Ok_bi)
    {
      Fdisk_pC->SendInput(Von_Cv, "Last", 10);
      Fdisk_pC->SendInput(Bis_Cv, "ommand", 10);
      SetType(PartNr_iv, PART_ID_LINUX_NATIVE);
      SendPrint();
    }
  return( Ok_bi );
}

string
FdiskAccess::GetPartitionNumber(int Part_iv)
{
#if !defined(__sparc__)
  if (BsdLabel_b)
    return string (1, char('a' + Part_iv - 1));
  else
#endif
    return dec_string(Part_iv);
}

void
FdiskAccess::SetType(const unsigned Part_iv, const unsigned Type_iv)
{
  CheckWritable();
  Changed_b = true;
  y2debug("part:%d Type:%d", Part_iv, Type_iv );
  Fdisk_pC->SendInput("t", "Partition", 10);
  Fdisk_pC->SendInput(GetPartitionNumber(Part_iv), "Hex", 10);
#if !defined(__sparc__)
  if (BsdLabel_b)
    SetTypeBsd(Part_iv, Type_iv);
  else
#endif
    SetTypeStd(Part_iv, Type_iv);
  SendPrint();
}

void
FdiskAccess::SetTypeStd(const unsigned Part_iv, const unsigned Type_iv)
{
  Fdisk_pC->SendInput(hex_string(Type_iv), "Command", 10);
}

void
FdiskAccess::SetTypeBsd(const unsigned Part_iv, const unsigned Type_iv)
{
  int Type_ii;
  if (Type_iv == PART_ID_LINUX_SWAP)
    Type_ii = 1;
  else
    Type_ii = 8;
  Fdisk_pC->SendInput(hex_string(Type_ii), "ommand", 10);
}

void
FdiskAccess::Delete(const unsigned Part_iv)
{
  CheckWritable();
  Changed_b = true;
  Fdisk_pC->SendInput("d", "Partition", 10);
  Fdisk_pC->SendInput(GetPartitionNumber(Part_iv), "ommand", 10);
  SendPrint();
}

void
FdiskAccess::DeleteAll()
{
  vector<PartInfo>::reverse_iterator Pix_Ci = Part_C.rbegin();
  while (Pix_Ci != Part_C.rend())
    {
      Delete(Pix_Ci->Num_i);
      ++Pix_Ci;
    }
}

void
FdiskAccess::SendPrint()
{
  CheckWritable();
  Fdisk_pC->SendInput("p", "ommand");
  Stderr_C.insert(0, *Fdisk_pC->GetString(IDX_STDERR));
  CheckOutput(*Fdisk_pC, Disk_C);
}

string
FdiskAccess::Stderr()
{
  return Stderr_C;
}

void
FdiskAccess::CheckWritable()
{
  if (!Fdisk_pC)
    {
      // XXX y2log()
    }
}

void
FdiskAccess::ScanBsdLine(string Line_Cv, PartInfo& Part_rr,
			 string Disk_Cv)
{
  string Tmp_Ci;
  string Line_Ci = Line_Cv;
  unsigned long Tmp_li;

  if (Line_Ci.length() > 2)
    Part_rr.Device_C = GetPartDeviceName(Line_Ci[2] - 'a' + 1, Disk_Cv);
  else
    Part_rr.Device_C = "";
  Tmp_Ci = Part_rr.Device_C;
  Tmp_Ci.erase(0, Tmp_Ci.find_last_not_of("0123456789") + 1);
  if (sscanf(Tmp_Ci.c_str(), "%d", &Part_rr.Num_i) != 1)
    {
      // XXX y2log()
    }
  Line_Ci.erase(0, Line_Ci.find(':') + 1);
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
#if  0 // old yast2 bsd partition code
  if (sscanf(Line_Ci.c_str(), "%lu", &Tmp_li) > 0)
    Part_rr.Blocks_i = Tmp_li / 2;
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (Line_Ci.find("swap") == 0)
    {
      Part_rr.PType_e = PAR_TYPE_SWAP;
      Part_rr.Filesys_e = FS_TYPE_SWAP;
      Part_rr.Id_i = PART_ID_LINUX_SWAP;
    }
  else if (Line_Ci.find("ext2") == 0)
    {
      Part_rr.Filesys_e = FS_TYPE_EXT2;
      Part_rr.PType_e = PAR_TYPE_LINUX;
      Part_rr.Id_i = PART_ID_LINUX_NATIVE;
    }
  else
    Part_rr.Filesys_e = FS_TYPE_OTHER;
  Line_Ci.erase(0, Line_Ci.find("Cyl.") + 4);
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.Start_i) != 1)
    {
      // XXX y2log()
    }
  Line_Ci.erase(0, Line_Ci.find('-') + 1);
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.End_i) != 1)
    {
      // XXX y2log()
    }
#else
  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.Start_i) != 1)
    {
	// y2log();
    }
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.End_i) != 1)
    {
      // XXX y2log()
    }
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));

  if (sscanf(Line_Ci.c_str(), "%ld", &Tmp_li) > 0)
    Part_rr.Blocks_i = Tmp_li ;

  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));

  if (Line_Ci.find("swap") == 0)
    {
      Part_rr.PType_e = PAR_TYPE_SWAP;
      Part_rr.Filesys_e = FS_TYPE_SWAP;
      Part_rr.Id_i = PART_ID_LINUX_SWAP;
    }
  else if (Line_Ci.find("ext2") == 0)
    {
      Part_rr.Filesys_e = FS_TYPE_EXT2;
      Part_rr.PType_e = PAR_TYPE_LINUX;
      Part_rr.Id_i = PART_ID_LINUX_NATIVE;
    }
  else if (Line_Ci.find("unused") == 0)
    {
      Part_rr.Filesys_e = FS_TYPE_UNUSED;
      Part_rr.PType_e = PAR_TYPE_UNUSED;
      Part_rr.Id_i = PART_ID_UNUSED;
    }
  else
    Part_rr.Filesys_e = FS_TYPE_OTHER;
#endif

  Part_rr.Info_C = "Linux ";
  if (Part_rr.PType_e == PAR_TYPE_SWAP)
    {
      Part_rr.Info_C += "swap";
    }
  else if (Part_rr.PType_e == PAR_TYPE_UNUSED)
    {
      Part_rr.Info_C = "unused";
    }
  else
    {
      Part_rr.Info_C += "native";
    }
  Part_rr.InodeDens_i = InodesFromBlock(Part_rr.Blocks_i);
}

void
FdiskAccess::ScanPdiskLine(string Line_Cv, PartInfo& Part_rr,
			   string Disk_Cv)
{
  string Tmp_Ci;
  string Line_Ci = Line_Cv;
  unsigned long Tmp_li;

  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.Num_i) != 1)
    {
      // XXX y2log()
    }
  Part_rr.Device_C = GetPartDeviceName(Part_rr.Num_i, Disk_Cv);
  Line_Ci.erase(0, Line_Ci.find(':') + 1);
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (Line_Ci.find("Apple_partition_map") == string::npos &&
      Line_Ci.find("Apple_Driver43") == string::npos &&
      Line_Ci.find("Apple_Driver43_CD") == string::npos &&
      Line_Ci.find("Apple_Driver_ATA") == string::npos &&
      Line_Ci.find("Apple_Driver_IOKit") == string::npos &&
      Line_Ci.find("Apple_Patches") == string::npos &&
      Line_Ci.find("Apple_ProDOS") == string::npos)
    {
      Tmp_Ci = Line_Ci;
      for (string::iterator i = Tmp_Ci.begin(); i != Tmp_Ci.end(); i++)
	if (isupper ((unsigned char) *i))
	  *i = tolower ((unsigned char) *i);
      if (Tmp_Ci.find("swap") != string::npos)
	{
	  Part_rr.PType_e = PAR_TYPE_SWAP;
	  Part_rr.Filesys_e = FS_TYPE_SWAP;
	  Part_rr.Id_i = PART_ID_LINUX_SWAP;
	}
      else if (Tmp_Ci.find ("apple_hfs") != string::npos)
	{
	  Part_rr.PType_e = PAR_TYPE_LINUX;
	  Part_rr.Filesys_e = FS_TYPE_HFS;
	  Part_rr.Id_i = PART_ID_LINUX_NATIVE;
	}
      else 
	{
	  Part_rr.PType_e = PAR_TYPE_LINUX;
	  Part_rr.Filesys_e = FS_TYPE_EXT2;
	  Part_rr.Id_i = PART_ID_LINUX_NATIVE;
	}
    }
  else
    {
      Part_rr.Filesys_e = FS_TYPE_OTHER;
      Part_rr.PType_e = PAR_TYPE_OTHER;
    }
  for (string::iterator i = Line_Ci.begin(); i != Line_Ci.end(); i++)
    if (*i == '*') *i = ' ';
  Part_rr.Info_C = ExtractNthWord(0, Line_Ci);
  Line_Ci.erase(Line_Ci.find(" @"));
  Tmp_Ci = Line_Ci.substr(Line_Ci.rfind(' ') + 1);
  if (sscanf(Tmp_Ci.c_str(), "%lu", &Tmp_li) > 0)
    Part_rr.Blocks_i = Tmp_li / 2;
  Part_rr.InodeDens_i = InodesFromBlock(Part_rr.Blocks_i);
}

void
FdiskAccess::ScanFdiskLine(string Line_Cv, PartInfo& Part_rr)
{
  string Line_Ci = Line_Cv;
  string Tmp_Ci;

  Part_rr.Device_C = Line_Ci.substr(0, Line_Ci.find_first_of(" \t"));
  Part_rr.Filesys_e = FS_TYPE_OTHER;
  Tmp_Ci = Part_rr.Device_C;
  Tmp_Ci.erase(0, Tmp_Ci.find_last_not_of("0123456789") + 1);
  if (sscanf(Tmp_Ci.c_str(), "%d", &Part_rr.Num_i) != 1)
    {
      // XXX y2log()
    }
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (!isdigit(Line_Ci[0]))
    {
      Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
      Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
    }
  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.Start_i) != 1)
    {
      // XXX y2log()
    }
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.End_i) != 1)
    {
      // XXX y2log()
    }
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (sscanf(Line_Ci.c_str(), "%d", &Part_rr.Blocks_i) != 1)
    {
      // XXX y2log()
    }
  Part_rr.InodeDens_i = InodesFromBlock(Part_rr.Blocks_i);
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  if (sscanf(Line_Ci.c_str(), "%x", &Part_rr.Id_i) != 1)
    {
      // XXX y2log()
    }
  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));
  Part_rr.Info_C = Line_Ci;
#ifndef __sparc__
  if (Part_rr.Info_C.find("Extended") != string::npos ||
      Part_rr.Info_C.find("Linux extended") != string::npos ||
      Part_rr.Info_C.find("Win95 Extended") != string::npos ||
      Part_rr.Id_i == 0x5 || Part_rr.Id_i == 0x15 ||
      Part_rr.Id_i == 0xf || Part_rr.Id_i == 0x1f ||
      Part_rr.Id_i == 0x85 || Part_rr.Id_i == 0x95)
    {
      Part_rr.PType_e = PAR_TYPE_EXTENDED;
    }
  else if (Part_rr.Info_C.find("DOS") != string::npos ||
	   Part_rr.Info_C.find("Win95 FAT") != string::npos ||
	   Part_rr.Id_i == 0x1 || Part_rr.Id_i == 0x4 || 
	   Part_rr.Id_i == 0x6 || Part_rr.Id_i == 0x11 ||
	   Part_rr.Id_i == 0x1b || Part_rr.Id_i == 0x1c ||
	   Part_rr.Id_i == 0x1e || Part_rr.Id_i == 0x14 ||
	   Part_rr.Id_i == 0x16)
    {
      Part_rr.PType_e = PAR_TYPE_DOS;
      if (Part_rr.Info_C.find("DOS") != string::npos ||
	  Part_rr.Id_i == 0x1 || Part_rr.Id_i == 0x4 || 
	  Part_rr.Id_i == 0x6 || Part_rr.Id_i == 0x11 ||
	  Part_rr.Id_i == 0x14 || Part_rr.Id_i == 0x16)
	{
	  Part_rr.Filesys_e = FS_TYPE_DOS;
	  if (Part_rr.Info_C.find("DOS") == string::npos)
	    Part_rr.Info_C = "DOS";
	}
      else
	{
	  Part_rr.Filesys_e = FS_TYPE_VFAT;
	  if (Part_rr.Info_C.find("Win95 FAT") == string::npos)
	    Part_rr.Info_C = "Win95 FAT";
	}
    }
  else if (Part_rr.Info_C.find("HPFS") != string::npos ||
	   Part_rr.Info_C.find("OS/2") != string::npos ||
	   Part_rr.Id_i == 0x7 || Part_rr.Id_i == 0x17 ||
	   Part_rr.Id_i == 0x1a)
    {
      Part_rr.PType_e = PAR_TYPE_HPFS;
      Part_rr.Filesys_e = FS_TYPE_HPFS;
    }
  else 
#endif
    if (Part_rr.Id_i == LVM_PART_ID)
    {
      Part_rr.PType_e = PAR_TYPE_LVM_PV;
      Part_rr.Info_C = "Linux LVM";
    }
  else if (Part_rr.Id_i == 0xFD)
    {
      Part_rr.PType_e = PAR_TYPE_RAID_PV;
      Part_rr.Info_C = "Linux Raid";
    }
  else if (Part_rr.Info_C.find("Linux") != string::npos ||
	   Part_rr.Id_i == 0x92 || Part_rr.Id_i == 0x93)
    {
      Part_rr.Filesys_e = FS_TYPE_EXT2;
      if (Part_rr.Info_C.find("swap") != string::npos ||
	  Part_rr.Id_i == 0x92)
	{
	  Part_rr.PType_e = PAR_TYPE_SWAP;
	  Part_rr.Filesys_e = FS_TYPE_SWAP;
	  if (Part_rr.Info_C.find("swap") == string::npos)
	    Part_rr.Info_C = "Linux swap";
	}
      else
	{
	  Part_rr.PType_e = PAR_TYPE_LINUX;
	  if (Part_rr.Info_C.find("native") == string::npos)
	    Part_rr.Info_C = "Linux native";
	}
    }
}

void
FdiskAccess::CheckOutput(SystemCmd& Cmd_C, string Pat_Cv)
{
#if !defined(__sparc__)
  if (BsdLabel_b)
    CheckOutputBsd(Cmd_C, Pat_Cv);
  else
#endif
    CheckOutputStd(Cmd_C, Pat_Cv);
}

void
FdiskAccess::CheckOutputStd(SystemCmd& Cmd_Cv, string Pat_Cv)
{
  int Cnt_ii;
  int Idx_ii;
  string Line_Ci;
  PartInfo Part_ri;
  vector<PartInfo> New_Ci;

  Part_ri.Mount_C = "";
  Part_ri.HasFstab_b = false;

  Cnt_ii = Cmd_Cv.Select("^" + Pat_Cv);
  for(Idx_ii = 0; Idx_ii < Cnt_ii; Idx_ii++)
    {
      Part_ri.Filesys_e = FS_TYPE_OTHER;
      Part_ri.PType_e = PAR_TYPE_OTHER;
      Part_ri.Format_e = FORMAT_NO;
      Line_Ci = *Cmd_Cv.GetLine(Idx_ii, true);
      ScanFdiskLine(Line_Ci, Part_ri);
      if (Fdisk_pC)
	{
	  vector<PartInfo>::iterator Pix_Ci = Part_C.begin();
	  while (Pix_Ci != Part_C.end() &&
		 Pix_Ci->Device_C != Part_ri.Device_C)
	    ++Pix_Ci;
	  if (Pix_Ci != Part_C.end())
	    Part_ri.Format_e = Pix_Ci->Format_e;
	}
      New_Ci.push_back(Part_ri);
    }
  Part_C = New_Ci;
#if defined(__sparc__)
  if (Cmd_Cv.Select("label)") >0 )
    {
      string Tmp_Ci;
      Line_Ci = *Cmd_Cv.GetLine(0, true);
      Line_Ci.erase(0,Line_Ci.find(':')+1);
      std::istringstream Data_Ci (Line_Ci.c_str());
      if( Data_Ci )
	{
	  Data_Ci >> Head_i >> Tmp_Ci >> Sector_i >> Tmp_Ci >> Cylinder_i;
	  ByteCyl_l = Head_i * Sector_i * 512;
	}
    }
#endif
}

void
FdiskAccess::CheckOutputBsd(SystemCmd& Cmd_Cv, string Disk_Cv)
{
  int Cnt_ii;
  int Idx_ii;
  string Line_Ci;
  PartInfo Part_ri;
  vector<PartInfo> New_Ci;

  Part_ri.Mount_C = "";
  Part_ri.HasFstab_b = false;

  Cnt_ii = Cmd_Cv.NumLines();
  for (Idx_ii=0; Idx_ii < Cnt_ii; Idx_ii++)
    {
      Part_ri.Filesys_e = FS_TYPE_OTHER;
      Part_ri.PType_e = PAR_TYPE_OTHER;
      Part_ri.Format_e = FORMAT_NO;
      Line_Ci = *Cmd_Cv.GetLine(Idx_ii);
      if (IsBsdLine(Line_Ci))
	{
	  ScanBsdLine(Line_Ci, Part_ri, Disk_Cv);
	  if (Fdisk_pC)
	    {
	      vector<PartInfo>::iterator Pix_Ci = Part_C.begin();
	      while (Pix_Ci != Part_C.end() &&
		     Pix_Ci->Device_C != Part_ri.Device_C)
		++Pix_Ci;
	      if (Pix_Ci != Part_C.end())
		Part_ri.Format_e = Pix_Ci->Format_e;
	    }
	  New_Ci.push_back(Part_ri);
	}
    }
  Part_C = New_Ci;
}

int
FdiskAccess::InodesFromBlock(const int Blocks_iv)
{
  if (Blocks_iv < 200 * 1024)
    return 2048;
  else
    return 4096;
}

bool
FdiskAccess::IsBsdLine(string Line_Cv)
{
    return (Line_Cv.length() > 4 && Line_Cv[0] == ' ' && Line_Cv[1] == ' ' &&
	    Line_Cv[3] == ':' && Line_Cv[2] >= 'a' && Line_Cv[2] <= 'h' &&
//	    Line_Cv[2] != 'c' && ExtractNthWord(3, Line_Cv) != "unused";
	    ExtractNthWord(3, Line_Cv) != "unused");
}

bool
FdiskAccess::IsPdiskLine(string Line_Cv)
{
  return (Line_Cv.length() > 4 &&
	  (Line_Cv[0] == ' ' || isdigit(Line_Cv[0])) && Line_Cv[2] == ':' &&
	  isdigit(Line_Cv[1]));
}

#if 0
void
FdiskAccess::RereadPartitions()
{
  AsciiFile Partitions_Ci("/proc/partitions");
  vector<string> Disks_Ci;
  string LastDisk_Ci;
  string Line_Ci;
  string Name_Ci;
  string Tmp_Ci;
  PartInfo Part_ri;
  int Num_ii = Partitions_Ci.NumLines();
  bool SkipDisk_bi = false;
  static Regex DeviceName_Cs("^\\(" REGEX_DEVICE_PARTITION "\\)$");
  static Regex PartName_Cs("^\\(" REGEX_DEVICE_NAME "\\)$");
  static Regex DiskName_Cs("^\\(" REGEX_NAME_DISK "\\)$");

  for (int I_ii = 0; I_ii < Num_ii; I_ii++)
    {
      Line_Ci = Partitions_Ci[I_ii];
      Name_Ci = ExtractNthWord(3, Line_Ci);
      if (PartName_Cs.match(Name_Ci))
	{
	  Name_Ci.insert(0, "/dev/");
	  Tmp_Ci = GetDiskName(Name_Ci);
	  SkipDisk_bi = Disk_C.length() > 0 && Tmp_Ci != Disk_C;
	  if (!SkipDisk_bi && Tmp_Ci != LastDisk_Ci)
	    {
	      LastDisk_Ci = Tmp_Ci;
	      vector<PartInfo>::iterator Pix_Ci = Part_C.begin();
	      while (Pix_Ci != Part_C.end() &&
		     Pix_Ci->Device_C.find(Tmp_Ci) != 0)
		++Pix_Ci;
	      SkipDisk_bi = Pix_Ci != Part_C.end();
	      if (!SkipDisk_bi)
		Disks_Ci.push_back(Tmp_Ci);
	    }
	  if (!SkipDisk_bi)
	    {
	      Part_ri.Device_C = Name_Ci;
	      Tmp_Ci = ExtractNthWord(2, Line_Ci);
	      Part_ri.Blocks_i = 0;
	      sscanf(Tmp_Ci.c_str(), "%u", &Part_ri.Blocks_i);
	      Part_C.push_back(Part_ri);
	    }
	}
      else if (Disk_C.length() == 0 && DiskName_Cs.match(Name_Ci))
	{
	  Name_Ci.insert(0, "/dev/");
	  bool Ok_bi = true;
	  int Fd_ii = open (Name_Ci.c_str(), O_RDWR);
	  if (Fd_ii >= 0)
	    {
	      struct hd_geometry Driveinfo_ri;
	      Ok_bi = (ioctl (Fd_ii, HDIO_GETGEO, &Driveinfo_ri) < 0 ||
		       (Driveinfo_ri.cylinders > 0 &&
			Driveinfo_ri.heads > 0 &&
			Driveinfo_ri.sectors > 0));
	      close (Fd_ii);
	    }
	  else
	    Ok_bi = false;
	  if (Ok_bi)
	    {
	      vector<string>::iterator Pix_Ci = DiskList_C.begin();
	      while (Pix_Ci != DiskList_C.end() && *Pix_Ci != Name_Ci)
		++Pix_Ci;
	      if (Pix_Ci == DiskList_C.end())
		DiskList_C.push_back(Name_Ci);
	    }
	}
    }
  for (vector<string>::iterator Pix_Ci = Disks_Ci.begin();
       Pix_Ci != Disks_Ci.end();
       ++Pix_Ci)
    {
      string Disk_Ci = *Pix_Ci;
      string CmdLine_Ci = FDISKPATH "-l" + Disk_Ci;
      SystemCmd Cmd_Ci(CmdLine_Ci.c_str());
      Cmd_Ci.Select("BSD label");
      bool BsdLabels_bi = Cmd_Ci.NumLines(true) != 0;
      bool PdiskLabel_bi = false;
      Cmd_Ci.Select("^" + Disk_Ci);
#ifdef __powerpc__
      if (Cmd_Ci.NumLines(true) == 0)
	{
	  CmdLine_Ci.replace(CmdLine_Ci.find("fdisk"), strlen("fdisk"),
			     "pdisk");
	  Cmd_Ci.Execute(CmdLine_Ci);
	  PdiskLabel_bi = true;
	}
#endif
      bool HandleLine_bi;
      vector<PartInfo>::iterator Pt_Ci;

      for (int I_ii = 0; I_ii < Cmd_Ci.NumLines(); I_ii++)
	{
	  Line_Ci = *Cmd_Ci.GetLine(I_ii);
	  HandleLine_bi = false;
	  if (BsdLabels_bi)
	    {
	      ScanBsdLine(Line_Ci, Part_ri, Disk_Ci);
	      if (IsBsdLine(Line_Ci))
		HandleLine_bi = true;
	      else if (DeviceName_Cs.match(Part_ri.Device_C))
		{
		  vector<PartInfo>::iterator P_Ci = Part_C.begin();
		  while (P_Ci != Part_C.end() &&
			 P_Ci->Device_C != Part_ri.Device_C)
		    ++P_Ci;
		  if (P_Ci != Part_C.end())
		    Part_C.erase(P_Ci);
		}
	    }
	  else if (PdiskLabel_bi)
	    {
	      if (IsPdiskLine(Line_Ci))
		{
		  ScanPdiskLine(Line_Ci, Part_ri, Disk_Ci);
		  HandleLine_bi = true;
		}
	    }
	  else
	    {
	      if (Line_Ci.find(Disk_Ci) == 0)
		{
		  ScanFdiskLine(Line_Ci, Part_ri);
		  HandleLine_bi = true;
		}
	    }
	  if (HandleLine_bi)
	    {
	      Pt_Ci = Part_C.begin();
	      while (Pt_Ci != Part_C.end() &&
		     Pt_Ci->Device_C != Part_ri.Device_C)
		++Pt_Ci;
	      if (Pt_Ci != Part_C.end())
		{
		  Part_ri.Blocks_i = Pt_Ci->Blocks_i;
		  *Pt_Ci = Part_ri;
		}
	    }
	}
    }
  for (vector<PartInfo>::iterator Pix_Ci = Part_C.begin();
       Pix_Ci != Part_C.end();
       ++Pix_Ci)
    Pix_Ci->InodeDens_i = InodesFromBlock(Pix_Ci->Blocks_i);
}
#endif

void
FdiskAccess::GetFsysType()
{
  SystemCmd Cmd_Ci;

  for (vector<PartInfo>::iterator Pix_Ci = Part_C.begin();
       Pix_Ci != Part_C.end();
       ++Pix_Ci)
    {
      if (IsLinuxPart(*Pix_Ci) && access( "/sbin/debugreiserfs", X_OK )==0 )
	{
	  if( Cmd_Ci.Execute((string)"/sbin/debugreiserfs " + Pix_Ci->Device_C) == 0 )
	    Pix_Ci->Filesys_e = FS_TYPE_REISER;
	}
    }
}
