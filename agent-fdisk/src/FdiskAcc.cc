// Maintainer: fehr@suse.de

#define FDISKPATH "/usr/lib/YaST2/bin/fdisk "	// blank at end !!


#include <string>
#include <sstream>

#include <ycp/y2log.h>
#include "AppUtil.h"
#include "SystemCmd.h"
#include "InterCmd.h"
#include "AsciiFile.h"
#include "FdiskAcc.h"

FdiskAccess::FdiskAccess(string Disk_Cv, bool Readonly_bv )
  : DiskAccess(Disk_Cv),
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
    Label_C = BsdLabel_b ? "bsd" : "msdos";
    SendPrint();
    }
}

FdiskAccess::~FdiskAccess()
{
  y2debug( "Destructor called Disk:%s Fdisk:%p", Disk_C.c_str(), Fdisk_pC );
  if (Fdisk_pC)
    SendQuit();
}

void
FdiskAccess::CheckWritable()
{
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
			  string Von_Cv, string Bis_Cv,
			  const unsigned Type_iv, string DefLabel_Cv )
{
  bool ret = false;
  Changed_b = true;
#if defined(__sparc__)
  ret = NewPartitionBsd(PartNr_iv, Von_Cv, Bis_Cv);
#else
  // If BsdLabel_b is true, the user should be asked whether
  // he wants a BSD or DOS Label. We have to make sure we have
  // at least 1 BSD Label in this case.

  if (BsdLabel_b)
    ret = NewPartitionBsd(PartNr_iv, Von_Cv, Bis_Cv);
  else
    ret = NewPartitionStd(Part_e, PartNr_iv, Von_Cv, Bis_Cv);
#endif
  SetType( PartNr_iv, Type_iv );
  return( ret );
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
  Fdisk_pC->SendInput("p", "ommand");
  Stderr_C.insert(0, *Fdisk_pC->GetString(IDX_STDERR));
  CheckOutput(*Fdisk_pC, Disk_C);
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
    Part_rr.Blocks_l = Tmp_li ;

  Line_Ci.erase(0, Line_Ci.find_first_of(" \t"));
  Line_Ci.erase(0, Line_Ci.find_first_not_of(" \t"));

  if (Line_Ci.find("swap") == 0)
    {
      Part_rr.PType_e = PAR_TYPE_SWAP;
      Part_rr.Id_i = PART_ID_LINUX_SWAP;
    }
  else if (Line_Ci.find("ext2") == 0)
    {
      Part_rr.PType_e = PAR_TYPE_LINUX;
      Part_rr.Id_i = PART_ID_LINUX_NATIVE;
    }
  else if (Line_Ci.find("unused") == 0)
    {
      Part_rr.PType_e = PAR_TYPE_UNUSED;
      Part_rr.Id_i = PART_ID_UNUSED;
    }

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
	  Part_rr.Id_i = PART_ID_LINUX_SWAP;
	}
      else if (Tmp_Ci.find ("apple_hfs") != string::npos)
	{
	  Part_rr.PType_e = PAR_TYPE_LINUX;
	  Part_rr.Id_i = PART_ID_LINUX_NATIVE;
	}
      else 
	{
	  Part_rr.PType_e = PAR_TYPE_LINUX;
	  Part_rr.Id_i = PART_ID_LINUX_NATIVE;
	}
    }
  else
    {
      Part_rr.PType_e = PAR_TYPE_OTHER;
    }
  for (string::iterator i = Line_Ci.begin(); i != Line_Ci.end(); i++)
    if (*i == '*') *i = ' ';
  Part_rr.Info_C = ExtractNthWord(0, Line_Ci);
  Line_Ci.erase(Line_Ci.find(" @"));
  Tmp_Ci = Line_Ci.substr(Line_Ci.rfind(' ') + 1);
  if (sscanf(Tmp_Ci.c_str(), "%lu", &Tmp_li) > 0)
    Part_rr.Blocks_l = Tmp_li / 2;
}

void
FdiskAccess::ScanFdiskLine(string Line_Cv, PartInfo& Part_rr)
{
  string Line_Ci = Line_Cv;
  string Tmp_Ci;

  Part_rr.Device_C = Line_Ci.substr(0, Line_Ci.find_first_of(" \t"));
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
  if (sscanf(Line_Ci.c_str(), "%ld", &Part_rr.Blocks_l) != 1)
    {
      // XXX y2log()
    }
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
	  if (Part_rr.Info_C.find("DOS") == string::npos)
	    Part_rr.Info_C = "DOS";
	}
      else
	{
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
      if (Part_rr.Info_C.find("swap") != string::npos ||
	  Part_rr.Id_i == 0x92)
	{
	  Part_rr.PType_e = PAR_TYPE_SWAP;
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

  Cnt_ii = Cmd_Cv.Select("^" + Pat_Cv);
  for(Idx_ii = 0; Idx_ii < Cnt_ii; Idx_ii++)
    {
      Part_ri.PType_e = PAR_TYPE_OTHER;
      Line_Ci = *Cmd_Cv.GetLine(Idx_ii, true);
      ScanFdiskLine(Line_Ci, Part_ri);
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

  Cnt_ii = Cmd_Cv.NumLines();
  for (Idx_ii=0; Idx_ii < Cnt_ii; Idx_ii++)
    {
      Part_ri.PType_e = PAR_TYPE_OTHER;
      Line_Ci = *Cmd_Cv.GetLine(Idx_ii);
      if (IsBsdLine(Line_Ci))
	{
	  ScanBsdLine(Line_Ci, Part_ri, Disk_Cv);
	  New_Ci.push_back(Part_ri);
	}
    }
  Part_C = New_Ci;
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

